import { afterEach, describe, expect, it } from "vitest";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { AddressInfo } from "node:net";
import type { Server } from "node:http";
import { createApp } from "../src/app.js";

/**
 * Modos de fallo FM-01 y FM-02 (docs/modos-de-fallo.md).
 *
 * Cada prueba afirma el comportamiento DESEADO. Si el defecto descrito en
 * el documento existe, la prueba falla; si no existe, pasa y el documento
 * debe corregirse. Se usa `expect.soft` en la primera aserción para que la
 * consecuencia (que no llegue `sync.start`) también se evalúe.
 */

interface StreamEvent {
  type: string;
  [key: string]: unknown;
}

/** Conexión NDJSON abierta contra el servidor real. */
interface OpenStream {
  events: StreamEvent[];
  /** `true` cuando el servidor terminó la respuesta. */
  readonly ended: boolean;
  close(): void;
  waitFor(type: string, timeoutMs: number): Promise<StreamEvent | undefined>;
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function openStream(
  baseUrl: string,
  roomId: string,
  receiverId: string,
): Promise<OpenStream> {
  const abort = new AbortController();
  const events: StreamEvent[] = [];
  let ended = false;

  const response = await fetch(`${baseUrl}/rooms/${roomId}/stream/${receiverId}`, {
    signal: abort.signal,
  });

  void (async () => {
    const reader = response.body?.getReader();

    if (!reader) {
      ended = true;
      return;
    }

    const decoder = new TextDecoder();
    let buffer = "";

    try {
      for (;;) {
        const { value, done } = await reader.read();

        if (done) {
          ended = true;
          return;
        }

        buffer += decoder.decode(value, { stream: true });

        let newline = buffer.indexOf("\n");

        while (newline >= 0) {
          const line = buffer.slice(0, newline).trim();
          buffer = buffer.slice(newline + 1);
          newline = buffer.indexOf("\n");

          if (line) {
            events.push(JSON.parse(line) as StreamEvent);
          }
        }
      }
    } catch {
      // Cierre o aborto de la conexión: no es un error de la prueba.
      ended = true;
    }
  })();

  return {
    events,
    get ended() {
      return ended;
    },
    close: () => abort.abort(),
    async waitFor(type, timeoutMs) {
      const deadline = Date.now() + timeoutMs;

      while (Date.now() < deadline) {
        const found = events.find((event) => event.type === type);

        if (found) {
          return found;
        }

        await sleep(25);
      }

      return events.find((event) => event.type === type);
    },
  };
}

describe("modos de fallo — conexiones de stream", () => {
  const cleanups: Array<() => Promise<void> | void> = [];

  afterEach(async () => {
    for (const cleanup of cleanups.splice(0).reverse()) {
      await cleanup();
    }
  });

  async function startServer(databaseFile: string) {
    const app = createApp({ databaseFile });
    const server: Server = app.listen(0);

    await new Promise((resolve) => server.once("listening", resolve));

    const baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
    let stopped = false;

    const stop = async () => {
      if (stopped) {
        return;
      }

      stopped = true;
      server.closeAllConnections();
      await new Promise((resolve) => server.close(resolve));
      app.locals.close();
    };

    cleanups.push(stop);

    return { baseUrl, stop };
  }

  function tempDatabase() {
    const directory = mkdtempSync(join(tmpdir(), "audioshare-fm-"));

    cleanups.push(() => rmSync(directory, { recursive: true, force: true }));

    return join(directory, "audioshare.sqlite");
  }

  async function post(url: string, body: unknown = {}) {
    return fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  }

  it("FM-01: al reconectar con el mismo receiverId, el cierre de la conexión anterior no deja al receptor sin eventos", async () => {
    const { baseUrl } = await startServer(tempDatabase());

    const { roomId } = (await (
      await post(`${baseUrl}/rooms`, { emitterId: "emitter-fm01" })
    ).json()) as { roomId: string };

    await post(`${baseUrl}/rooms/${roomId}/receivers`, { receiverId: "r1" });

    // Conexión A, y luego la reconexión B con el mismo receiverId.
    const streamA = await openStream(baseUrl, roomId, "r1");
    const streamB = await openStream(baseUrl, roomId, "r1");

    cleanups.push(() => {
      streamA.close();
      streamB.close();
    });

    // El cliente abandona la conexión A (cambio de red, por ejemplo).
    streamA.close();
    await sleep(300); // margen para que el servidor procese el cierre

    const room = (await (await fetch(`${baseUrl}/rooms/${roomId}`)).json()) as {
      connectedReceivers: number;
    };

    // Sigue habiendo una conexión viva (la B).
    expect.soft(room.connectedReceivers).toBe(1);

    await post(`${baseUrl}/rooms/${roomId}/play`);

    const start = await streamB.waitFor("sync.start", 2000);

    expect(start).toBeDefined();
  });

  it("FM-02: una sala creada antes de un reinicio puede abrir su stream y recibir PLAY", async () => {
    const databaseFile = tempDatabase();

    // Proceso 1: crea la sala y une al receptor.
    const first = await startServer(databaseFile);

    const { roomId } = (await (
      await post(`${first.baseUrl}/rooms`, { emitterId: "emitter-fm02" })
    ).json()) as { roomId: string };

    await post(`${first.baseUrl}/rooms/${roomId}/receivers`, { receiverId: "r1" });

    // Reinicio: se cierra el proceso 1 y arranca otro sobre la misma base.
    await first.stop();

    const second = await startServer(databaseFile);

    // Precondición: la base conservó la sala (la persistencia sí funciona).
    const restored = await fetch(`${second.baseUrl}/rooms/${roomId}`);

    expect(restored.status).toBe(200);

    // El receptor vuelve a abrir su stream en el proceso nuevo.
    const stream = await openStream(second.baseUrl, roomId, "r1");

    cleanups.push(() => stream.close());

    await sleep(300);

    // El servidor no debe terminar la respuesta de inmediato.
    expect.soft(stream.ended).toBe(false);

    await post(`${second.baseUrl}/rooms/${roomId}/play`);

    const start = await stream.waitFor("sync.start", 2000);

    expect(start).toBeDefined();
  });
});

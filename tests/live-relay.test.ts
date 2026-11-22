import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type { Express } from "express";
import type { Server } from "node:http";
import type { AddressInfo } from "node:net";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import WebSocket from "ws";
import { createApp } from "../src/app.js";
import { LIVE_CLOSE } from "../src/modules/live/index.js";

/**
 * Transmisión de audio en vivo (ADR-0015): el emisor envía paquetes PCM por un
 * WebSocket y el servidor los reenvía a los receptores de la misma sala.
 */

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/** Paquete versión 1: PCM16 estéreo, 48 kHz. */
function packet(sequence: number, frames = 8): Buffer {
  const bytes = Buffer.alloc(20 + frames * 4);

  bytes[0] = 1;
  bytes[1] = 0;
  bytes[2] = 2;
  bytes.writeUInt32LE(48_000, 4);
  bytes.writeUInt32LE(sequence, 8);
  bytes.writeDoubleLE(Date.now(), 12);

  return bytes;
}

interface Peer {
  socket: WebSocket;
  messages: Array<Record<string, unknown>>;
  packets: Buffer[];
  closeCode: number | null;
}

describe("Audio en vivo", () => {
  let directory: string;
  let app: Express;
  let server: Server;
  let baseUrl: string;
  const peers: Peer[] = [];

  const api = async (method: string, path: string, options: { key?: string; body?: unknown } = {}) => {
    const headers: Record<string, string> = {};

    if (options.key) {
      headers.Authorization = `Bearer ${options.key}`;
    }

    if (options.body !== undefined) {
      headers["Content-Type"] = "application/json";
    }

    const response = await fetch(`${baseUrl}${path}`, {
      method,
      headers,
      body: options.body === undefined ? undefined : JSON.stringify(options.body),
    });
    const text = await response.text();

    return {
      status: response.status,
      json: text ? (JSON.parse(text) as Record<string, any>) : {},
    };
  };

  const newRoom = async () => {
    const res = await api("POST", "/rooms", { body: { emitterId: "Ana" } });

    expect(res.status).toBe(201);

    return { roomId: res.json.roomId as string, key: res.json.emitterKey as string };
  };

  const joinRoom = async (roomId: string, receiverId: string) => {
    const res = await api("POST", `/rooms/${roomId}/receivers`, { body: { receiverId } });

    expect(res.status).toBe(201);
  };

  const connect = async (roomId: string, hello: Record<string, unknown>): Promise<Peer> => {
    const socket = new WebSocket(`${baseUrl.replace("http", "ws")}/rooms/${roomId}/live`);
    const peer: Peer = { socket, messages: [], packets: [], closeCode: null };

    socket.on("message", (data: Buffer, isBinary: boolean) => {
      if (isBinary) {
        peer.packets.push(Buffer.from(data));
      } else {
        peer.messages.push(JSON.parse(data.toString()) as Record<string, unknown>);
      }
    });
    socket.on("close", (code: number) => {
      peer.closeCode = code;
    });
    socket.on("error", () => undefined);
    peers.push(peer);
    await new Promise<void>((resolve) => {
      socket.once("open", () => resolve());
      socket.once("close", () => resolve());
    });

    if (socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({ type: "hello", ...hello }));
    }

    return peer;
  };

  const until = async (condition: () => boolean, timeoutMs = 2000) => {
    const deadline = Date.now() + timeoutMs;

    while (!condition() && Date.now() < deadline) {
      await sleep(20);
    }
  };

  const lastState = (peer: Peer) => peer.messages.filter((m) => m.type === "live.state").at(-1);

  beforeEach(async () => {
    directory = mkdtempSync(join(tmpdir(), "audioshare-live-"));
    app = createApp({ databaseFile: join(directory, "audioshare.sqlite") });
    server = app.listen(0);
    app.locals.attachLive(server);
    await new Promise((resolve) => server.once("listening", resolve));
    baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  });

  afterEach(async () => {
    peers.splice(0).forEach((peer) => peer.socket.terminate());
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
    app.locals.close();
    rmSync(directory, { recursive: true, force: true });
  });

  it("rechaza al emisor con una llave que no es de la sala", async () => {
    const { roomId } = await newRoom();
    const emitter = await connect(roomId, { role: "emitter", key: "llave-falsa" });

    await until(() => emitter.closeCode !== null);

    expect(emitter.closeCode).toBe(LIVE_CLOSE.unauthorized);
  });

  it("rechaza a un receptor que no se unió a la sala", async () => {
    const { roomId } = await newRoom();
    const receiver = await connect(roomId, { role: "receiver", receiverId: "Luis" });

    await until(() => receiver.closeCode !== null);

    expect(receiver.closeCode).toBe(LIVE_CLOSE.notFound);
  });

  it("responde 404 si la sala no existe", async () => {
    const res = await api("GET", "/rooms/999999/live");

    expect(res.status).toBe(404);
  });

  it("rechaza una conexión de audio desde un origen no permitido", async () => {
    const { roomId } = await newRoom();
    const status = await new Promise<number>((resolve) => {
      const socket = new WebSocket(`${baseUrl.replace("http", "ws")}/rooms/${roomId}/live`, {
        origin: "https://sitio-ajeno.example",
      });

      socket.on("unexpected-response", (_request, response) => resolve(response.statusCode ?? 0));
      socket.on("open", () => resolve(101));
      socket.on("error", () => undefined);
    });

    expect(status).toBe(403);
  });

  it("reenvía el audio del emisor a los receptores y publica el estado", async () => {
    const { roomId, key } = await newRoom();

    await joinRoom(roomId, "Luis");

    const receiver = await connect(roomId, { role: "receiver", receiverId: "Luis" });
    const emitter = await connect(roomId, { role: "emitter", key });

    await until(() => receiver.messages.length >= 2 && emitter.messages.length >= 1);
    expect(lastState(receiver)?.active).toBe(false);

    emitter.socket.send(JSON.stringify({ type: "live.start", source: "tab", label: "Pestaña" }));
    await until(() => lastState(receiver)?.active === true);

    expect(lastState(receiver)).toMatchObject({ active: true, source: "tab", label: "Pestaña" });

    const live = await api("GET", `/rooms/${roomId}/live`);

    expect(live.status).toBe(200);
    expect(live.json).toMatchObject({ active: true, source: "tab", receivers: 1 });

    const sent = [packet(1), packet(2), packet(3)];

    sent.forEach((item) => emitter.socket.send(item));
    emitter.socket.send(Buffer.from([1, 2, 3])); // cabecera inválida: se descarta
    await until(() => receiver.packets.length >= 3);
    await sleep(60);

    expect(receiver.packets).toHaveLength(3);
    sent.forEach((item, index) => expect(receiver.packets[index]?.equals(item)).toBe(true));
  });

  it("avisa a los receptores cuando el emisor deja de transmitir", async () => {
    const { roomId, key } = await newRoom();

    await joinRoom(roomId, "Luis");

    const receiver = await connect(roomId, { role: "receiver", receiverId: "Luis" });
    const emitter = await connect(roomId, { role: "emitter", key });

    await until(() => emitter.messages.length >= 1);
    emitter.socket.send(JSON.stringify({ type: "live.start", source: "device" }));
    await until(() => lastState(receiver)?.active === true);
    emitter.socket.close();
    await until(() => lastState(receiver)?.active === false);

    expect(lastState(receiver)?.active).toBe(false);
  });

  it("corta el audio de un receptor expulsado", async () => {
    const { roomId, key } = await newRoom();

    await joinRoom(roomId, "Luis");

    const receiver = await connect(roomId, { role: "receiver", receiverId: "Luis" });

    await until(() => receiver.messages.length >= 1);

    const kick = await api("POST", `/rooms/${roomId}/kick`, { key, body: { receiverId: "Luis" } });

    expect(kick.status).toBe(204);
    await until(() => receiver.closeCode !== null);

    expect(receiver.closeCode).toBe(LIVE_CLOSE.removed);
  });

  it("cierra las conexiones de audio al cerrar la sala", async () => {
    const { roomId, key } = await newRoom();

    await joinRoom(roomId, "Luis");

    const receiver = await connect(roomId, { role: "receiver", receiverId: "Luis" });

    await until(() => receiver.messages.length >= 1);

    const closed = await api("DELETE", `/rooms/${roomId}`, { key });

    expect(closed.status).toBe(204);
    await until(() => receiver.closeCode !== null);

    expect(receiver.closeCode).toBe(LIVE_CLOSE.roomClosed);
  });
});

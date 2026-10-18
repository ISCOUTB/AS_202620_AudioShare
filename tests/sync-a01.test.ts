import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { AddressInfo } from "node:net";
import type { Server } from "node:http";
import { createApp } from "../src/app.js";
import {
  EC01_THRESHOLD_MS,
  delayUntilStart,
  estimateBestOffset,
  estimateOffset,
} from "../src/modules/sync/index.js";
import { SimulatedReceiver } from "./support/simulated-receiver.js";

/**
 * A-01 / EC-01 — Sincronización inicial (ADR-0005).
 *
 * Estas pruebas ejercitan el código real (src/modules/sync + src/app.ts):
 * levantan el servidor, conectan receptores simulados con relojes
 * desfasados y miden la diferencia de arranque a partir de los ACK que
 * ellos reportan. No hay constantes calculadas dentro del test.
 *
 * Límite honesto: los receptores son procesos simulados en la misma
 * máquina; miden el protocolo (offset + programación + ACK), no la
 * reproducción de audio física en dispositivos reales.
 */

describe("A-01 / EC-01 — lógica de sincronización (unitaria)", () => {
  it("estima el offset del reloj como servidor − punto medio local", () => {
    // El reloj local va 3000 ms ADELANTADO; ida y vuelta de 20 ms.
    const sample = { t0: 13_000, serverTime: 10_010, t1: 13_020 };

    expect(estimateOffset(sample)).toBe(-3000);
  });

  it("elige la muestra con menor tiempo de ida y vuelta", () => {
    const noisy = { t0: 0, serverTime: 5_000, t1: 400 }; // RTT 400, offset 4800
    const clean = { t0: 1_000, serverTime: 5_995, t1: 1_010 }; // RTT 10, offset 4990

    expect(estimateBestOffset([noisy, clean])).toBe(4990);
  });

  it("espera hasta startAt en el reloj del servidor, no en el local", () => {
    // Local atrasado 2000 ms respecto del servidor (offset +2000).
    // startAt = 10_500 (servidor); ahora local = 8_000 → servidor = 10_000.
    expect(delayUntilStart(10_500, 8_000, 2000)).toBe(500);
    // Si startAt ya pasó, arranca de inmediato.
    expect(delayUntilStart(10_500, 9_000, 2000)).toBe(0);
  });
});

describe("A-01 / EC-01 — receptores simulados contra el servidor real", () => {
  let directory: string;
  let app: ReturnType<typeof createApp>;
  let server: Server;
  let baseUrl: string;
  const receivers: SimulatedReceiver[] = [];

  beforeEach(async () => {
    directory = mkdtempSync(join(tmpdir(), "audioshare-sync-"));
    app = createApp({ databaseFile: join(directory, "audioshare.sqlite") });
    server = app.listen(0);
    await new Promise((resolve) => server.once("listening", resolve));
    baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  });

  afterEach(async () => {
    receivers.splice(0).forEach((receiver) => receiver.close());
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
    app.locals.close();
    rmSync(directory, { recursive: true, force: true });
  });

  async function runScenario(correctClock: boolean) {
    const room = (await (
      await fetch(`${baseUrl}/rooms`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ emitterId: "emitter-sync" }),
      })
    ).json()) as { roomId: string };

    // Tres dispositivos con relojes muy distintos: +3 s, −2,5 s y +120 ms.
    const skews = [3000, -2500, 120];

    for (const [index, skewMs] of skews.entries()) {
      const receiver = new SimulatedReceiver({
        baseUrl,
        roomId: room.roomId,
        receiverId: `receiver-${index + 1}`,
        skewMs,
        correctClock,
      });

      receivers.push(receiver);
      await receiver.calibrate();
      await receiver.join();
    }

    await fetch(`${baseUrl}/rooms/${room.roomId}/play`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ payload: "audio-demo" }),
    });

    const instants = await Promise.all(
      receivers.map((receiver) => receiver.startInstants()),
    );

    // Verdad de referencia: diferencia entre el primer y el último arranque
    // medida con el reloj real único del proceso, no con los relojes
    // desfasados de los dispositivos simulados.
    const realTimes = instants.map((instant) => instant.trueClock);
    const trueSpreadMs = Math.max(...realTimes) - Math.min(...realTimes);

    const report = (await (
      await fetch(`${baseUrl}/rooms/${room.roomId}/sync`)
    ).json()) as {
      acks: unknown[];
      spreadMs: number | null;
      withinThreshold: boolean | null;
    };

    const metrics = (await (await fetch(`${baseUrl}/metrics`)).json()) as {
      last_sync_spread_ms: number | null;
    };

    console.info(
      JSON.stringify({
        escenario: correctClock ? "con corrección" : "sin corrección",
        spreadReportadoPorServidorMs: report.spreadMs,
        spreadRealMs: trueSpreadMs,
      }),
    );

    return { report, metrics, trueSpreadMs };
  }

  it(
    "con corrección de reloj, la diferencia de arranque entre receptores es ≤ 100 ms",
    async () => {
      const { report, metrics, trueSpreadMs } = await runScenario(true);

      expect(report.acks).toHaveLength(3);
      expect(report.spreadMs).not.toBeNull();
      expect(report.spreadMs as number).toBeLessThanOrEqual(EC01_THRESHOLD_MS);
      expect(report.withinThreshold).toBe(true);
      expect(metrics.last_sync_spread_ms).toBe(report.spreadMs);

      // El desfase REAL (reloj único) también cumple el umbral, y coincide
      // con lo que el servidor reporta: la estimación de reloj es fiable.
      expect(trueSpreadMs).toBeLessThanOrEqual(EC01_THRESHOLD_MS);
      expect(
        Math.abs(trueSpreadMs - (report.spreadMs as number)),
      ).toBeLessThanOrEqual(25);
    },
    10_000,
  );

  it(
    "sin corrección de reloj (defecto descartado en ADR-0005) el umbral se supera",
    async () => {
      const { report, trueSpreadMs } = await runScenario(false);

      // Relojes de +3 s, −2,5 s y +120 ms: el desfase REAL es de segundos.
      // Esta es la medida válida del defecto; el valor que reporta el
      // servidor aquí mezcla relojes locales (los receptores no informan su
      // offset) y no debe compararse con el del escenario corregido.
      expect(trueSpreadMs).toBeGreaterThan(EC01_THRESHOLD_MS);
      expect(report.spreadMs as number).toBeGreaterThan(EC01_THRESHOLD_MS);
    },
    10_000,
  );
});

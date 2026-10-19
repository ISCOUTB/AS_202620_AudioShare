import { afterEach, describe, expect, it, vi } from "vitest";
import request from "supertest";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createApp } from "../src/app.js";
import { positionAt } from "../src/modules/sync/index.js";

/**
 * EC-03 — pausar y reanudar conserva la posición de la pista (NC-04).
 * El reloj se simula para no esperar tiempo real.
 */
describe("pausa y reanudación con posición", () => {
  afterEach(() => vi.restoreAllMocks());

  it("positionAt no avanza antes de startAt y suma lo transcurrido después", () => {
    expect(positionAt(1000, 5000, 4000)).toBe(1000);
    expect(positionAt(1000, 5000, 5000)).toBe(1000);
    expect(positionAt(1000, 5000, 8500)).toBe(4500);
  });

  it("pausa guarda la posición alcanzada y play la reanuda desde ahí", async () => {
    const directory = mkdtempSync(join(tmpdir(), "audioshare-resume-"));
    const app = createApp({ databaseFile: join(directory, "audioshare.sqlite") });

    try {
      const { body: room } = await request(app)
        .post("/rooms")
        .send({ emitterId: "emitter-1" })
        .expect(201);

      const play1 = await request(app).post(`/rooms/${room.roomId}/play`).expect(200);
      expect(play1.body.positionMs).toBe(0);

      // 3 s después de startAt, el emisor pausa.
      vi.spyOn(Date, "now").mockReturnValue(play1.body.startAt + 3000);
      const pause1 = await request(app).post(`/rooms/${room.roomId}/pause`).expect(200);
      expect(pause1.body.positionMs).toBe(3000);
      expect(pause1.body.playbackState).toEqual({ playing: false, positionMs: 3000 });

      // Pausar de nuevo no cambia la posición.
      const pause2 = await request(app).post(`/rooms/${room.roomId}/pause`).expect(200);
      expect(pause2.body.positionMs).toBe(3000);

      // Reanudar: el evento lleva la posición y queda persistida.
      const play2 = await request(app).post(`/rooms/${room.roomId}/play`).expect(200);
      expect(play2.body.positionMs).toBe(3000);
      expect(play2.body.playbackState).toEqual({ playing: true, positionMs: 3000 });

      // Pausa inmediata (antes de startAt): la posición no retrocede ni avanza.
      const pause3 = await request(app).post(`/rooms/${room.roomId}/pause`).expect(200);
      expect(pause3.body.positionMs).toBe(3000);

      const state = await request(app).get(`/rooms/${room.roomId}`).expect(200);
      expect(state.body.playbackState.positionMs).toBe(3000);
    } finally {
      app.locals.close();
      rmSync(directory, { recursive: true, force: true });
    }
  });
});

import { afterEach, beforeEach, describe, expect, it } from "vitest";
import request from "supertest";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Express } from "express";
import { createApp } from "../src/app.js";

/**
 * Unirse a una sala es idempotente: el mismo receptor puede volver a entrar
 * (p. ej. tras cerrar la app) y un identificador de otro rol se rechaza con 409.
 */
describe("unirse a una sala con un identificador repetido", () => {
  let directory: string;
  let app: Express;

  beforeEach(() => {
    directory = mkdtempSync(join(tmpdir(), "audioshare-rejoin-"));
    app = createApp({ databaseFile: join(directory, "audioshare.sqlite") });
  });

  afterEach(() => {
    app.locals.close();
    rmSync(directory, { recursive: true, force: true });
  });

  it("el mismo receptor puede volver a entrar sin duplicarse", async () => {
    const { body: room } = await request(app)
      .post("/rooms")
      .send({ emitterId: "emisor-1" })
      .expect(201);

    await request(app)
      .post(`/rooms/${room.roomId}/receivers`)
      .send({ receiverId: "receptor-1" })
      .expect(201);
    await request(app)
      .post(`/rooms/${room.roomId}/receivers`)
      .send({ receiverId: "receptor-1" })
      .expect(201);

    const state = await request(app).get(`/rooms/${room.roomId}`).expect(200);
    const receivers = state.body.participants.filter(
      (participant: { role: string }) => participant.role === "receiver",
    );
    expect(receivers).toHaveLength(1);
  });

  it("rechaza con 409 un identificador que ya es el emisor", async () => {
    const { body: room } = await request(app)
      .post("/rooms")
      .send({ emitterId: "mismo-id" })
      .expect(201);

    const res = await request(app)
      .post(`/rooms/${room.roomId}/receivers`)
      .send({ receiverId: "mismo-id" })
      .expect(409);

    expect(res.body.error).toContain("otro rol");
  });

  it("sigue respondiendo 404 si la sala no existe", async () => {
    await request(app)
      .post("/rooms/no-existe/receivers")
      .send({ receiverId: "receptor-1" })
      .expect(404);
  });
});

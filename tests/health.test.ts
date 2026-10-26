import { afterEach, beforeEach, describe, it, expect } from "vitest";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import request from "supertest";
import { createApp } from "../src/app.js";

describe("esqueleto ejecutable", () => {
  let app: ReturnType<typeof createApp>;
  let directory: string;
  let beforeStart: number;

  beforeEach(() => {
    directory = mkdtempSync(join(tmpdir(), "audioshare-health-"));
    beforeStart = Date.now();
    app = createApp({ databaseFile: join(directory, "audioshare.sqlite") });
  });

  afterEach(() => {
    app.locals.close();
    rmSync(directory, { recursive: true, force: true });
  });

  it("sirve la interfaz de demostración en la raíz", async () => {
    const response = await request(app).get("/");

    expect(response.status).toBe(200);
    expect(response.type).toBe("text/html");
    expect(response.text).toContain("AudioShare");
    expect(response.text).toContain("SINCRONIZACIÓN DE REPRODUCCIÓN");
  });

  it("arranca la aplicación y responde en /health", async () => {
    const response = await request(app).get("/health");

    expect(response.status).toBe(200);
    expect(response.body.status).toBe("ok");
  });

  it("expone los tres módulos definidos en el ADR 0001", async () => {
    const response = await request(app).get("/health");

    expect(response.body.modules).toEqual(
      expect.arrayContaining(["session", "audio", "sync"]),
    );
  });

  it("informa cuándo arrancó el servicio en /health", async () => {
    const response = await request(app).get("/health");
    const startedAt = Date.parse(response.body.startedAt);

    // Un instante válido, posterior a la creación de la app y no futuro: sirve
    // para comprobar desde fuera si el proceso se reinició.
    expect(Number.isNaN(startedAt)).toBe(false);
    expect(startedAt).toBeGreaterThanOrEqual(beforeStart);
    expect(startedAt).toBeLessThanOrEqual(Date.now());
  });

  it("expone la colección de salas en GET /rooms", async () => {
    const createRoom = await request(app)
      .post("/rooms")
      .send({ emitterId: "emitter-a" })
      .expect(201);

    const response = await request(app).get("/rooms").expect(200);

    expect(Array.isArray(response.body)).toBe(true);
    expect(response.body).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          roomId: createRoom.body.roomId,
          status: "stopped",
          participants: expect.arrayContaining([
            expect.objectContaining({
              id: "emitter-a",
              role: "emitter",
            }),
          ]),
        }),
      ]),
    );
  });

  it("permite preflight solo desde un origen configurado", async () => {
    await request(app)
      .options("/rooms")
      .set("Origin", "http://localhost:3000")
      .set("Access-Control-Request-Method", "POST")
      .expect("Access-Control-Allow-Origin", "http://localhost:3000")
      .expect(204);

    await request(app)
      .options("/rooms")
      .set("Origin", "http://localhost:8080")
      .set("Access-Control-Request-Method", "POST")
      .expect("Access-Control-Allow-Origin", "http://localhost:8080")
      .expect(204);

    const denied = await request(app)
      .options("/rooms")
      .set("Origin", "https://untrusted.example")
      .set("Access-Control-Request-Method", "POST")
      .expect(403);

    expect(denied.body.error).toBe("Origen no permitido");
    expect(denied.headers["access-control-allow-origin"]).toBeUndefined();
  });
});

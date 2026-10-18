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
});

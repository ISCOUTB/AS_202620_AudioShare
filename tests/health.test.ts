import { afterEach, beforeEach, describe, it, expect } from "vitest";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import request from "supertest";
import { createApp } from "../src/app.js";

describe("esqueleto ejecutable", () => {
  let app: ReturnType<typeof createApp>;
  let directory: string;

  beforeEach(() => {
    directory = mkdtempSync(join(tmpdir(), "audioshare-health-"));
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
});

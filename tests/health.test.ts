import { describe, it, expect } from "vitest";
import request from "supertest";
import { createApp } from "../src/app.js";

describe("esqueleto ejecutable", () => {
  it("arranca la aplicación y responde en /health", async () => {
    const app = createApp();

    const response = await request(app).get("/health");

    expect(response.status).toBe(200);
    expect(response.body.status).toBe("ok");
  });

  it("expone los tres módulos definidos en el ADR 0001", async () => {
    const app = createApp();

    const response = await request(app).get("/health");

    expect(response.body.modules).toEqual(
      expect.arrayContaining(["session", "audio", "sync"]),
    );
  });
});

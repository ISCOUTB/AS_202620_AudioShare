import { afterEach, beforeEach, describe, expect, it } from "vitest";
import request from "supertest";
import { readFileSync } from "node:fs";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { load } from "js-yaml";
import Ajv from "ajv";
import type { Express } from "express";
import { createApp } from "../src/app.js";

/**
 * Prueba de contrato — NO prueba lógica de negocio (eso lo hace
 * tests/a01.test.ts). Prueba que las respuestas reales del servidor siguen
 * cumpliendo el contrato publicado en docs/contracts/openapi.yaml.
 *
 * El esquema se carga directamente del archivo YAML: el contrato es la
 * fuente única de verdad, no una copia del esquema mantenida a mano dentro
 * del test. Si alguien cambia un campo en app.ts sin actualizar el YAML,
 * o cambia el YAML sin que el código lo cumpla, esta prueba debe fallar.
 */

const __dirname = dirname(fileURLToPath(import.meta.url));

interface OpenApiDoc {
  components: { schemas: Record<string, unknown> };
}

const openapi = load(
  readFileSync(
    join(__dirname, "../docs/contracts/openapi.yaml"),
    "utf-8",
  ),
) as OpenApiDoc;

const ajv = new Ajv({ strict: false });

// Registra cada esquema de components/schemas para poder referenciarlo por
// $ref tal como lo hace el propio openapi.yaml.
for (const [name, schema] of Object.entries(openapi.components.schemas)) {
  ajv.addSchema(schema as object, `#/components/schemas/${name}`);
}

function validate(schemaName: string, data: unknown): void {
  const validator = ajv.getSchema(`#/components/schemas/${schemaName}`);

  if (!validator) {
    throw new Error(`Esquema no encontrado en el contrato: ${schemaName}`);
  }

  const valid = validator(data);

  if (!valid) {
    throw new Error(
      `Respuesta no cumple el contrato "${schemaName}":\n` +
        JSON.stringify(validator.errors, null, 2) +
        `\nRecibido:\n${JSON.stringify(data, null, 2)}`,
    );
  }
}

describe("Prueba de contrato — OpenAPI", () => {
  let app: Express;
  let directory: string;

  beforeEach(() => {
    directory = mkdtempSync(join(tmpdir(), "audioshare-contract-"));
    app = createApp({
      databaseFile: join(directory, "audioshare.sqlite"),
    });
  });

  afterEach(() => {
    app.locals.close();
    rmSync(directory, { recursive: true, force: true });
  });

  it("GET /health cumple HealthStatus", async () => {
    const res = await request(app).get("/health").expect(200);
    validate("HealthStatus", res.body);
  });

  it("POST /rooms cumple CreateRoomResponse", async () => {
    const res = await request(app)
      .post("/rooms")
      .send({ emitterId: "emitter-contract" })
      .expect(201);
    validate("CreateRoomResponse", res.body);
  });

  it("GET /rooms/:roomId cumple RoomState", async () => {
    const room = await request(app)
      .post("/rooms")
      .send({ emitterId: "emitter-contract" })
      .expect(201);

    const res = await request(app)
      .get(`/rooms/${room.body.roomId}`)
      .expect(200);

    validate("RoomState", res.body);
  });

  it("GET /rooms/:roomId con sala inexistente cumple ErrorResponse", async () => {
    const res = await request(app).get("/rooms/no-existe").expect(404);
    validate("ErrorResponse", res.body);
  });

  it("POST /rooms/:roomId/receivers cumple AddReceiverResponse", async () => {
    const room = await request(app)
      .post("/rooms")
      .send({ emitterId: "emitter-contract" })
      .expect(201);

    const res = await request(app)
      .post(`/rooms/${room.body.roomId}/receivers`)
      .send({ receiverId: "receiver-contract" })
      .expect(201);

    validate("AddReceiverResponse", res.body);
  });

  it("POST /rooms/:roomId/play cumple PlayResponse", async () => {
    const room = await request(app)
      .post("/rooms")
      .send({ emitterId: "emitter-contract" })
      .expect(201);

    const res = await request(app)
      .post(`/rooms/${room.body.roomId}/play`)
      .send({ payload: "contract-demo" })
      .expect(200);

    validate("PlayResponse", res.body);
  });

  it("POST /rooms/:roomId/pause cumple PauseResponse", async () => {
    const room = await request(app)
      .post("/rooms")
      .send({ emitterId: "emitter-contract" })
      .expect(201);

    await request(app)
      .post(`/rooms/${room.body.roomId}/play`)
      .send({ payload: "contract-demo" })
      .expect(200);

    const res = await request(app)
      .post(`/rooms/${room.body.roomId}/pause`)
      .expect(200);

    validate("PauseResponse", res.body);
  });

  it("POST /rooms/:roomId/audio cumple AudioChunk", async () => {
    const room = await request(app)
      .post("/rooms")
      .send({ emitterId: "emitter-contract" })
      .expect(201);

    const res = await request(app)
      .post(`/rooms/${room.body.roomId}/audio`)
      .send({ payload: "contract-demo" })
      .expect(200);

    validate("AudioChunk", res.body);
  });
});

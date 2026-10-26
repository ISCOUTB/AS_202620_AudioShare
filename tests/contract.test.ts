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

  it("GET /track entrega la pista de audio (MP3) con soporte Range", async () => {
    const res = await request(app).get("/track").expect(200);
    expect(res.headers["content-type"]).toContain("audio/mpeg");

    const range = await request(app)
      .get("/track")
      .set("Range", "bytes=0-99")
      .expect(206);
    expect(range.headers["content-range"]).toMatch(/^bytes 0-99\//);
  });

  it("POST /rooms/:roomId/track cumple el contrato y devuelve el archivo subido", async () => {
    const room = await request(app)
      .post("/rooms")
      .send({ emitterId: "emitter-contract" })
      .expect(201);
    const bytes = Buffer.from([0x49, 0x44, 0x33, 1, 2, 3]);

    await request(app)
      .post(`/rooms/${room.body.roomId}/track`)
      .set("Content-Type", "audio/mpeg")
      .send(Buffer.from("not audio"))
      .expect(400);

    const upload = await request(app)
      .post(`/rooms/${room.body.roomId}/track`)
      .set("Content-Type", "audio/mpeg")
      .send(bytes)
      .expect(201);

    expect(upload.body).toEqual({ roomId: room.body.roomId, bytes: bytes.length });

    const download = await request(app)
      .get(`/rooms/${room.body.roomId}/track`)
      .buffer(true)
      .parse((response, callback) => {
        const chunks: Buffer[] = [];
        response.on("data", (chunk: Buffer) => chunks.push(chunk));
        response.on("end", () => callback(null, Buffer.concat(chunks)));
      })
      .expect(200);

    expect(download.headers["content-type"]).toContain("audio/mpeg");
    expect(download.body).toEqual(bytes);
  });

  it("GET /time cumple ServerTime", async () => {
    const res = await request(app).get("/time").expect(200);
    validate("ServerTime", res.body);
  });

  it("POST .../ack y GET /rooms/:roomId/sync cumplen AckResponse y SyncReport", async () => {
    const room = await request(app)
      .post("/rooms")
      .send({ emitterId: "emitter-contract" })
      .expect(201);
    const roomId = room.body.roomId;

    for (const receiverId of ["r1", "r2"]) {
      await request(app)
        .post(`/rooms/${roomId}/receivers`)
        .send({ receiverId })
        .expect(201);
    }

    const play = await request(app).post(`/rooms/${roomId}/play`).send({}).expect(200);

    const ack = await request(app)
      .post(`/rooms/${roomId}/receivers/r1/ack`)
      .send({ startedAt: play.body.startAt + 5, offsetMs: 0 })
      .expect(200);
    validate("AckResponse", ack.body);

    await request(app)
      .post(`/rooms/${roomId}/receivers/r2/ack`)
      .send({ startedAt: play.body.startAt + 9, offsetMs: 0 })
      .expect(200);

    const report = await request(app).get(`/rooms/${roomId}/sync`).expect(200);
    validate("SyncReport", report.body);
    expect(report.body.spreadMs).toBe(4);
    expect(report.body.withinThreshold).toBe(true);
  });

  it("ACK con datos inválidos o sala sin play responde con ErrorResponse", async () => {
    const room = await request(app)
      .post("/rooms")
      .send({ emitterId: "emitter-contract" })
      .expect(201);
    const roomId = room.body.roomId;
    await request(app)
      .post(`/rooms/${roomId}/receivers`)
      .send({ receiverId: "r1" })
      .expect(201);

    const noPlay = await request(app)
      .post(`/rooms/${roomId}/receivers/r1/ack`)
      .send({ startedAt: 1, offsetMs: 0 })
      .expect(409);
    validate("ErrorResponse", noPlay.body);

    const invalid = await request(app)
      .post(`/rooms/${roomId}/receivers/r1/ack`)
      .send({ startedAt: "x" })
      .expect(400);
    validate("ErrorResponse", invalid.body);
  });
});

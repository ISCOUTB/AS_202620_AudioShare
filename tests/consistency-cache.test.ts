import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import * as fsPromises from "node:fs/promises";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import request from "supertest";
import { createApp } from "../src/app.js";
import { AudioTrackStore } from "../src/modules/audio/index.js";

// `rename` envuelto para poder simular un fallo justo antes de publicar la pista.
vi.mock("node:fs/promises", async (importOriginal) => {
  const actual = await importOriginal<typeof import("node:fs/promises")>();
  return { ...actual, rename: vi.fn(actual.rename) };
});

/**
 * Semana 12 — consistencia y caché (docs/consistencia-operaciones.md,
 * docs/diseno-cache.md, ADR-0011).
 */
describe("consistencia: PLAY persiste el estado que luego se lee", () => {
  let app: ReturnType<typeof createApp>;
  let directory: string;

  beforeEach(() => {
    directory = mkdtempSync(join(tmpdir(), "audioshare-s12-"));
    app = createApp({ databaseFile: join(directory, "audioshare.sqlite") });
  });

  afterEach(() => {
    app.locals.close();
    rmSync(directory, { recursive: true, force: true });
  });

  it("la respuesta de PLAY coincide con la lectura posterior de la sala", async () => {
    const { body: room } = await request(app)
      .post("/rooms")
      .send({ emitterId: "emitter-1" })
      .expect(201);

    const play = await request(app).post(`/rooms/${room.roomId}/play`).expect(200);
    const read = await request(app).get(`/rooms/${room.roomId}`).expect(200);

    expect(read.body.startAt).toBe(play.body.startAt);
    expect(read.body.playbackState).toEqual(play.body.playbackState);
    expect(read.body.status).toBe("playing");
  });

  it("PLAY sobre una sala inexistente no crea estado ni responde éxito", async () => {
    await request(app).post("/rooms/no-existe/play").expect(404);
    await request(app).get("/rooms/no-existe").expect(404);
  });
});

describe("caché de la pista", () => {
  let app: ReturnType<typeof createApp>;
  let directory: string;

  beforeEach(() => {
    directory = mkdtempSync(join(tmpdir(), "audioshare-s12-cache-"));
    app = createApp({ databaseFile: join(directory, "audioshare.sqlite") });
  });

  afterEach(() => {
    app.locals.close();
    rmSync(directory, { recursive: true, force: true });
  });

  it("/track exige revalidar y un If-None-Match vigente recibe 304", async () => {
    const first = await request(app).get("/track").expect(200);

    expect(first.headers["cache-control"]).toContain("no-cache");
    expect(first.headers["cache-control"]).not.toContain("max-age=3600");
    expect(first.headers.etag).toBeTruthy();

    await request(app)
      .get("/track")
      .set("If-None-Match", first.headers.etag)
      .expect(304);
  });

  it("la pista de una sala no se cachea", async () => {
    const { body: room } = await request(app)
      .post("/rooms")
      .send({ emitterId: "emitter-1" })
      .expect(201);
    const mp3 = Buffer.concat([Buffer.from("ID3"), Buffer.alloc(64, 1)]);

    await request(app)
      .post(`/rooms/${room.roomId}/track`)
      .set("Content-Type", "audio/mpeg")
      .send(mp3)
      .expect(201);

    const response = await request(app).get(`/rooms/${room.roomId}/track`).expect(200);
    expect(response.headers["cache-control"]).toBe("no-store");
  });
});

describe("almacenamiento atómico de pistas (ADR-0011)", () => {
  let directory: string;

  beforeEach(() => {
    directory = mkdtempSync(join(tmpdir(), "audioshare-s12-store-"));
  });

  afterEach(() => rmSync(directory, { recursive: true, force: true }));

  it("reemplaza la pista completa y no deja archivos temporales", async () => {
    const store = new AudioTrackStore(directory);
    const roomId = "abc-123";
    const first = Buffer.alloc(1024, 1);
    const second = Buffer.alloc(2048, 2);

    await store.save(roomId, first);
    await store.save(roomId, second);

    expect(readFileSync(store.pathFor(roomId)).equals(second)).toBe(true);
    expect(readdirSync(directory)).toEqual([`${roomId}.mp3`]);
  });

  it("si falla la publicación conserva la pista anterior y limpia el temporal", async () => {
    const store = new AudioTrackStore(directory);
    const roomId = "abc-123";
    const original = Buffer.alloc(512, 7);
    await store.save(roomId, original);

    vi.mocked(fsPromises.rename).mockRejectedValueOnce(new Error("EIO simulado"));

    await expect(store.save(roomId, Buffer.alloc(4096, 9))).rejects.toThrow("EIO");

    expect(readFileSync(store.pathFor(roomId)).equals(original)).toBe(true);
    expect(readdirSync(directory)).toEqual([`${roomId}.mp3`]);
  });
});

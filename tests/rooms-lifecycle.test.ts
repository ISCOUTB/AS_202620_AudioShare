import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import request from "supertest";
import Database from "better-sqlite3";
import type { Express } from "express";
import type { AddressInfo } from "node:net";
import { existsSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createApp } from "../src/app.js";

/**
 * Ciclo de vida de las salas (semana 14): código de 6 dígitos, nombres
 * elegidos por el usuario, regreso del emisor, caducidad por inactividad,
 * límite de intentos con códigos inexistentes y errores siempre en JSON.
 */

const HOUR_MS = 60 * 60 * 1000;

describe("Ciclo de vida de las salas", () => {
  let directory: string;
  let app: Express;

  const open = (options: Parameters<typeof createApp>[0] = {}): Express =>
    createApp({ databaseFile: join(directory, "audioshare.sqlite"), ...options });

  const createRoom = async (emitterId = "emisor"): Promise<string> => {
    const res = await request(app).post("/rooms").send({ emitterId }).expect(201);
    return res.body.roomId as string;
  };

  beforeEach(() => {
    directory = mkdtempSync(join(tmpdir(), "audioshare-lifecycle-"));
    app = open();
  });

  afterEach(() => {
    vi.restoreAllMocks();
    app.locals.close();
    rmSync(directory, { recursive: true, force: true });
  });

  describe("código de sala", () => {
    it("es de 6 dígitos y no se repite entre salas", async () => {
      const codes = new Set<string>();

      for (let i = 0; i < 30; i += 1) {
        const code = await createRoom(`emisor-${i}`);
        expect(code).toMatch(/^\d{6}$/);
        codes.add(code);
      }

      expect(codes.size).toBe(30);
    });

    it("la sala se consulta con su código, incluidos los ceros iniciales", async () => {
      const code = await createRoom();

      const res = await request(app).get(`/rooms/${code}`).expect(200);
      expect(res.body.roomId).toBe(code);
    });
  });

  describe("nombres elegidos por el usuario", () => {
    it.each([
      ["vacío", ""],
      ["solo espacios", "   "],
      ["demasiado largo", "x".repeat(31)],
      ["no es texto", 123],
      ["caracteres de control", "a\nb"],
    ])("rechaza un emisor con nombre %s", async (_label, emitterId) => {
      const res = await request(app).post("/rooms").send({ emitterId }).expect(400);
      expect(typeof res.body.error).toBe("string");
    });

    it("rechaza un receptor con nombre inválido", async () => {
      const code = await createRoom();

      await request(app)
        .post(`/rooms/${code}/receivers`)
        .send({ receiverId: "   " })
        .expect(400);
    });

    it("guarda el nombre recortado", async () => {
      const res = await request(app)
        .post("/rooms")
        .send({ emitterId: "  Ana  " })
        .expect(201);
      expect(res.body.emitterId).toBe("Ana");

      const join = await request(app)
        .post(`/rooms/${res.body.roomId}/receivers`)
        .send({ receiverId: "  Luis " })
        .expect(201);
      expect(join.body.receiverId).toBe("Luis");
    });

    it("si no se envía nombre, el servidor genera uno (clientes anteriores)", async () => {
      const res = await request(app).post("/rooms").send({}).expect(201);
      expect(res.body.emitterId.length).toBeGreaterThan(0);
    });
  });

  describe("regreso del emisor", () => {
    it("el emisor vuelve con su mismo nombre", async () => {
      const code = await createRoom("Ana");

      const res = await request(app)
        .post(`/rooms/${code}/emitter`)
        .send({ emitterId: "Ana" })
        .expect(200);

      expect(res.body).toEqual({ roomId: code, emitterId: "Ana", role: "emitter" });
    });

    it("otro nombre, o el de un receptor, recibe 403", async () => {
      const code = await createRoom("Ana");
      await request(app)
        .post(`/rooms/${code}/receivers`)
        .send({ receiverId: "Luis" })
        .expect(201);

      await request(app)
        .post(`/rooms/${code}/emitter`)
        .send({ emitterId: "Pedro" })
        .expect(403);
      await request(app)
        .post(`/rooms/${code}/emitter`)
        .send({ emitterId: "Luis" })
        .expect(403);
    });

    it("exige el nombre y una sala existente", async () => {
      const code = await createRoom("Ana");

      await request(app).post(`/rooms/${code}/emitter`).send({}).expect(400);
      await request(app)
        .post("/rooms/000000/emitter")
        .send({ emitterId: "Ana" })
        .expect(404);
    });
  });

  describe("caducidad por inactividad", () => {
    const mp3 = Buffer.concat([Buffer.from("ID3"), Buffer.alloc(64)]);

    beforeEach(() => {
      app.locals.close();
      app = open({ roomTtlMs: HOUR_MS });
    });

    it("borra la sala y su pista cuando pasa el plazo, y no antes", async () => {
      const code = await createRoom();
      await request(app)
        .post(`/rooms/${code}/track`)
        .set("Content-Type", "audio/mpeg")
        .send(mp3)
        .expect(201);
      const track = join(directory, "tracks", `${code}.mp3`);
      expect(existsSync(track)).toBe(true);

      expect(await app.locals.sweepExpiredRooms(Date.now())).toBe(0);
      await request(app).get(`/rooms/${code}`).expect(200);

      expect(await app.locals.sweepExpiredRooms(Date.now() + 2 * HOUR_MS)).toBe(1);
      expect(existsSync(track)).toBe(false);
      await request(app).get(`/rooms/${code}`).expect(404);
    });

    it("no borra una sala con un receptor conectado", async () => {
      const code = await createRoom();
      await request(app)
        .post(`/rooms/${code}/receivers`)
        .send({ receiverId: "Luis" })
        .expect(201);

      const server = app.listen(0);
      const { port } = server.address() as AddressInfo;
      const controller = new AbortController();

      try {
        await fetch(`http://127.0.0.1:${port}/rooms/${code}/stream/Luis`, {
          signal: controller.signal,
        });

        expect(await app.locals.sweepExpiredRooms(Date.now() + 2 * HOUR_MS)).toBe(0);

        controller.abort();
        await new Promise((resolve) => setTimeout(resolve, 100));

        expect(await app.locals.sweepExpiredRooms(Date.now() + 2 * HOUR_MS)).toBe(1);
      } finally {
        controller.abort();
        server.closeAllConnections();
        server.close();
      }
    });

    it("migra una base anterior sin la columna de actividad", async () => {
      const legacyFile = join(directory, "legacy.sqlite");
      const legacy = new Database(legacyFile);
      legacy.exec(`
        CREATE TABLE rooms (
          id TEXT PRIMARY KEY, created_at TEXT NOT NULL, status TEXT NOT NULL,
          playback_state TEXT NOT NULL, start_at INTEGER
        );
        CREATE TABLE participants (
          id TEXT NOT NULL, room_id TEXT NOT NULL, role TEXT NOT NULL,
          joined_at TEXT NOT NULL, PRIMARY KEY (room_id, id),
          FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
        );
        INSERT INTO rooms VALUES ('aaaaaaaa-0000-4000-8000-000000000001', '2020-01-01T00:00:00.000Z', 'stopped',
          '{"playing":false,"positionMs":0}', NULL);
        INSERT INTO participants VALUES ('Ana', 'aaaaaaaa-0000-4000-8000-000000000001', 'emitter', '2020-01-01T00:00:00.000Z');
      `);
      legacy.close();

      const migrated = createApp({ databaseFile: legacyFile, roomTtlMs: HOUR_MS });

      try {
        // Sin consultarla antes: consultar una sala cuenta como actividad.
        expect(await migrated.locals.sweepExpiredRooms(Date.now())).toBe(1);
        await request(migrated).get("/rooms/aaaaaaaa-0000-4000-8000-000000000001").expect(404);
      } finally {
        migrated.locals.close();
      }
    });

    it("con plazo 0 las salas no caducan", async () => {
      app.locals.close();
      app = open({ roomTtlMs: 0 });
      await createRoom();

      expect(await app.locals.sweepExpiredRooms(Date.now() + 1000 * HOUR_MS)).toBe(0);
    });
  });

  describe("límite de intentos con códigos inexistentes", () => {
    beforeEach(() => {
      app.locals.close();
      app = open({ lookupLimit: { max: 3, windowMs: 60_000 } });
    });

    it("bloquea al origen tras el tope, incluso con un código válido, y se libera", async () => {
      const code = await createRoom();

      for (let i = 0; i < 3; i += 1) {
        await request(app).get("/rooms/999999").expect(404);
      }

      const blocked = await request(app).get("/rooms/999999").expect(429);
      expect(typeof blocked.body.error).toBe("string");
      expect(Number(blocked.headers["retry-after"])).toBeGreaterThan(0);

      await request(app).get(`/rooms/${code}`).expect(429);

      const later = Date.now() + 61_000;
      vi.spyOn(Date, "now").mockReturnValue(later);
      await request(app).get(`/rooms/${code}`).expect(200);
    });

    it("equivocarse unas pocas veces no bloquea el uso normal", async () => {
      const code = await createRoom();

      await request(app).get("/rooms/111111").expect(404);
      await request(app).get("/rooms/222222").expect(404);
      await request(app).get(`/rooms/${code}`).expect(200);
    });
  });

  describe("errores y salud", () => {
    it("un cuerpo que no es JSON responde 400 en JSON", async () => {
      const res = await request(app)
        .post("/rooms")
        .set("Content-Type", "application/json")
        .send("{mal")
        .expect(400);

      expect(typeof res.body.error).toBe("string");
    });

    it("si el almacenamiento falla, el error es JSON y no se disfraza de 404", async () => {
      const code = await createRoom();
      app.locals.close();

      const create = await request(app).post("/rooms").send({ emitterId: "x" });
      expect(create.status).toBe(500);
      expect(typeof create.body.error).toBe("string");

      const join = await request(app)
        .post(`/rooms/${code}/receivers`)
        .send({ receiverId: "Luis" });
      expect(join.status).toBe(500);
      expect(typeof join.body.error).toBe("string");
    });

    it("/health informa si se puede escribir", async () => {
      const ok = await request(app).get("/health").expect(200);
      expect(ok.body.status).toBe("ok");
      expect(ok.body.storage).toBe("ok");

      app.locals.close();

      const degraded = await request(app).get("/health").expect(200);
      expect(degraded.body.status).toBe("degraded");
      expect(degraded.body.storage).toBe("error");
    });
  });

  describe("listado de salas", () => {
    it("GET /rooms puede cerrarse (producción)", async () => {
      app.locals.close();
      app = open({ exposeRoomList: false });
      await createRoom();

      await request(app).get("/rooms").expect(404);
    });

    it("sigue disponible en desarrollo y pruebas", async () => {
      await createRoom();

      const res = await request(app).get("/rooms").expect(200);
      expect(res.body).toHaveLength(1);
    });
  });
});

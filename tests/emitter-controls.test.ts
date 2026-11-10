import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type { Express } from "express";
import type { Server } from "node:http";
import type { AddressInfo } from "node:net";
import { existsSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createApp } from "../src/app.js";

/**
 * Controles del emisor (semana 14, paquete B1): llave de emisor, salida
 * voluntaria, expulsión con veto, cambio de pista, cierre de sala y eventos
 * en vivo para el emisor.
 */

type RoomEvent = { type: string; [key: string]: unknown };

interface Feed {
  events: RoomEvent[];
  readonly ended: boolean;
  close(): void;
  waitFor(type: string, timeoutMs?: number): Promise<RoomEvent | undefined>;
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
const mp3 = Buffer.concat([Buffer.from("ID3"), Buffer.alloc(64, 1)]);

async function openFeed(url: string, headers: Record<string, string> = {}): Promise<Feed> {
  const abort = new AbortController();
  const events: RoomEvent[] = [];
  let ended = false;
  const response = await fetch(url, { headers, signal: abort.signal });

  if (!response.ok || !response.body) {
    throw new Error(`No se abrió el flujo: HTTP ${response.status}`);
  }

  void (async () => {
    const reader = response.body!.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    try {
      for (;;) {
        const { value, done } = await reader.read();

        if (done) {
          ended = true;
          return;
        }

        buffer += decoder.decode(value, { stream: true });

        let newline = buffer.indexOf("\n");

        while (newline >= 0) {
          const line = buffer.slice(0, newline).trim();
          buffer = buffer.slice(newline + 1);
          newline = buffer.indexOf("\n");

          if (line) {
            events.push(JSON.parse(line) as RoomEvent);
          }
        }
      }
    } catch {
      ended = true;
    }
  })();

  return {
    events,
    get ended() {
      return ended;
    },
    close: () => abort.abort(),
    async waitFor(type, timeoutMs = 2000) {
      const deadline = Date.now() + timeoutMs;

      while (Date.now() < deadline) {
        const found = events.find((event) => event.type === type);

        if (found) {
          return found;
        }

        await sleep(20);
      }

      return events.find((event) => event.type === type);
    },
  };
}

describe("Controles del emisor", () => {
  let directory: string;
  let app: Express;
  let server: Server;
  let baseUrl: string;
  const feeds: Feed[] = [];

  const api = async (
    method: string,
    path: string,
    options: { key?: string; body?: unknown; headers?: Record<string, string>; raw?: Buffer } = {},
  ) => {
    const headers: Record<string, string> = { ...(options.headers ?? {}) };

    if (options.key) {
      headers.Authorization = `Bearer ${options.key}`;
    }

    let body: BodyInit | undefined;

    if (options.raw) {
      headers["Content-Type"] = "audio/mpeg";
      body = new Uint8Array(options.raw);
    } else if (options.body !== undefined) {
      headers["Content-Type"] = "application/json";
      body = JSON.stringify(options.body);
    }

    const response = await fetch(`${baseUrl}${path}`, { method, headers, body });
    const text = await response.text();

    return {
      status: response.status,
      json: text ? (JSON.parse(text) as Record<string, any>) : {},
    };
  };

  const newRoom = async (emitterId = "Ana") => {
    const res = await api("POST", "/rooms", { body: { emitterId } });
    expect(res.status).toBe(201);
    return { roomId: res.json.roomId as string, key: res.json.emitterKey as string };
  };

  const joinRoom = async (roomId: string, receiverId: string) => {
    const res = await api("POST", `/rooms/${roomId}/receivers`, { body: { receiverId } });
    expect(res.status).toBe(201);
  };

  const watch = async (roomId: string, key: string) => {
    const feed = await openFeed(`${baseUrl}/rooms/${roomId}/events`, {
      Authorization: `Bearer ${key}`,
    });
    feeds.push(feed);
    return feed;
  };

  const listen = async (roomId: string, receiverId: string) => {
    const feed = await openFeed(`${baseUrl}/rooms/${roomId}/stream/${receiverId}`);
    feeds.push(feed);
    return feed;
  };

  beforeEach(async () => {
    directory = mkdtempSync(join(tmpdir(), "audioshare-emitter-"));
    app = createApp({ databaseFile: join(directory, "audioshare.sqlite") });
    server = app.listen(0);
    await new Promise((resolve) => server.once("listening", resolve));
    baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  });

  afterEach(async () => {
    feeds.splice(0).forEach((feed) => feed.close());
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
    app.locals.close();
    rmSync(directory, { recursive: true, force: true });
  });

  describe("llave de emisor (AM-01)", () => {
    it("la sala nueva entrega una llave, y solo una vez", async () => {
      const { roomId, key } = await newRoom();

      expect(key.length).toBeGreaterThanOrEqual(30);

      const room = await api("GET", `/rooms/${roomId}`);
      expect(JSON.stringify(room.json)).not.toContain(key);
    });

    it.each([
      ["POST", "play"],
      ["POST", "pause"],
      ["POST", "audio"],
      ["POST", "kick"],
      ["POST", "seek"],
      ["GET", "events"],
      ["DELETE", ""],
    ])("%s /rooms/:id/%s sin llave responde 401 y con una llave ajena 403", async (method, action) => {
      const { roomId } = await newRoom();
      const other = await newRoom("Otro");
      const path = `/rooms/${roomId}${action ? `/${action}` : ""}`;
      const body =
        action === "kick"
          ? { receiverId: "x" }
          : action === "seek"
            ? { positionMs: 1000 }
            : method === "GET"
              ? undefined
              : {};

      expect((await api(method, path, { body })).status).toBe(401);
      expect((await api(method, path, { key: other.key, body })).status).toBe(403);
      expect((await api("GET", `/rooms/${roomId}`)).status).toBe(200);
    });

    it("subir una pista sin llave se rechaza antes de leer el archivo", async () => {
      const { roomId, key } = await newRoom();

      expect((await api("POST", `/rooms/${roomId}/track`, { raw: mp3 })).status).toBe(401);
      expect((await api("POST", `/rooms/${roomId}/track`, { raw: mp3, key: "mala" })).status).toBe(403);
      expect((await api("POST", `/rooms/${roomId}/track`, { raw: mp3, key })).status).toBe(201);
    });

    it("con la llave se puede reproducir y pausar; los receptores no", async () => {
      const { roomId, key } = await newRoom();
      await joinRoom(roomId, "Luis");

      expect((await api("POST", `/rooms/${roomId}/play`, { key })).status).toBe(200);
      expect((await api("POST", `/rooms/${roomId}/pause`, { key })).status).toBe(200);
      expect((await api("POST", `/rooms/${roomId}/play`)).status).toBe(401);
    });

    it("volver como emisor exige la llave", async () => {
      const { roomId, key } = await newRoom("Ana");

      const ok = await api("POST", `/rooms/${roomId}/emitter`, { key });
      expect(ok.status).toBe(200);
      expect(ok.json).toEqual({ roomId, emitterId: "Ana", role: "emitter" });

      expect((await api("POST", `/rooms/${roomId}/emitter`, { body: { emitterId: "Ana" } })).status).toBe(401);
      expect((await api("POST", `/rooms/${roomId}/emitter`, { key: "mala" })).status).toBe(403);
      expect((await api("POST", "/rooms/000000/emitter", { key })).status).toBe(404);
    });
  });

  describe("salir de la sala", () => {
    it("un receptor que sale desaparece de la sala y el emisor se entera", async () => {
      const { roomId, key } = await newRoom();
      await joinRoom(roomId, "Luis");
      const feed = await watch(roomId, key);

      const left = await api("DELETE", `/rooms/${roomId}/receivers/Luis`);
      expect(left.status).toBe(204);

      const event = await feed.waitFor("participant.left");
      expect(event).toMatchObject({ receiverId: "Luis", reason: "left" });

      const room = await api("GET", `/rooms/${roomId}`);
      expect(room.json.participants.map((p: { id: string }) => p.id)).toEqual(["Ana"]);
    });

    it("quien sale puede volver a entrar", async () => {
      const { roomId } = await newRoom();
      await joinRoom(roomId, "Luis");
      await api("DELETE", `/rooms/${roomId}/receivers/Luis`);

      await joinRoom(roomId, "Luis");
    });

    it("no se puede sacar al emisor ni a alguien que no está", async () => {
      const { roomId } = await newRoom("Ana");

      expect((await api("DELETE", `/rooms/${roomId}/receivers/Ana`)).status).toBe(404);
      expect((await api("DELETE", `/rooms/${roomId}/receivers/nadie`)).status).toBe(404);
    });

    it("cuando alguien entra, se conecta o se desconecta, el emisor lo ve", async () => {
      const { roomId, key } = await newRoom();
      const feed = await watch(roomId, key);

      await joinRoom(roomId, "Luis");
      expect(await feed.waitFor("participant.joined")).toMatchObject({
        participant: { id: "Luis", role: "receiver", connected: false },
      });

      const stream = await listen(roomId, "Luis");
      expect(await feed.waitFor("participant.connected")).toMatchObject({ receiverId: "Luis" });

      const online = await api("GET", `/rooms/${roomId}`);
      expect(online.json.participants.find((p: { id: string }) => p.id === "Luis").connected).toBe(true);

      stream.close();
      expect(await feed.waitFor("participant.disconnected")).toMatchObject({ receiverId: "Luis" });

      const offline = await api("GET", `/rooms/${roomId}`);
      expect(offline.json.participants.find((p: { id: string }) => p.id === "Luis").connected).toBe(false);
    });
  });

  describe("expulsar", () => {
    it("el emisor expulsa a un receptor, que recibe el aviso y no puede volver", async () => {
      const { roomId, key } = await newRoom();
      await joinRoom(roomId, "Luis");
      await joinRoom(roomId, "Marta");
      const luis = await listen(roomId, "Luis");
      const marta = await listen(roomId, "Marta");

      const kicked = await api("POST", `/rooms/${roomId}/kick`, { key, body: { receiverId: "Luis" } });
      expect(kicked.status).toBe(204);

      expect(await luis.waitFor("participant.left")).toMatchObject({ receiverId: "Luis", reason: "removed" });
      expect(await marta.waitFor("participant.left")).toMatchObject({ receiverId: "Luis", reason: "removed" });
      await sleep(100);
      expect(luis.ended).toBe(true);

      const again = await api("POST", `/rooms/${roomId}/receivers`, { body: { receiverId: "Luis" } });
      expect(again.status).toBe(403);

      const stream = await fetch(`${baseUrl}/rooms/${roomId}/stream/Luis`);
      expect(stream.status).toBe(404);
    });

    it("expulsar a quien no está, o sin nombre, falla con claridad", async () => {
      const { roomId, key } = await newRoom();

      expect((await api("POST", `/rooms/${roomId}/kick`, { key, body: { receiverId: "nadie" } })).status).toBe(404);
      expect((await api("POST", `/rooms/${roomId}/kick`, { key, body: {} })).status).toBe(400);
    });
  });

  describe("cambiar la canción", () => {
    it("registra nombre y versión, detiene la sala y avisa a todos", async () => {
      const { roomId, key } = await newRoom();
      await joinRoom(roomId, "Luis");
      const luis = await listen(roomId, "Luis");
      const feed = await watch(roomId, key);

      await api("POST", `/rooms/${roomId}/track`, {
        key,
        raw: mp3,
        headers: { "X-Track-Name": encodeURIComponent("Canción número 1.mp3") },
      });
      await api("POST", `/rooms/${roomId}/play`, { key });

      const first = await api("GET", `/rooms/${roomId}`);
      expect(first.json.trackName).toBe("Canción número 1.mp3");
      expect(first.json.trackVersion).toBe(1);
      expect(first.json.status).toBe("playing");

      await api("POST", `/rooms/${roomId}/track`, {
        key,
        raw: mp3,
        headers: { "X-Track-Name": encodeURIComponent("Otra.mp3") },
      });

      const second = await api("GET", `/rooms/${roomId}`);
      expect(second.json.trackName).toBe("Otra.mp3");
      expect(second.json.trackVersion).toBe(2);
      expect(second.json.status).toBe("stopped");
      expect(second.json.startAt).toBeNull();
      expect(second.json.playbackState).toEqual({ playing: false, positionMs: 0 });

      const changes = luis.events.filter((event) => event.type === "track.changed");
      await sleep(100);
      expect(changes.length).toBeGreaterThanOrEqual(1);
      expect((await feed.waitFor("track.changed"))).toMatchObject({ trackName: "Canción número 1.mp3", trackVersion: 1 });
    });

    it("sin nombre queda en null y un nombre largo se recorta", async () => {
      const { roomId, key } = await newRoom();

      await api("POST", `/rooms/${roomId}/track`, { key, raw: mp3 });
      expect((await api("GET", `/rooms/${roomId}`)).json.trackName).toBeNull();

      await api("POST", `/rooms/${roomId}/track`, {
        key,
        raw: mp3,
        headers: { "X-Track-Name": "x".repeat(300) },
      });
      expect(((await api("GET", `/rooms/${roomId}`)).json.trackName as string).length).toBe(100);
    });
  });

  describe("adelantar y atrasar la canción", () => {
    it("en pausa guarda la posición y avisa con sync.pause", async () => {
      const { roomId, key } = await newRoom();
      await joinRoom(roomId, "Luis");
      const luis = await listen(roomId, "Luis");

      const res = await api("POST", `/rooms/${roomId}/seek`, { key, body: { positionMs: 42_000 } });

      expect(res.status).toBe(200);
      expect(res.json).toMatchObject({ type: "sync.pause", positionMs: 42_000, status: "paused" });
      expect(await luis.waitFor("sync.pause")).toMatchObject({ positionMs: 42_000 });

      const room = await api("GET", `/rooms/${roomId}`);
      expect(room.json.playbackState).toEqual({ playing: false, positionMs: 42_000 });
    });

    it("sonando reprograma el arranque con la posición pedida", async () => {
      const { roomId, key } = await newRoom();
      await joinRoom(roomId, "Luis");
      const luis = await listen(roomId, "Luis");
      await api("POST", `/rooms/${roomId}/play`, { key });
      const first = (await api("GET", `/rooms/${roomId}`)).json;

      const res = await api("POST", `/rooms/${roomId}/seek`, { key, body: { positionMs: 90_000 } });

      expect(res.status).toBe(200);
      expect(res.json).toMatchObject({ type: "sync.start", positionMs: 90_000, status: "playing" });
      expect(res.json.startAt).toBeGreaterThanOrEqual(first.startAt);

      await sleep(150);
      const starts = luis.events.filter((event) => event.type === "sync.start");
      expect(starts.length).toBeGreaterThanOrEqual(2);
      expect(starts[starts.length - 1]).toMatchObject({ positionMs: 90_000 });

      const room = (await api("GET", `/rooms/${roomId}`)).json;
      expect(room.status).toBe("playing");
      expect(room.playbackState.positionMs).toBe(90_000);
    });

    it("reanudar después de adelantar parte de la nueva posición", async () => {
      const { roomId, key } = await newRoom();
      await api("POST", `/rooms/${roomId}/seek`, { key, body: { positionMs: 30_000 } });

      const play = await api("POST", `/rooms/${roomId}/play`, { key });

      expect(play.json.positionMs).toBe(30_000);
    });

    it.each([
      ["negativa", -1],
      ["no numérica", "10"],
      ["absurda", 999_999_999_999],
      ["no finita", null],
    ])("rechaza una posición %s", async (_label, positionMs) => {
      const { roomId, key } = await newRoom();

      expect((await api("POST", `/rooms/${roomId}/seek`, { key, body: { positionMs } })).status).toBe(400);
      expect((await api("POST", `/rooms/${roomId}/seek`, { key, body: {} })).status).toBe(400);
    });
  });

  describe("cerrar la sala", () => {
    it("avisa, borra la sala y su pista y corta las conexiones", async () => {
      const { roomId, key } = await newRoom();
      await joinRoom(roomId, "Luis");
      await api("POST", `/rooms/${roomId}/track`, { key, raw: mp3 });
      const track = join(directory, "tracks", `${roomId}.mp3`);
      expect(existsSync(track)).toBe(true);
      const luis = await listen(roomId, "Luis");

      const closed = await api("DELETE", `/rooms/${roomId}`, { key });
      expect(closed.status).toBe(204);

      expect(await luis.waitFor("room.closed")).toBeDefined();
      expect(existsSync(track)).toBe(false);
      expect((await api("GET", `/rooms/${roomId}`)).status).toBe(404);
    });
  });
});


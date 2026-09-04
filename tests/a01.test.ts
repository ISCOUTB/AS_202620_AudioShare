import { describe, expect, it } from "vitest";
import request from "supertest";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createApp } from "../src/app.js";

describe("A-01 - Sincronización de reproducción de audio", () => {
  it("crea una sala, agrega receptores y distribuye eventos", async () => {
    const directory = mkdtempSync(join(tmpdir(), "audioshare-a01-"));
    const app = createApp({ databaseFile: join(directory, "audioshare.sqlite") });

    try {
      const roomResponse = await request(app)
        .post("/rooms")
        .send({ emitterId: "emitter-1" })
        .expect(201);

      const roomId = roomResponse.body.roomId;

      expect(roomId).toBeDefined();

      await request(app)
        .post(`/rooms/${roomId}/receivers`)
        .send({ receiverId: "receiver-1" })
        .expect(201);

      await request(app)
        .post(`/rooms/${roomId}/receivers`)
        .send({ receiverId: "receiver-2" })
        .expect(201);

      const room = await request(app).get(`/rooms/${roomId}`).expect(200);

      expect(room.body.participants).toHaveLength(3);

      const play = await request(app)
        .post(`/rooms/${roomId}/play`)
        .send({ payload: "audio-demo" })
        .expect(200);

      expect(play.body.type).toBe("sync.start");
      expect(play.body.status).toBe("playing");
      expect(play.body.startAt).toBeDefined();
      expect(play.body.participants).toHaveLength(3);
      expect(play.body.audioChunk).toMatchObject({
        type: "audio.chunk",
        sequence: 1,
        payload: "audio-demo",
      });

      const persistedRoom = await request(app)
        .get(`/rooms/${roomId}`)
        .expect(200);

      expect(persistedRoom.body.status).toBe("playing");
      expect(persistedRoom.body.playbackState).toEqual({
        playing: true,
        positionMs: 0,
      });
      expect(persistedRoom.body.startAt).toBe(play.body.startAt);
      expect(persistedRoom.body.participants).toHaveLength(3);

      const audio = await request(app)
        .post(`/rooms/${roomId}/audio`)
        .send({ payload: "audio-follow-up" })
        .expect(200);

      expect(audio.body.type).toBe("audio.chunk");
      expect(audio.body.sequence).toBe(2);
      expect(audio.body.payload).toBe("audio-follow-up");
    } finally {
      app.locals.close();
      rmSync(directory, { recursive: true, force: true });
    }
  });

  it("persiste la sala y sus receptores entre instancias", async () => {
    const directory = mkdtempSync(join(tmpdir(), "audioshare-a01-"));
    const persistenceFile = join(directory, "rooms.json");

    try {
      const firstApp = createApp({ databaseFile: persistenceFile });
      const roomResponse = await request(firstApp)
        .post("/rooms")
        .send({ emitterId: "persistent-emitter" })
        .expect(201);
      const roomId = roomResponse.body.roomId;

      await request(firstApp)
        .post(`/rooms/${roomId}/receivers`)
        .send({ receiverId: "persistent-receiver" })
        .expect(201);

      firstApp.locals.close();

      const secondApp = createApp({ databaseFile: persistenceFile });
      const room = await request(secondApp).get(`/rooms/${roomId}`).expect(200);

      expect(room.body.participants).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ id: "persistent-emitter", role: "emitter" }),
          expect.objectContaining({ id: "persistent-receiver", role: "receiver" }),
        ]),
      );
      secondApp.locals.close();
    } finally {
      rmSync(directory, { recursive: true, force: true });
    }
  });
});
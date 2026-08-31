import { describe, expect, it } from "vitest";
import request from "supertest";
import { createApp } from "../src/app.js";

describe("A-01 - Sincronización de reproducción de audio", () => {
  it("crea una sala, agrega receptores y distribuye eventos", async () => {
    const app = createApp();

    // Crear sala
    const roomResponse = await request(app)
      .post("/rooms")
      .send({
        emitterId: "emitter-1",
      })
      .expect(201);

    const roomId = roomResponse.body.roomId;

    expect(roomId).toBeDefined();

    // Agregar receptores
    await request(app)
      .post(`/rooms/${roomId}/receivers`)
      .send({
        receiverId: "receiver-1",
      })
      .expect(201);

    await request(app)
      .post(`/rooms/${roomId}/receivers`)
      .send({
        receiverId: "receiver-2",
      })
      .expect(201);

    // Verificar sala
    const room = await request(app)
      .get(`/rooms/${roomId}`)
      .expect(200);

    expect(room.body.participants).toHaveLength(3);

    // Ejecutar PLAY
    const play = await request(app)
      .post(`/rooms/${roomId}/play`)
      .expect(200);

    expect(play.body.type).toBe("sync.start");
    expect(play.body.startAt).toBeDefined();

    // Enviar audio
    const audio = await request(app)
      .post(`/rooms/${roomId}/audio`)
      .send({
        payload: "audio-demo",
      })
      .expect(200);

    expect(audio.body.type).toBe("audio.chunk");
    expect(audio.body.sequence).toBe(1);
    expect(audio.body.payload).toBe("audio-demo");
  });
});
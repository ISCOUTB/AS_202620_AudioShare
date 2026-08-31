import express, { type Express, type Request, type Response } from "express";
import { SessionManager } from "./modules/session/index.js";
import { AudioStreamHub } from "./modules/audio/index.js";
import { SyncCoordinator } from "./modules/sync/index.js";

interface Client {
  id: string;
  send: (event: unknown) => void;
}

export function createApp(): Express {
  const app = express();

  app.use(express.json());

  const sessions = new SessionManager();
  const audio = new AudioStreamHub();

  const streams = new Map<string, Map<string, Client>>();

  /*
   * Crea una sala.
   *
   * El participante que crea la sala se registra como emisor.
   */
  app.post("/rooms", (req: Request, res: Response) => {
    const emitterId = req.body?.emitterId ?? crypto.randomUUID();

    const room = sessions.createRoom(emitterId);

    streams.set(room.id, new Map());

    res.status(201).json({
      roomId: room.id,
      emitterId,
    });
  });

  /*
   * Agrega un receptor a una sala.
   */
  app.post(
    "/rooms/:roomId/receivers",
    (req: Request, res: Response) => {
      const { roomId } = req.params;
      const receiverId = req.body?.receiverId ?? crypto.randomUUID();

      try {
        const receiver = sessions.addReceiver(roomId, receiverId);

        res.status(201).json({
          roomId,
          receiverId: receiver.id,
          role: receiver.role,
        });
      } catch {
        res.status(404).json({
          error: "Sala no encontrada",
        });
      }
    },
  );

  /*
   * Stream de eventos para un receptor.
   *
   * Se utiliza NDJSON: cada evento se envía como una línea JSON.
   */
  app.get(
    "/rooms/:roomId/stream/:receiverId",
    (req: Request, res: Response) => {
      const { roomId, receiverId } = req.params;

      const room = sessions.getRoom(roomId);

      if (!room) {
        res.status(404).json({
          error: "Sala no encontrada",
        });
        return;
      }

      const receiver = room.participants.get(receiverId);

      if (!receiver || receiver.role !== "receiver") {
        res.status(404).json({
          error: "Receptor no encontrado",
        });
        return;
      }

      res.status(200);
      res.setHeader("Content-Type", "application/x-ndjson");
      res.setHeader("Cache-Control", "no-cache");
      res.setHeader("Connection", "keep-alive");

      const roomStreams = streams.get(roomId);

      if (!roomStreams) {
        res.end();
        return;
      }

      const client: Client = {
        id: receiverId,
        send: (event: unknown) => {
          res.write(`${JSON.stringify(event)}\n`);
        },
      };

      roomStreams.set(receiverId, client);

      req.on("close", () => {
        roomStreams.delete(receiverId);
      });
    },
  );

  /*
   * PLAY:
   *
   * El emisor solicita comenzar la reproducción.
   * SyncCoordinator genera un único startAt que se distribuye
   * a todos los receptores conectados.
   */
  app.post("/rooms/:roomId/play", (req: Request, res: Response) => {
    const { roomId } = req.params;

    const room = sessions.getRoom(roomId);

    if (!room) {
      res.status(404).json({
        error: "Sala no encontrada",
      });
      return;
    }

    const sync = new SyncCoordinator();
    const event = sync.start();

    const roomStreams = streams.get(roomId);

    if (roomStreams) {
      for (const client of roomStreams.values()) {
        client.send(event);
      }
    }

    res.status(200).json(event);
  });

  /*
   * PAUSE:
   *
   * Detiene la reproducción y comunica la posición actual.
   */
  app.post("/rooms/:roomId/pause", (req: Request, res: Response) => {
    const { roomId } = req.params;

    const room = sessions.getRoom(roomId);

    if (!room) {
      res.status(404).json({
        error: "Sala no encontrada",
      });
      return;
    }

    const sync = new SyncCoordinator();
    const event = sync.pause();

    const roomStreams = streams.get(roomId);

    if (roomStreams) {
      for (const client of roomStreams.values()) {
        client.send(event);
      }
    }

    res.status(200).json(event);
  });

  /*
   * Distribuye un paquete de audio a todos los receptores conectados.
   */
  app.post("/rooms/:roomId/audio", (req: Request, res: Response) => {
    const { roomId } = req.params;

    const room = sessions.getRoom(roomId);

    if (!room) {
      res.status(404).json({
        error: "Sala no encontrada",
      });
      return;
    }

    if (typeof req.body?.payload !== "string") {
      res.status(400).json({
        error: "payload debe ser un string",
      });
      return;
    }

    const chunk = audio.createChunk(req.body.payload);

    const roomStreams = streams.get(roomId);

    if (roomStreams) {
      for (const client of roomStreams.values()) {
        client.send(chunk);
      }
    }

    res.status(200).json(chunk);
  });

  /*
   * Consulta el estado de la sala.
   */
  app.get("/rooms/:roomId", (req: Request, res: Response) => {
    const { roomId } = req.params;

    const room = sessions.getRoom(roomId);

    if (!room) {
      res.status(404).json({
        error: "Sala no encontrada",
      });
      return;
    }

    res.status(200).json({
      roomId: room.id,
      participants: Array.from(room.participants.values()),
      connectedReceivers: streams.get(roomId)?.size ?? 0,
    });
  });

  /*
   * Endpoint original del esqueleto.
   *
   * Se conserva para comprobar que la aplicación arranca.
   */
  app.get("/health", (_req, res) => {
    res.status(200).json({
      status: "ok",
      system: "AudioShare",
      modules: ["session", "audio", "sync"],
    });
  });

  return app;
}
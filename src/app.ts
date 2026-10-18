import express, { type Express, type Request, type Response } from "express";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import {
  SessionApplication,
  SQLiteRoomRepository,
} from "./modules/session/index.js";
import { AudioStreamHub } from "./modules/audio/index.js";
import {
  SyncCoordinator,
  SyncMeasurements,
  toServerClock,
} from "./modules/sync/index.js";
import { config } from "./shared/config.js";
import { log } from "./shared/logger.js";
import { metrics, metricsHandler } from "./shared/metrics.js";

interface Client {
  id: string;
  send: (event: unknown) => void;
  /** Termina la respuesta de esta conexión (FM-01: reemplazo por reconexión). */
  close: () => void;
}

export function createApp(
  options: { databaseFile?: string; serveFlutterWeb?: boolean } = {},
): Express {
  const app = express();

  app.use((req: Request, res: Response, next) => {
    const origin = req.header("Origin");

    if (origin) {
      res.setHeader("Access-Control-Allow-Origin", origin);
      res.setHeader("Vary", "Origin");
    }

    res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.sendStatus(204);
      return;
    }

    next();
  });

  app.use(express.json());

  const sessions = new SessionApplication(
    new SQLiteRoomRepository(options.databaseFile ?? config.databaseFile),
  );
  const audio = new AudioStreamHub();

  const streams = new Map<string, Map<string, Client>>();
  const measurements = new SyncMeasurements();
  // Instante en que arrancó este servicio. Se expone en /health para poder
  // comprobar desde fuera si el proceso se reinició (por ejemplo tras un
  // redespliegue) y desde cuándo corre.
  const startedAt = new Date().toISOString();
  const coordinators = new Map<string, SyncCoordinator>();

  // Las conexiones de una sala se crean bajo demanda. Antes solo se creaban en
  // POST /rooms, así que una sala restaurada de SQLite tras un reinicio no
  // tenía entrada y su stream terminaba de inmediato (FM-02).
  const streamsFor = (roomId: string): Map<string, Client> => {
    let roomStreams = streams.get(roomId);

    if (!roomStreams) {
      roomStreams = new Map<string, Client>();
      streams.set(roomId, roomStreams);
    }

    return roomStreams;
  };

  // Un coordinador por sala: antes se creaba uno nuevo en cada petición y
  // su estado se perdía.
  const coordinatorFor = (roomId: string): SyncCoordinator => {
    let coordinator = coordinators.get(roomId);

    if (!coordinator) {
      coordinator = new SyncCoordinator();
      coordinators.set(roomId, coordinator);
    }

    return coordinator;
  };

  app.locals.close = () => sessions.close();

  const flutterWebDirectory = resolve(process.cwd(), "build/web");
  const legacyWebDirectory = resolve(
    dirname(fileURLToPath(import.meta.url)),
    "../public",
  );
  const webDirectory = options.serveFlutterWeb &&
      existsSync(resolve(flutterWebDirectory, "index.html"))
    ? flutterWebDirectory
    : legacyWebDirectory;

  app.use(express.static(webDirectory));

  /*
   * Crea una sala.
   *
   * El participante que crea la sala se registra como emisor.
   */
  app.post("/rooms", (req: Request, res: Response) => {
    const emitterId = req.body?.emitterId ?? crypto.randomUUID();

    const room = sessions.createRoom(emitterId);

    streams.set(room.id, new Map());

    metrics.roomsCreated += 1;
    log.info("room.created", { roomId: room.id, emitterId });

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

      const receiver = room.participants.find(
        (participant) => participant.id === receiverId,
      );

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

      const roomStreams = streamsFor(roomId);

      // Envía las cabeceras ya: el receptor sabe que quedó registrado sin
      // esperar al primer evento.
      res.flushHeaders();

      const client: Client = {
        id: receiverId,
        send: (event: unknown) => {
          res.write(`${JSON.stringify(event)}\n`);
        },
        close: () => {
          res.end();
        },
      };

      // Una conexión viva por receptor: la nueva reemplaza a la anterior y la
      // cierra (FM-01).
      const previous = roomStreams.get(receiverId);

      roomStreams.set(receiverId, client);
      previous?.close();

      // El cierre solo borra el registro propio. Antes borraba el del
      // receptor aunque ya perteneciera a una conexión más nueva (FM-01).
      req.on("close", () => {
        if (roomStreams.get(receiverId) === client) {
          roomStreams.delete(receiverId);
        }
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

    const sync = coordinatorFor(roomId);
    const event = sync.start();
    const updatedRoom = sessions.startPlayback(roomId, event.startAt);
    const audioChunk = audio.createChunk(req.body?.payload ?? "audio-demo");

    const roomStreams = streams.get(roomId);

    if (roomStreams) {
      for (const client of roomStreams.values()) {
        client.send(event);
        client.send(audioChunk);
      }
    }

    metrics.playEvents += 1;
    metrics.lastPlayReceiverCount = roomStreams?.size ?? 0;
    metrics.lastPlayAt = new Date().toISOString();
    log.info("room.play", {
      roomId,
      receiverCount: metrics.lastPlayReceiverCount,
      startAt: event.startAt,
    });

    res.status(200).json({
      ...event,
      roomId: updatedRoom.id,
      status: updatedRoom.status,
      playbackState: updatedRoom.playbackState,
      startAt: updatedRoom.startAt,
      participants: updatedRoom.participants,
      audioChunk,
    });
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

    const sync = coordinatorFor(roomId);
    const event = sync.pause();
    const updatedRoom = sessions.pausePlayback(roomId, event.positionMs);

    const roomStreams = streams.get(roomId);

    if (roomStreams) {
      for (const client of roomStreams.values()) {
        client.send(event);
      }
    }

    res.status(200).json({
      ...event,
      roomId: updatedRoom.id,
      status: updatedRoom.status,
      playbackState: updatedRoom.playbackState,
      startAt: updatedRoom.startAt,
    });
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
   * Reloj del servidor. Los receptores toman muestras de este endpoint para
   * estimar su offset de reloj antes de programar el arranque (ADR-0005).
   */
  app.get("/time", (_req: Request, res: Response) => {
    res.status(200).json({ serverTime: Date.now() });
  });

  /*
   * ACK de arranque: el receptor informa cuándo (en su reloj local) empezó
   * a reproducir y qué offset de reloj estimó. El servidor lo lleva a su
   * propio reloj para medir el desfase entre receptores (EC-01).
   */
  app.post(
    "/rooms/:roomId/receivers/:receiverId/ack",
    (req: Request, res: Response) => {
      const { roomId, receiverId } = req.params;
      const { startedAt, offsetMs } = req.body ?? {};

      const room = sessions.getRoom(roomId);

      if (!room) {
        res.status(404).json({ error: "Sala no encontrada" });
        return;
      }

      const receiver = room.participants.find(
        (participant) => participant.id === receiverId,
      );

      if (!receiver || receiver.role !== "receiver") {
        res.status(404).json({ error: "Receptor no encontrado" });
        return;
      }

      if (!Number.isFinite(startedAt) || !Number.isFinite(offsetMs)) {
        res.status(400).json({
          error: "startedAt y offsetMs deben ser números",
        });
        return;
      }

      if (room.startAt === null) {
        res.status(409).json({ error: "La sala no ha iniciado reproducción" });
        return;
      }

      const ack = measurements.record(
        roomId,
        room.startAt,
        receiverId,
        toServerClock(startedAt, offsetMs),
      );
      const report = measurements.report(roomId, room.startAt);

      if (report.spreadMs !== null) {
        metrics.lastSyncSpreadMs = report.spreadMs;
        metrics.maxSyncSpreadMs = Math.max(
          metrics.maxSyncSpreadMs ?? 0,
          report.spreadMs,
        );
      }

      log.info("receiver.ack", {
        roomId,
        receiverId,
        startAt: room.startAt,
        deviationMs: ack.deviationMs,
        spreadMs: report.spreadMs,
      });

      res.status(200).json({ roomId, startAt: room.startAt, ...ack });
    },
  );

  /*
   * Informe de sincronización de la última reproducción de la sala.
   */
  app.get("/rooms/:roomId/sync", (req: Request, res: Response) => {
    const { roomId } = req.params;
    const room = sessions.getRoom(roomId);

    if (!room) {
      res.status(404).json({ error: "Sala no encontrada" });
      return;
    }

    if (room.startAt === null) {
      res.status(409).json({ error: "La sala no ha iniciado reproducción" });
      return;
    }

    res.status(200).json(measurements.report(roomId, room.startAt));
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
      createdAt: room.createdAt,
      status: room.status,
      playbackState: room.playbackState,
      startAt: room.startAt,
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
      startedAt,
    });
  });

  /*
   * Métrica consultable, ligada al aspecto A-01 y a EC-01/EC-04.
   * Ver src/shared/metrics.ts para la nota honesta sobre qué mide hoy.
   */
  app.get("/metrics", metricsHandler);

  return app;
}
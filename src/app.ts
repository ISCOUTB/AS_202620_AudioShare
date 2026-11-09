import express, {
  type Express,
  type NextFunction,
  type Request,
  type Response,
} from "express";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import {
  PARTICIPANT_ROLE_CONFLICT,
  SessionApplication,
  SQLiteRoomRepository,
} from "./modules/session/index.js";
import { AudioStreamHub, AudioTrackStore } from "./modules/audio/index.js";
import {
  SyncCoordinator,
  SyncMeasurements,
  positionAt,
  toServerClock,
} from "./modules/sync/index.js";
import { config } from "./shared/config.js";
import { FailedLookupLimiter } from "./shared/failed-lookup-limiter.js";
import { log } from "./shared/logger.js";
import { metrics, metricsHandler } from "./shared/metrics.js";

interface Client {
  id: string;
  send: (event: unknown) => void;
  /** Termina la respuesta de esta conexión (FM-01: reemplazo por reconexión). */
  close: () => void;
}

/** Longitud máxima del nombre (identificador) de un participante. */
const MAX_PARTICIPANT_ID_LENGTH = 30;
/** Cada cuánto, como máximo, se registra actividad de una sala en SQLite. */
const TOUCH_INTERVAL_MS = 60_000;
/** Cada cuánto se buscan salas caducadas. */
const SWEEP_INTERVAL_MS = 10 * 60_000;
/** Espera antes de la primera búsqueda de salas caducadas tras arrancar. */
const SWEEP_STARTUP_DELAY_MS = 30_000;

type ParsedParticipantId = { ok: true; id: string } | { ok: false; error: string };

/**
 * Valida el nombre que el cliente elige como identificador. Si se omite y no
 * es obligatorio, el servidor genera uno (compatibilidad con clientes
 * anteriores). Se guarda recortado.
 */
function parseParticipantId(value: unknown, required = false): ParsedParticipantId {
  if (value === undefined || value === null) {
    return required
      ? { ok: false, error: "El identificador es obligatorio" }
      : { ok: true, id: crypto.randomUUID() };
  }

  if (typeof value !== "string") {
    return { ok: false, error: "El identificador debe ser texto" };
  }

  const id = value.trim();

  if (id.length === 0 || id.length > MAX_PARTICIPANT_ID_LENGTH) {
    return {
      ok: false,
      error: `El identificador debe tener entre 1 y ${MAX_PARTICIPANT_ID_LENGTH} caracteres`,
    };
  }

  if (/[\u0000-\u001f\u007f]/.test(id)) {
    return { ok: false, error: "El identificador contiene caracteres no permitidos" };
  }

  return { ok: true, id };
}

export function createApp(
  options: {
    databaseFile?: string;
    serveFlutterWeb?: boolean;
    allowedOrigins?: string[];
    /** Milisegundos sin actividad antes de borrar una sala. 0 = nunca. */
    roomTtlMs?: number;
    /** Si `GET /rooms` lista las salas (cerrado por defecto en producción). */
    exposeRoomList?: boolean;
    /** Tope de consultas a salas inexistentes por origen y ventana (AM-04). */
    lookupLimit?: { max: number; windowMs: number };
  } = {},
): Express {
  const app = express();

  if (config.trustProxy !== undefined) {
    app.set("trust proxy", config.trustProxy);
  }

  const allowedOrigins = new Set(options.allowedOrigins ?? config.corsOrigins);

  app.use((req: Request, res: Response, next) => {
    const origin = req.header("Origin");

    if (origin) {
      if (!allowedOrigins.has(origin)) {
        res.status(403).json({ error: "Origen no permitido" });
        return;
      }

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

  const databaseFile = options.databaseFile ?? config.databaseFile;
  const sessions = new SessionApplication(new SQLiteRoomRepository(databaseFile));
  const audio = new AudioStreamHub();
  const tracks = new AudioTrackStore(resolve(dirname(databaseFile), "tracks"));

  const streams = new Map<string, Map<string, Client>>();
  const measurements = new SyncMeasurements();
  // Instante en que arrancó este servicio. Se expone en /health para poder
  // comprobar desde fuera si el proceso se reinició (por ejemplo tras un
  // redespliegue) y desde cuándo corre.
  const startedAt = new Date().toISOString();
  // Commit servido. Lo inyecta el build (ARG/ENV GIT_SHA en el Dockerfile);
  // sin él, /health informa "unknown" en lugar de inventar un valor.
  const commit = process.env.GIT_SHA?.trim() || "unknown";
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

  const roomTtlMs = options.roomTtlMs ?? config.roomTtlMs;
  const exposeRoomList = options.exposeRoomList ?? config.exposeRoomList;
  const lookupLimiter = new FailedLookupLimiter(
    options.lookupLimit?.max ?? 20,
    options.lookupLimit?.windowMs ?? 60_000,
  );
  const lastTouched = new Map<string, number>();

  const touchRoom = (roomId: string, now: number): void => {
    const previous = lastTouched.get(roomId);

    if (previous !== undefined && now - previous < TOUCH_INTERVAL_MS) {
      return;
    }

    lastTouched.set(roomId, now);

    try {
      sessions.touchRoom(roomId, new Date(now).toISOString());
    } catch (error) {
      // Registrar actividad no debe romper una lectura (p. ej. disco lleno).
      log.warn("room.touch_failed", {
        roomId,
        message: error instanceof Error ? error.message : String(error),
      });
    }
  };

  /*
   * Borra las salas sin actividad desde hace más de `roomTtlMs`, junto con su
   * pista y su estado en memoria (AM-11, FM-15). Una sala con receptores
   * conectados no se borra aunque lleve tiempo sin peticiones.
   */
  const sweepExpiredRooms = async (now = Date.now()): Promise<number> => {
    if (roomTtlMs <= 0) {
      return 0;
    }

    let expired: string[];

    try {
      expired = sessions.inactiveRoomIds(new Date(now - roomTtlMs).toISOString());
    } catch (error) {
      log.error("room.sweep_failed", {
        message: error instanceof Error ? error.message : String(error),
      });
      return 0;
    }

    let removed = 0;

    for (const roomId of expired) {
      if ((streams.get(roomId)?.size ?? 0) > 0) {
        continue;
      }

      try {
        await tracks.delete(roomId);
        sessions.deleteRoom(roomId);
      } catch (error) {
        log.error("room.expire_failed", {
          roomId,
          message: error instanceof Error ? error.message : String(error),
        });
        continue;
      }

      streams.delete(roomId);
      coordinators.delete(roomId);
      measurements.forgetRoom(roomId);
      lastTouched.delete(roomId);
      removed += 1;
      log.info("room.expired", { roomId });
    }

    return removed;
  };

  const sweepTimer = roomTtlMs > 0
    ? setInterval(() => void sweepExpiredRooms(), SWEEP_INTERVAL_MS)
    : undefined;
  const startupSweep = roomTtlMs > 0
    ? setTimeout(() => void sweepExpiredRooms(), SWEEP_STARTUP_DELAY_MS)
    : undefined;
  sweepTimer?.unref();
  startupSweep?.unref();

  app.locals.sweepExpiredRooms = sweepExpiredRooms;
  app.locals.close = () => {
    if (sweepTimer) clearInterval(sweepTimer);
    if (startupSweep) clearTimeout(startupSweep);
    sessions.close();
  };

  /*
   * Todas las rutas con :roomId pasan por aquí. Registra actividad (caducidad)
   * y limita los intentos con códigos inexistentes (el código de 6 dígitos no
   * debe poder recorrerse por fuerza bruta).
   */
  app.param(
    "roomId",
    (req: Request, res: Response, next: NextFunction, roomId: string) => {
      const origin = req.ip ?? "desconocido";
      const now = Date.now();
      const wait = lookupLimiter.retryAfterSeconds(origin, now);

      if (wait > 0) {
        res.setHeader("Retry-After", String(wait));
        res.status(429).json({
          error: "Demasiados intentos con códigos de sala inexistentes. Espera un momento.",
        });
        return;
      }

      let room;

      try {
        room = sessions.getRoom(roomId);
      } catch (error) {
        next(error);
        return;
      }

      if (!room) {
        lookupLimiter.recordFailure(origin, now);
      } else {
        touchRoom(roomId, now);
      }

      next();
    },
  );

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

  app.get("/rooms", (_req: Request, res: Response) => {
    if (!exposeRoomList) {
      res.status(404).json({ error: "No encontrado" });
      return;
    }

    const rooms = sessions.listRooms();

    res.status(200).json(
      rooms.map((room) => ({
        roomId: room.id,
        createdAt: room.createdAt,
        status: room.status,
        playbackState: room.playbackState,
        startAt: room.startAt,
        participants: room.participants,
        connectedReceivers: streams.get(room.id)?.size ?? 0,
      })),
    );
  });

  /*
   * Crea una sala.
   *
   * El participante que crea la sala se registra como emisor.
   */
  app.post("/rooms", (req: Request, res: Response) => {
    const parsed = parseParticipantId(req.body?.emitterId);

    if (!parsed.ok) {
      res.status(400).json({ error: parsed.error });
      return;
    }

    const emitterId = parsed.id;
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
      const parsed = parseParticipantId(req.body?.receiverId);

      if (!parsed.ok) {
        res.status(400).json({ error: parsed.error });
        return;
      }

      const receiverId = parsed.id;

      try {
        const receiver = sessions.addReceiver(roomId, receiverId);

        res.status(201).json({
          roomId,
          receiverId: receiver.id,
          role: receiver.role,
        });
      } catch (error) {
        if (
          error instanceof Error &&
          error.message === PARTICIPANT_ROLE_CONFLICT
        ) {
          res.status(409).json({
            error: "El identificador ya está en uso en esta sala con otro rol",
          });
          return;
        }

        if (error instanceof Error && error.message === "Sala no encontrada") {
          res.status(404).json({
            error: "Sala no encontrada",
          });
          return;
        }

        // Cualquier otro fallo (p. ej. de almacenamiento) ya no se disfraza de
        // «sala no encontrada»: lo atiende el manejador de errores (FM-07).
        throw error;
      }
    },
  );

  /*
   * Vuelve a entrar como emisor. Sin cuentas (AM-01), el emisor se reconoce por
   * el identificador con el que creó la sala; cualquier otro recibe 403.
   */
  app.post("/rooms/:roomId/emitter", (req: Request, res: Response) => {
    const { roomId } = req.params;
    const room = sessions.getRoom(roomId);

    if (!room) {
      res.status(404).json({ error: "Sala no encontrada" });
      return;
    }

    const parsed = parseParticipantId(req.body?.emitterId, true);

    if (!parsed.ok) {
      res.status(400).json({ error: parsed.error });
      return;
    }

    const emitter = room.participants.find(
      (participant) => participant.role === "emitter",
    );

    if (!emitter || emitter.id !== parsed.id) {
      res.status(403).json({
        error: "El identificador no corresponde al emisor de esta sala",
      });
      return;
    }

    res.status(200).json({ roomId, emitterId: emitter.id, role: "emitter" });
  });

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

    // Reanudar continúa desde la posición guardada al pausar; un PLAY con la
    // sala ya sonando conserva la posición actual en vez de reiniciar.
    const resumeFrom =
      room.playbackState.playing && room.startAt !== null
        ? positionAt(room.playbackState.positionMs, room.startAt, Date.now())
        : room.playbackState.positionMs;

    const sync = coordinatorFor(roomId);
    const event = sync.start(resumeFrom);
    const updatedRoom = sessions.startPlayback(
      roomId,
      event.startAt,
      event.positionMs,
    );
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

    // Posición real alcanzada: la guardada al arrancar más lo transcurrido
    // desde startAt. Se calcula desde SQLite, así que sobrevive a reinicios.
    const pausedAt =
      room.playbackState.playing && room.startAt !== null
        ? positionAt(room.playbackState.positionMs, room.startAt, Date.now())
        : room.playbackState.positionMs;

    const sync = coordinatorFor(roomId);
    const event = sync.pause(pausedAt);
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

  app.post(
    "/rooms/:roomId/track",
    express.raw({ type: "audio/mpeg", limit: "50mb" }),
    async (req: Request, res: Response) => {
      const { roomId } = req.params;
      if (!sessions.getRoom(roomId)) {
        res.status(404).json({ error: "Sala no encontrada" });
        return;
      }

      if (!Buffer.isBuffer(req.body) || req.body.length < 2) {
        res.status(400).json({ error: "Se requiere un archivo MP3" });
        return;
      }

      const hasId3Header = req.body.subarray(0, 3).toString("ascii") === "ID3";
      const hasMpegFrameSync =
        req.body[0] === 0xff && (req.body[1] & 0xe0) === 0xe0;
      if (!hasId3Header && !hasMpegFrameSync) {
        res.status(400).json({ error: "El contenido no parece ser un MP3" });
        return;
      }

      try {
        await tracks.save(roomId, req.body);
        res.status(201).json({ roomId, bytes: req.body.length });
      } catch {
        res.status(500).json({ error: "No se pudo guardar la pista de audio" });
      }
    },
  );

  app.get("/rooms/:roomId/track", (req: Request, res: Response) => {
    const { roomId } = req.params;
    if (!sessions.getRoom(roomId)) {
      res.status(404).json({ error: "Sala no encontrada" });
      return;
    }

    const track = tracks.pathFor(roomId);
    if (!existsSync(track)) {
      res.status(404).json({ error: "La sala aún no tiene una pista de audio" });
      return;
    }

    res.setHeader("Cache-Control", "no-store");
    res.type("audio/mpeg").sendFile(track);
  });

  /*
   * Pista de audio de la demostración. Todos los receptores la descargan
   * antes de empezar y la reproducen localmente a partir de `startAt`.
   * Express atiende peticiones Range, que just_audio usa para saltar (seek).
   */
  app.get("/track", (_req: Request, res: Response) => {
    const file = resolve(legacyWebDirectory, "audio/demo.mp3");

    if (!existsSync(file)) {
      res.status(404).json({ error: "Pista no disponible" });
      return;
    }

    // Caché con revalidación (docs/diseno-cache.md): el cliente o un
    // intermediario puede guardar la pista, pero debe validarla con ETag /
    // Last-Modified antes de usarla. Si el archivo cambia en la misma URL,
    // la siguiente petición recibe la versión nueva (antes: max-age=3600).
    res.setHeader("Cache-Control", "public, no-cache");
    res.type("audio/mpeg");
    res.sendFile(file);
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
    // Sigue respondiendo 200 aunque el almacenamiento falle: el HEALTHCHECK de
    // Docker solo debe medir si el proceso vive (si no, el proxy retiraría el
    // servicio entero). Quien monitoree debe leer `storage`.
    const storageWritable = sessions.storageWritable();

    res.status(200).json({
      status: storageWritable ? "ok" : "degraded",
      system: "AudioShare",
      modules: ["session", "audio", "sync"],
      startedAt,
      commit,
      storage: storageWritable ? "ok" : "error",
    });
  });

  /*
   * Métrica consultable, ligada al aspecto A-01 y a EC-01/EC-04.
   * Ver src/shared/metrics.ts para la nota honesta sobre qué mide hoy.
   */
  app.get("/metrics", metricsHandler);

  /*
   * Último manejador: ningún fallo debe terminar en una página HTML de Express
   * (antes, un error de SQLite daba un 500 mudo sin JSON).
   */
  app.use((error: unknown, _req: Request, res: Response, next: NextFunction) => {
    if (res.headersSent) {
      next(error);
      return;
    }

    const details = error as { type?: string; code?: string };
    const message = error instanceof Error ? error.message : String(error);

    if (details.type === "entity.parse.failed") {
      res.status(400).json({ error: "El cuerpo de la petición no es JSON válido" });
      return;
    }

    if (details.type === "entity.too.large") {
      res.status(413).json({ error: "El cuerpo de la petición es demasiado grande" });
      return;
    }

    if (typeof details.code === "string" && details.code.startsWith("SQLITE_")) {
      log.error("storage.error", { code: details.code, message });
      res.status(503).json({
        error: "El servidor no pudo guardar los datos. Intenta de nuevo en unos minutos.",
      });
      return;
    }

    log.error("request.failed", { message });
    res.status(500).json({ error: "Error interno del servidor" });
  });

  return app;
}
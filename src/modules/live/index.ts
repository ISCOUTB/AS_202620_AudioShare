import type { IncomingMessage, Server } from "node:http";
import type { Duplex } from "node:stream";
import { WebSocket, WebSocketServer, type RawData } from "ws";
import { log } from "../../shared/logger.js";

/*
 * Módulo `live`: retransmisión de audio en vivo (ADR-0015).
 *
 * El emisor captura el audio de su dispositivo, de una aplicación o de una
 * pestaña y lo envía por un WebSocket a `/rooms/:roomId/live`. El servidor no
 * decodifica ni mezcla nada: reenvía cada paquete binario, tal cual, a los
 * receptores conectados de la misma sala. Los receptores ordenan la
 * reproducción con la marca de tiempo del paquete (reloj del servidor), la
 * misma referencia temporal que ya usa A-01 (ADR-0005 y ADR-0007).
 *
 * Este módulo no conoce Express ni SQLite: la autorización de la sala y del
 * emisor llega por `LiveRelayHooks`, para respetar el límite de módulo
 * (ADR-0001).
 *
 * Paquete binario (little endian), versión 1:
 *   byte  0      versión del protocolo (1)
 *   byte  1      códec (0 = PCM entero de 16 bits intercalado)
 *   byte  2      canales (1 o 2)
 *   byte  3      reservado (0)
 *   bytes 4-7    frecuencia de muestreo en Hz (uint32)
 *   bytes 8-11   número de secuencia (uint32)
 *   bytes 12-19  instante de captura en reloj del servidor, ms epoch (float64)
 *   bytes 20-    muestras
 *
 * Mensajes de texto (JSON):
 *   cliente -> servidor  {"type":"hello","role":"emitter","key":"..."}
 *                        {"type":"hello","role":"receiver","receiverId":"..."}
 *                        {"type":"live.start","source":"device|app|tab","label":"..."}
 *                        {"type":"live.stop"}
 *   servidor -> cliente  {"type":"ready","role":"emitter|receiver"}
 *                        {"type":"live.state","active":bool,"source":...,"label":...}
 */

export const LIVE_PROTOCOL_VERSION = 1;
export const LIVE_HEADER_BYTES = 20;
export const MAX_PACKET_BYTES = 64 * 1024;

const MAX_CONTROL_BYTES = 2_048;
const MAX_BUFFERED_BYTES = 1024 * 1024;
const MAX_PACKETS_PER_SECOND = 200;
const MAX_RECEIVERS_PER_ROOM = 50;
const MAX_LABEL_LENGTH = 80;
const HELLO_TIMEOUT_MS = 5_000;
const HEARTBEAT_INTERVAL_MS = 20_000;

/** Códigos de cierre del WebSocket. Los clientes no reconectan con 4400-4413. */
export const LIVE_CLOSE = {
  badHello: 4400,
  unauthorized: 4401,
  removed: 4403,
  notFound: 4404,
  replaced: 4409,
  roomClosed: 4410,
  roomFull: 4413,
} as const;

export type LiveSource = "device" | "app" | "tab";

const LIVE_SOURCES: readonly string[] = ["device", "app", "tab"];

export interface LiveState {
  active: boolean;
  source: LiveSource | null;
  label: string | null;
  startedAt: string | null;
}

export interface LiveInfo extends LiveState {
  receivers: number;
}

export type UpgradeDecision =
  | { ok: true }
  | { ok: false; status: number; message: string };

export interface LiveRelayHooks {
  /** Origen permitido, límite de intentos y existencia de la sala. */
  authorizeUpgrade(req: IncomingMessage, roomId: string): UpgradeDecision;
  isEmitterAuthorized(roomId: string, key: string | undefined): boolean;
  hasReceiver(roomId: string, receiverId: string): boolean;
  /** Se llama con cada paquete del emisor (el llamador limita la frecuencia). */
  onActivity?(roomId: string): void;
}

interface RoomLive {
  emitter: WebSocket | null;
  receivers: Map<string, WebSocket>;
  state: LiveState;
  windowStart: number;
  windowPackets: number;
}

type Session =
  | { role: "emitter" }
  | { role: "receiver"; receiverId: string };

const INACTIVE: LiveState = { active: false, source: null, label: null, startedAt: null };

const STATUS_TEXT: Record<number, string> = {
  403: "Forbidden",
  404: "Not Found",
  429: "Too Many Requests",
  500: "Internal Server Error",
};

const noop = (): void => undefined;

function toBuffer(raw: RawData): Buffer {
  if (Array.isArray(raw)) {
    return Buffer.concat(raw);
  }

  return Buffer.isBuffer(raw) ? raw : Buffer.from(raw);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function sanitizeLabel(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const label = value.replace(/[\u0000-\u001f\u007f]/g, "").trim().slice(0, MAX_LABEL_LENGTH);

  return label.length > 0 ? label : null;
}

function roomIdFrom(url: string | undefined): string | null {
  const path = (url ?? "").split("?")[0] ?? "";
  const encoded = /^\/rooms\/([^/]+)\/live$/.exec(path)?.[1];

  if (encoded === undefined) {
    return null;
  }

  try {
    return decodeURIComponent(encoded);
  } catch {
    return null;
  }
}

function rejectUpgrade(socket: Duplex, status: number, message: string): void {
  const body = JSON.stringify({ error: message });

  socket.on("error", noop);
  socket.write(
    `HTTP/1.1 ${status} ${STATUS_TEXT[status] ?? "Error"}\r\n` +
      "Connection: close\r\n" +
      "Content-Type: application/json\r\n" +
      `Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`,
  );
  socket.destroy();
}

/** Comprueba la cabecera del paquete; no mira las muestras. */
export function isValidPacket(packet: Buffer): boolean {
  if (packet.length <= LIVE_HEADER_BYTES || packet.length > MAX_PACKET_BYTES) {
    return false;
  }

  const channels = packet[2];
  const sampleRate = packet.readUInt32LE(4);

  return (
    packet[0] === LIVE_PROTOCOL_VERSION &&
    packet[1] === 0 &&
    (channels === 1 || channels === 2) &&
    sampleRate >= 8_000 &&
    sampleRate <= 96_000 &&
    (packet.length - LIVE_HEADER_BYTES) % (2 * channels) === 0
  );
}

export class LiveAudioRelay {
  private readonly rooms = new Map<string, RoomLive>();
  private readonly alive = new WeakMap<WebSocket, boolean>();
  private readonly server = new WebSocketServer({ noServer: true, maxPayload: MAX_PACKET_BYTES });
  private readonly heartbeat: NodeJS.Timeout;

  constructor(private readonly hooks: LiveRelayHooks) {
    // Un proxy inverso cierra las conexiones inactivas: el ping las mantiene
    // abiertas y descarta las que ya no responden.
    this.heartbeat = setInterval(() => this.checkConnections(), HEARTBEAT_INTERVAL_MS);
    this.heartbeat.unref();
  }

  /** Atiende las peticiones `Upgrade` de `/rooms/:roomId/live` del servidor HTTP. */
  attach(server: Server): void {
    server.on("upgrade", (req: IncomingMessage, socket: Duplex, head: Buffer) => {
      const roomId = roomIdFrom(req.url);

      if (roomId === null) {
        socket.destroy();
        return;
      }

      let decision: UpgradeDecision;

      try {
        decision = this.hooks.authorizeUpgrade(req, roomId);
      } catch (error) {
        log.error("live.upgrade_failed", {
          message: error instanceof Error ? error.message : String(error),
        });
        decision = { ok: false, status: 500, message: "Error interno del servidor" };
      }

      if (!decision.ok) {
        rejectUpgrade(socket, decision.status, decision.message);
        return;
      }

      this.server.handleUpgrade(req, socket, head, (ws) => this.accept(ws, roomId));
    });
  }

  /** Estado público de la transmisión de una sala. */
  info(roomId: string): LiveInfo {
    const room = this.rooms.get(roomId);

    return { ...(room?.state ?? INACTIVE), receivers: room?.receivers.size ?? 0 };
  }

  /** Hay un emisor o receptores conectados: la sala no debe caducar. */
  hasConnections(roomId: string): boolean {
    const room = this.rooms.get(roomId);

    return room !== undefined && (room.emitter !== null || room.receivers.size > 0);
  }

  /** Cierra la conexión de audio de un receptor que salió o fue expulsado. */
  dropReceiver(roomId: string, receiverId: string, code: number = LIVE_CLOSE.removed): void {
    const room = this.rooms.get(roomId);
    const client = room?.receivers.get(receiverId);

    if (room && client) {
      room.receivers.delete(receiverId);
      client.close(code, "Fuera de la sala");
      this.prune(roomId, room);
    }
  }

  /** La sala se borró: se cierra todo y se olvida su estado. */
  closeRoom(roomId: string): void {
    const room = this.rooms.get(roomId);

    if (!room) {
      return;
    }

    this.rooms.delete(roomId);
    room.emitter?.close(LIVE_CLOSE.roomClosed, "Sala cerrada");

    for (const client of room.receivers.values()) {
      client.close(LIVE_CLOSE.roomClosed, "Sala cerrada");
    }
  }

  close(): void {
    clearInterval(this.heartbeat);

    for (const client of this.server.clients) {
      client.terminate();
    }

    this.server.close();
    this.rooms.clear();
  }

  private checkConnections(): void {
    for (const client of this.server.clients) {
      if (this.alive.get(client) === false) {
        client.terminate();
        continue;
      }

      this.alive.set(client, false);
      client.ping(noop);
    }
  }

  private roomFor(roomId: string): RoomLive {
    let room = this.rooms.get(roomId);

    if (!room) {
      room = {
        emitter: null,
        receivers: new Map(),
        state: { ...INACTIVE },
        windowStart: 0,
        windowPackets: 0,
      };
      this.rooms.set(roomId, room);
    }

    return room;
  }

  private prune(roomId: string, room: RoomLive): void {
    if (room.emitter === null && room.receivers.size === 0 && !room.state.active) {
      this.rooms.delete(roomId);
    }
  }

  private accept(ws: WebSocket, roomId: string): void {
    let session: Session | null = null;
    const helloTimer = setTimeout(
      () => ws.close(LIVE_CLOSE.badHello, "Falta el mensaje hello"),
      HELLO_TIMEOUT_MS,
    );

    this.alive.set(ws, true);
    ws.on("pong", () => this.alive.set(ws, true));

    ws.on("message", (raw: RawData, isBinary: boolean) => {
      try {
        if (session === null) {
          session = this.hello(ws, roomId, raw, isBinary);

          if (session !== null) {
            clearTimeout(helloTimer);
          }

          return;
        }

        if (session.role === "emitter") {
          this.fromEmitter(ws, roomId, raw, isBinary);
        }
        // Los receptores no envían nada después del hello: se ignora.
      } catch (error) {
        log.warn("live.message_failed", {
          roomId,
          message: error instanceof Error ? error.message : String(error),
        });
        ws.close(1011, "Error interno");
      }
    });

    ws.on("close", () => {
      clearTimeout(helloTimer);

      if (session !== null) {
        this.detach(ws, roomId, session);
      }
    });

    ws.on("error", (error: Error) => {
      log.warn("live.socket_error", { roomId, message: error.message });
    });
  }

  private hello(ws: WebSocket, roomId: string, raw: RawData, isBinary: boolean): Session | null {
    const reject = (code: number, reason: string): null => {
      ws.close(code, reason);

      return null;
    };

    if (isBinary) {
      return reject(LIVE_CLOSE.badHello, "Se esperaba un mensaje hello");
    }

    const text = toBuffer(raw);

    if (text.length > MAX_CONTROL_BYTES) {
      return reject(LIVE_CLOSE.badHello, "Mensaje demasiado grande");
    }

    let message: unknown;

    try {
      message = JSON.parse(text.toString("utf8"));
    } catch {
      return reject(LIVE_CLOSE.badHello, "JSON no válido");
    }

    if (!isRecord(message) || message.type !== "hello") {
      return reject(LIVE_CLOSE.badHello, "Se esperaba un mensaje hello");
    }

    if (message.role === "emitter") {
      const key = typeof message.key === "string" ? message.key : undefined;

      if (!this.hooks.isEmitterAuthorized(roomId, key)) {
        return reject(LIVE_CLOSE.unauthorized, "La llave de emisor no es válida");
      }

      const room = this.roomFor(roomId);
      const previous = room.emitter;

      room.emitter = ws;
      previous?.close(LIVE_CLOSE.replaced, "Otro dispositivo tomó el control");

      // El emisor nuevo aún no transmite: los receptores dejan de ver «en vivo».
      if (room.state.active) {
        this.setState(room, { ...INACTIVE });
      }

      this.send(ws, { type: "ready", role: "emitter" });

      return { role: "emitter" };
    }

    if (message.role === "receiver") {
      const receiverId = typeof message.receiverId === "string" ? message.receiverId : "";

      if (!this.hooks.hasReceiver(roomId, receiverId)) {
        return reject(LIVE_CLOSE.notFound, "Receptor no encontrado");
      }

      const room = this.roomFor(roomId);
      const previous = room.receivers.get(receiverId);

      if (!previous && room.receivers.size >= MAX_RECEIVERS_PER_ROOM) {
        return reject(LIVE_CLOSE.roomFull, "La sala alcanzó el máximo de receptores");
      }

      room.receivers.set(receiverId, ws);
      previous?.close(LIVE_CLOSE.replaced, "Este receptor se conectó desde otro lugar");
      this.send(ws, { type: "ready", role: "receiver" });
      this.send(ws, { type: "live.state", ...room.state });

      return { role: "receiver", receiverId };
    }

    return reject(LIVE_CLOSE.badHello, "Rol desconocido");
  }

  private fromEmitter(ws: WebSocket, roomId: string, raw: RawData, isBinary: boolean): void {
    const room = this.rooms.get(roomId);

    if (!room || room.emitter !== ws) {
      return;
    }

    if (!isBinary) {
      this.controlFromEmitter(ws, room, raw);

      return;
    }

    if (!room.state.active) {
      return;
    }

    const packet = toBuffer(raw);

    if (!isValidPacket(packet)) {
      return;
    }

    const now = Date.now();

    if (now - room.windowStart >= 1_000) {
      room.windowStart = now;
      room.windowPackets = 0;
    }

    room.windowPackets += 1;

    if (room.windowPackets > MAX_PACKETS_PER_SECOND) {
      return;
    }

    this.hooks.onActivity?.(roomId);

    for (const client of room.receivers.values()) {
      // Un receptor lento no debe frenar a los demás ni llenar la memoria:
      // se le descartan paquetes (en vivo no sirve entregar audio atrasado).
      if (client.readyState === WebSocket.OPEN && client.bufferedAmount <= MAX_BUFFERED_BYTES) {
        client.send(packet, { binary: true }, noop);
      }
    }
  }

  private controlFromEmitter(ws: WebSocket, room: RoomLive, raw: RawData): void {
    const text = toBuffer(raw);

    if (text.length > MAX_CONTROL_BYTES) {
      return;
    }

    let message: unknown;

    try {
      message = JSON.parse(text.toString("utf8"));
    } catch {
      return;
    }

    if (!isRecord(message)) {
      return;
    }

    if (message.type === "live.start") {
      const source = message.source;

      if (typeof source !== "string" || !LIVE_SOURCES.includes(source)) {
        ws.close(LIVE_CLOSE.badHello, "Origen de audio desconocido");

        return;
      }

      this.setState(room, {
        active: true,
        source: source as LiveSource,
        label: sanitizeLabel(message.label),
        startedAt: new Date().toISOString(),
      });

      return;
    }

    if (message.type === "live.stop" && room.state.active) {
      this.setState(room, { ...INACTIVE });
    }
  }

  private setState(room: RoomLive, state: LiveState): void {
    room.state = state;

    for (const client of room.receivers.values()) {
      this.send(client, { type: "live.state", ...state });
    }
  }

  private detach(ws: WebSocket, roomId: string, session: Session): void {
    const room = this.rooms.get(roomId);

    if (!room) {
      return;
    }

    if (session.role === "emitter") {
      if (room.emitter === ws) {
        room.emitter = null;

        if (room.state.active) {
          this.setState(room, { ...INACTIVE });
        }
      }
    } else if (room.receivers.get(session.receiverId) === ws) {
      room.receivers.delete(session.receiverId);
    }

    this.prune(roomId, room);
  }

  private send(ws: WebSocket, message: unknown): void {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(message), noop);
    }
  }
}

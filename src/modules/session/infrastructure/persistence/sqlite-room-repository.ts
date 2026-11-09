import Database from "better-sqlite3";
import { createHash, randomBytes, randomInt, timingSafeEqual } from "node:crypto";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import type {
  Participant,
  PlaybackState,
  PlaybackStatus,
  Room,
  Role,
} from "../../domain/models.js";
import {
  PARTICIPANT_REMOVED,
  PARTICIPANT_ROLE_CONFLICT,
} from "../../domain/models.js";
import type {
  EmitterKeyCheck,
  RoomRepository,
} from "../../application/room-repository.js";

/** Intentos de generar un código de sala libre antes de rendirse. */
const ROOM_CODE_ATTEMPTS = 20;

/** Código de sala de 6 dígitos (con ceros a la izquierda): fácil de dictar y teclear. */
function generateRoomCode(): string {
  return String(randomInt(0, 1_000_000)).padStart(6, "0");
}

function hashKey(key: string): Buffer {
  return createHash("sha256").update(key).digest();
}

interface RoomRow {
  id: string;
  created_at: string;
  status: PlaybackStatus;
  playback_state: string;
  start_at: number | null;
  track_name: string | null;
  track_version: number;
}

interface ParticipantRow {
  id: string;
  role: Role;
  joined_at: string;
}

export class SQLiteRoomRepository implements RoomRepository {
  private readonly database: Database.Database;

  constructor(databaseFile: string) {
    mkdirSync(dirname(databaseFile), { recursive: true });
    this.database = new Database(databaseFile);
    this.database.pragma("foreign_keys = ON");
    this.database.exec(`
      CREATE TABLE IF NOT EXISTS rooms (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('stopped', 'playing', 'paused')),
        playback_state TEXT NOT NULL,
        start_at INTEGER,
        last_activity_at TEXT,
        emitter_key_hash TEXT,
        track_name TEXT,
        track_version INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS participants (
        id TEXT NOT NULL,
        room_id TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('emitter', 'receiver')),
        joined_at TEXT NOT NULL,
        PRIMARY KEY (room_id, id),
        FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS removed_participants (
        room_id TEXT NOT NULL,
        id TEXT NOT NULL,
        removed_at TEXT NOT NULL,
        PRIMARY KEY (room_id, id),
        FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS health_probe (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        checked_at TEXT NOT NULL
      );
    `);

    // Migración: las bases creadas antes de la caducidad no tienen la columna.
    const columns = this.database
      .prepare("PRAGMA table_info(rooms)")
      .all() as Array<{ name: string }>;

    const migrations: Array<[string, string]> = [
      ["last_activity_at", "ALTER TABLE rooms ADD COLUMN last_activity_at TEXT"],
      ["emitter_key_hash", "ALTER TABLE rooms ADD COLUMN emitter_key_hash TEXT"],
      ["track_name", "ALTER TABLE rooms ADD COLUMN track_name TEXT"],
      [
        "track_version",
        "ALTER TABLE rooms ADD COLUMN track_version INTEGER NOT NULL DEFAULT 0",
      ],
    ];

    for (const [column, statement] of migrations) {
      if (!columns.some((existing) => existing.name === column)) {
        this.database.exec(statement);
      }
    }

    this.database.exec(
      "UPDATE rooms SET last_activity_at = created_at WHERE last_activity_at IS NULL",
    );
  }

  createRoom(emitterId: string): { room: Room; emitterKey: string } {
    let id: string | undefined;

    for (let attempt = 0; attempt < ROOM_CODE_ATTEMPTS; attempt += 1) {
      const candidate = generateRoomCode();
      const taken = this.database
        .prepare("SELECT 1 FROM rooms WHERE id = ?")
        .get(candidate);

      if (!taken) {
        id = candidate;
        break;
      }
    }

    if (id === undefined) {
      throw new Error("No se pudo generar un código de sala único");
    }

    const room: Room = {
      id,
      createdAt: new Date().toISOString(),
      status: "stopped",
      playbackState: { playing: false, positionMs: 0 },
      startAt: null,
      participants: [],
      trackName: null,
      trackVersion: 0,
    };
    // La llave de emisor se devuelve una sola vez; en la base solo queda el hash.
    const emitterKey = randomBytes(24).toString("base64url");
    const participant: Participant = {
      id: emitterId,
      role: "emitter",
      joinedAt: new Date().toISOString(),
    };

    const transaction = this.database.transaction(() => {
      this.database
        .prepare(
          "INSERT INTO rooms (id, created_at, status, playback_state, start_at, last_activity_at, emitter_key_hash) VALUES (?, ?, ?, ?, ?, ?, ?)",
        )
        .run(
          room.id,
          room.createdAt,
          room.status,
          JSON.stringify(room.playbackState),
          room.startAt,
          room.createdAt,
          hashKey(emitterKey).toString("hex"),
        );
      this.insertParticipant(room.id, participant);
    });

    transaction();
    return { room: this.getRoom(room.id) as Room, emitterKey };
  }

  checkEmitterKey(roomId: string, key: string | undefined): EmitterKeyCheck {
    const row = this.database
      .prepare("SELECT emitter_key_hash FROM rooms WHERE id = ?")
      .get(roomId) as { emitter_key_hash: string | null } | undefined;

    if (!row || row.emitter_key_hash === null) {
      return row ? "legacy" : "invalid";
    }

    if (key === undefined || key === "") {
      return "missing";
    }

    const expected = Buffer.from(row.emitter_key_hash, "hex");

    return timingSafeEqual(expected, hashKey(key)) ? "valid" : "invalid";
  }

  removeParticipant(roomId: string, participantId: string, ban: boolean): boolean {
    const transaction = this.database.transaction(() => {
      const result = this.database
        .prepare(
          "DELETE FROM participants WHERE room_id = ? AND id = ? AND role = 'receiver'",
        )
        .run(roomId, participantId);

      if (result.changes === 0) {
        return false;
      }

      if (ban) {
        this.database
          .prepare(
            "INSERT OR IGNORE INTO removed_participants (room_id, id, removed_at) VALUES (?, ?, ?)",
          )
          .run(roomId, participantId, new Date().toISOString());
      }

      return true;
    });

    return transaction();
  }

  replaceTrack(roomId: string, trackName: string | null): Room {
    const result = this.database
      .prepare(
        "UPDATE rooms SET track_name = ?, track_version = track_version + 1, status = 'stopped', playback_state = ?, start_at = NULL WHERE id = ?",
      )
      .run(trackName, JSON.stringify({ playing: false, positionMs: 0 }), roomId);

    if (result.changes === 0) {
      throw new Error("Sala no encontrada");
    }

    return this.getRoom(roomId) as Room;
  }

  listRooms(): Room[] {
    const roomIds = this.database
      .prepare("SELECT id FROM rooms ORDER BY created_at ASC, id ASC")
      .all() as Array<{ id: string }>;

    return roomIds.map((row) => this.getRoom(row.id)).filter(Boolean) as Room[];
  }

  findRoom(roomId: string): Room | undefined {
    return this.getRoom(roomId);
  }

  getRoom(roomId: string): Room | undefined {
    const room = this.database
      .prepare("SELECT * FROM rooms WHERE id = ?")
      .get(roomId) as RoomRow | undefined;

    if (!room) {
      return undefined;
    }

    const participants = this.database
      .prepare(
        "SELECT id, role, joined_at FROM participants WHERE room_id = ? ORDER BY joined_at, id",
      )
      .all(roomId) as ParticipantRow[];

    return {
      id: room.id,
      createdAt: room.created_at,
      status: room.status,
      playbackState: JSON.parse(room.playback_state) as PlaybackState,
      startAt: room.start_at,
      trackName: room.track_name,
      trackVersion: room.track_version,
      participants: participants.map((participant) => ({
        id: participant.id,
        role: participant.role,
        joinedAt: participant.joined_at,
      })),
    };
  }

  addParticipant(roomId: string, participant: Participant): Participant {
    const room = this.getRoom(roomId);

    if (!room) {
      throw new Error("Sala no encontrada");
    }

    const banned = this.database
      .prepare("SELECT 1 FROM removed_participants WHERE room_id = ? AND id = ?")
      .get(roomId, participant.id);

    if (banned) {
      throw new Error(PARTICIPANT_REMOVED);
    }

    // Unirse es idempotente: el mismo identificador con el mismo rol vuelve a
    // entrar (p. ej. tras cerrar la app) en vez de fallar contra la clave primaria.
    const existing = room.participants.find((item) => item.id === participant.id);

    if (existing) {
      if (existing.role !== participant.role) {
        throw new Error(PARTICIPANT_ROLE_CONFLICT);
      }

      return existing;
    }

    this.insertParticipant(roomId, participant);
    return participant;
  }

  updatePlaybackState(
    roomId: string,
    status: PlaybackStatus,
    playbackState: PlaybackState,
    startAt: number | null,
  ): Room {
    const result = this.database
      .prepare(
        "UPDATE rooms SET status = ?, playback_state = ?, start_at = ? WHERE id = ?",
      )
      .run(status, JSON.stringify(playbackState), startAt, roomId);

    if (result.changes === 0) {
      throw new Error("Sala no encontrada");
    }

    return this.getRoom(roomId) as Room;
  }

  touchRoom(roomId: string, at: string): void {
    this.database
      .prepare("UPDATE rooms SET last_activity_at = ? WHERE id = ?")
      .run(at, roomId);
  }

  listInactiveRoomIds(beforeIso: string): string[] {
    const rows = this.database
      .prepare(
        "SELECT id FROM rooms WHERE COALESCE(last_activity_at, created_at) < ? ORDER BY id",
      )
      .all(beforeIso) as Array<{ id: string }>;

    return rows.map((row) => row.id);
  }

  deleteRoom(roomId: string): boolean {
    return this.database.prepare("DELETE FROM rooms WHERE id = ?").run(roomId).changes > 0;
  }

  checkWritable(): boolean {
    try {
      this.database
        .prepare(
          "INSERT INTO health_probe (id, checked_at) VALUES (1, ?) ON CONFLICT(id) DO UPDATE SET checked_at = excluded.checked_at",
        )
        .run(new Date().toISOString());
      return true;
    } catch {
      return false;
    }
  }

  close(): void {
    this.database.close();
  }

  private insertParticipant(roomId: string, participant: Participant): void {
    this.database
      .prepare(
        "INSERT INTO participants (id, room_id, role, joined_at) VALUES (?, ?, ?, ?)",
      )
      .run(participant.id, roomId, participant.role, participant.joinedAt);
  }
}
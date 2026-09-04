import Database from "better-sqlite3";
import { randomUUID } from "node:crypto";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import type {
  Participant,
  PlaybackState,
  PlaybackStatus,
  Room,
  Role,
} from "../../domain/models.js";
import type { RoomRepository } from "../../application/room-repository.js";

interface RoomRow {
  id: string;
  created_at: string;
  status: PlaybackStatus;
  playback_state: string;
  start_at: number | null;
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
        start_at INTEGER
      );

      CREATE TABLE IF NOT EXISTS participants (
        id TEXT NOT NULL,
        room_id TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('emitter', 'receiver')),
        joined_at TEXT NOT NULL,
        PRIMARY KEY (room_id, id),
        FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
      );
    `);
  }

  createRoom(emitterId: string): Room {
    const room: Room = {
      id: randomUUID(),
      createdAt: new Date().toISOString(),
      status: "stopped",
      playbackState: { playing: false, positionMs: 0 },
      startAt: null,
      participants: [],
    };
    const participant: Participant = {
      id: emitterId,
      role: "emitter",
      joinedAt: new Date().toISOString(),
    };

    const transaction = this.database.transaction(() => {
      this.database
        .prepare(
          "INSERT INTO rooms (id, created_at, status, playback_state, start_at) VALUES (?, ?, ?, ?, ?)",
        )
        .run(
          room.id,
          room.createdAt,
          room.status,
          JSON.stringify(room.playbackState),
          room.startAt,
        );
      this.insertParticipant(room.id, participant);
    });

    transaction();
    return this.getRoom(room.id) as Room;
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
      participants: participants.map((participant) => ({
        id: participant.id,
        role: participant.role,
        joinedAt: participant.joined_at,
      })),
    };
  }

  addParticipant(roomId: string, participant: Participant): Participant {
    if (!this.getRoom(roomId)) {
      throw new Error("Sala no encontrada");
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
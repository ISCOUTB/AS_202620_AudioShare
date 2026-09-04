import type { Participant, Room } from "../domain/models.js";
import type { RoomRepository } from "./room-repository.js";

export class SessionApplication {
  constructor(private readonly rooms: RoomRepository) {}

  createRoom(emitterId: string): Room {
    return this.rooms.createRoom(emitterId);
  }

  getRoom(roomId: string): Room | undefined {
    return this.rooms.getRoom(roomId);
  }

  addReceiver(roomId: string, receiverId: string): Participant {
    const room = this.rooms.findRoom(roomId);

    if (!room) {
      throw new Error("Sala no encontrada");
    }

    return this.rooms.addParticipant(roomId, {
      id: receiverId,
      role: "receiver",
      joinedAt: new Date().toISOString(),
    });
  }

  startPlayback(roomId: string, startAt: number): Room {
    const room = this.requireRoomWithEmitter(roomId);

    return this.rooms.updatePlaybackState(
      room.id,
      "playing",
      { playing: true, positionMs: 0 },
      startAt,
    );
  }

  pausePlayback(roomId: string, positionMs: number): Room {
    const room = this.requireRoomWithEmitter(roomId);

    return this.rooms.updatePlaybackState(
      room.id,
      "paused",
      { playing: false, positionMs },
      room.startAt,
    );
  }

  close(): void {
    this.rooms.close();
  }

  private requireRoomWithEmitter(roomId: string): Room {
    const room = this.rooms.findRoom(roomId);

    if (!room) {
      throw new Error("Sala no encontrada");
    }

    if (!room.participants.some((participant) => participant.role === "emitter")) {
      throw new Error("La sala no tiene emisor");
    }

    return room;
  }
}
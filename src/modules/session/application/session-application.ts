import type { Participant, Room } from "../domain/models.js";
import type { EmitterKeyCheck, RoomRepository } from "./room-repository.js";

export class SessionApplication {
  constructor(private readonly rooms: RoomRepository) {}

  createRoom(emitterId: string): { room: Room; emitterKey: string } {
    return this.rooms.createRoom(emitterId);
  }

  checkEmitterKey(roomId: string, key: string | undefined): EmitterKeyCheck {
    return this.rooms.checkEmitterKey(roomId, key);
  }

  removeParticipant(roomId: string, participantId: string, ban: boolean): boolean {
    return this.rooms.removeParticipant(roomId, participantId, ban);
  }

  replaceTrack(roomId: string, trackName: string | null): Room {
    return this.rooms.replaceTrack(roomId, trackName);
  }

  listRooms(): Room[] {
    return this.rooms.listRooms();
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

  startPlayback(roomId: string, startAt: number, positionMs = 0): Room {
    const room = this.requireRoomWithEmitter(roomId);

    return this.rooms.updatePlaybackState(
      room.id,
      "playing",
      { playing: true, positionMs },
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

  touchRoom(roomId: string, at: string): void {
    this.rooms.touchRoom(roomId, at);
  }

  inactiveRoomIds(beforeIso: string): string[] {
    return this.rooms.listInactiveRoomIds(beforeIso);
  }

  deleteRoom(roomId: string): boolean {
    return this.rooms.deleteRoom(roomId);
  }

  storageWritable(): boolean {
    return this.rooms.checkWritable();
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
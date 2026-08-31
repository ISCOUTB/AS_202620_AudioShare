export type Role = "emitter" | "receiver";

export interface Participant {
  id: string;
  role: Role;
}

export interface Room {
  id: string;
  participants: Map<string, Participant>;
}

export class SessionManager {
  private rooms = new Map<string, Room>();

  createRoom(emitterId: string): Room {
    const room: Room = {
      id: crypto.randomUUID(),
      participants: new Map(),
    };

    room.participants.set(emitterId, {
      id: emitterId,
      role: "emitter",
    });

    this.rooms.set(room.id, room);

    return room;
  }

  getRoom(roomId: string): Room | undefined {
    return this.rooms.get(roomId);
  }

  addReceiver(roomId: string, receiverId: string): Participant {
    const room = this.rooms.get(roomId);

    if (!room) {
      throw new Error("Sala no encontrada");
    }

    const receiver: Participant = {
      id: receiverId,
      role: "receiver",
    };

    room.participants.set(receiverId, receiver);

    return receiver;
  }

  getReceivers(roomId: string): Participant[] {
    const room = this.rooms.get(roomId);

    if (!room) {
      throw new Error("Sala no encontrada");
    }

    return Array.from(room.participants.values()).filter(
      (participant) => participant.role === "receiver",
    );
  }
}
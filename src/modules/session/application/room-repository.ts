import type {
  Participant,
  PlaybackState,
  PlaybackStatus,
  Room,
} from "../domain/models.js";

export interface RoomRepository {
  createRoom(emitterId: string): Room;
  listRooms(): Room[];
  findRoom(roomId: string): Room | undefined;
  getRoom(roomId: string): Room | undefined;
  addParticipant(roomId: string, participant: Participant): Participant;
  updatePlaybackState(
    roomId: string,
    status: PlaybackStatus,
    playbackState: PlaybackState,
    startAt: number | null,
  ): Room;
  /** Marca actividad en la sala (base de la caducidad por inactividad). */
  touchRoom(roomId: string, at: string): void;
  /** Identificadores de salas sin actividad desde antes de `beforeIso`. */
  listInactiveRoomIds(beforeIso: string): string[];
  /** Borra la sala y sus participantes. Devuelve si existía. */
  deleteRoom(roomId: string): boolean;
  /** Comprueba que se puede escribir en el almacenamiento. */
  checkWritable(): boolean;
  close(): void;
}
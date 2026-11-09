import type {
  Participant,
  PlaybackState,
  PlaybackStatus,
  Room,
} from "../domain/models.js";

/**
 * Resultado de comprobar la llave de emisor de una sala:
 * - `valid`: la llave corresponde.
 * - `legacy`: la sala es anterior a las llaves y no tiene una.
 * - `missing`: la sala tiene llave y no se envió ninguna.
 * - `invalid`: se envió una llave que no corresponde.
 */
export type EmitterKeyCheck = "valid" | "legacy" | "missing" | "invalid";

export interface RoomRepository {
  /**
   * Crea la sala y devuelve, solo en este momento, la llave de emisor en
   * claro; en SQLite se guarda únicamente su hash SHA-256.
   */
  createRoom(emitterId: string): { room: Room; emitterKey: string };
  checkEmitterKey(roomId: string, key: string | undefined): EmitterKeyCheck;
  /**
   * Quita a un receptor. Con `ban` el nombre queda vetado en esa sala.
   * Devuelve si había un receptor con ese identificador.
   */
  removeParticipant(roomId: string, participantId: string, ban: boolean): boolean;
  /** Registra una pista nueva: sube la versión y deja la sala detenida. */
  replaceTrack(roomId: string, trackName: string | null): Room;
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
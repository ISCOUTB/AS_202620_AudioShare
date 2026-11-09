/** Mensaje del error al reutilizar un identificador con otro rol en la misma sala. */
export const PARTICIPANT_ROLE_CONFLICT = "Identificador en uso por otro rol";
/** Mensaje del error al volver a entrar con un nombre que el emisor expulsó. */
export const PARTICIPANT_REMOVED = "Participante expulsado de la sala";

export type Role = "emitter" | "receiver";
export type PlaybackStatus = "stopped" | "playing" | "paused";

export interface Participant {
  id: string;
  role: Role;
  joinedAt: string;
}

export interface PlaybackState {
  playing: boolean;
  positionMs: number;
}

export interface Room {
  id: string;
  createdAt: string;
  status: PlaybackStatus;
  playbackState: PlaybackState;
  startAt: number | null;
  participants: Participant[];
  /** Nombre de la canción actual (el que envió el emisor), si lo hay. */
  trackName: string | null;
  /** Cuántas veces se ha subido o cambiado la pista; 0 = sin pista. */
  trackVersion: number;
}
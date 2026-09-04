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
}
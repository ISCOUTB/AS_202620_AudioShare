import type {
  Participant,
  PlaybackState,
  PlaybackStatus,
  Room,
} from "../domain/models.js";

export interface RoomRepository {
  createRoom(emitterId: string): Room;
  findRoom(roomId: string): Room | undefined;
  getRoom(roomId: string): Room | undefined;
  addParticipant(roomId: string, participant: Participant): Participant;
  updatePlaybackState(
    roomId: string,
    status: PlaybackStatus,
    playbackState: PlaybackState,
    startAt: number | null,
  ): Room;
  close(): void;
}
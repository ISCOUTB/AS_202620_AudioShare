export interface AudioChunk {
  type: "audio.chunk";
  sequence: number;
  payload: string;
}

export class AudioStreamHub {
  private sequence = 0;

  createChunk(payload: string): AudioChunk {
    this.sequence += 1;

    return {
      type: "audio.chunk",
      sequence: this.sequence,
      payload,
    };
  }
}
import { mkdirSync } from "node:fs";
import { writeFile } from "node:fs/promises";
import { join } from "node:path";

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

export class AudioTrackStore {
  constructor(private readonly directory: string) {
    mkdirSync(directory, { recursive: true });
  }

  pathFor(roomId: string): string {
    if (!/^[a-f0-9-]+$/i.test(roomId)) {
      throw new Error("Identificador de sala inválido");
    }

    return join(this.directory, `${roomId}.mp3`);
  }

  save(roomId: string, track: Buffer): Promise<void> {
    return writeFile(this.pathFor(roomId), track);
  }
}

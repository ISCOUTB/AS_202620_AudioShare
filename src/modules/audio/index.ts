import { randomUUID } from "node:crypto";
import { mkdirSync } from "node:fs";
import { rename, unlink, writeFile } from "node:fs/promises";
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

  /**
   * Guarda la pista de forma atómica (ADR-0011): escribe un archivo temporal
   * en el mismo directorio y lo renombra sobre el definitivo. Un lector
   * concurrente o un fallo a mitad de escritura nunca ve una pista parcial:
   * o queda la pista anterior o queda la nueva completa.
   */
  async save(roomId: string, track: Buffer): Promise<void> {
    const destination = this.pathFor(roomId);
    const temporary = `${destination}.${randomUUID()}.tmp`;

    try {
      await writeFile(temporary, track);
      await rename(temporary, destination);
    } catch (error) {
      await unlink(temporary).catch(() => undefined);
      throw error;
    }
  }
}

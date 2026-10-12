import {
  delayUntilStart,
  estimateBestOffset,
  type ClockSample,
} from "../../src/modules/sync/index.js";

/**
 * Receptor simulado: ejecuta el MISMO algoritmo que debe ejecutar un
 * cliente real (calibrar reloj → recibir sync.start → esperar hasta
 * startAt → reportar ACK), pero con un reloj local desfasado a propósito
 * (`skewMs`) para reproducir dispositivos con relojes mal sincronizados.
 *
 * `correctClock: false` reproduce el defecto que ADR-0005 descartó
 * ("usar la hora local de cada receptor"): ignora el offset.
 */
export interface SimulatedReceiverOptions {
  baseUrl: string;
  roomId: string;
  receiverId: string;
  skewMs: number;
  correctClock?: boolean;
  calibrationSamples?: number;
}

export class SimulatedReceiver {
  private offsetMs = 0;
  private readonly correctClock: boolean;
  private readonly abort = new AbortController();
  private started: Promise<number> | undefined;

  constructor(private readonly options: SimulatedReceiverOptions) {
    this.correctClock = options.correctClock ?? true;
  }

  /** Reloj local del dispositivo simulado (desfasado respecto del servidor). */
  localNow(): number {
    return Date.now() + this.options.skewMs;
  }

  get estimatedOffsetMs(): number {
    return this.offsetMs;
  }

  /** Toma muestras de GET /time y estima el offset de reloj. */
  async calibrate(): Promise<void> {
    if (!this.correctClock) {
      this.offsetMs = 0;
      return;
    }

    const samples: ClockSample[] = [];

    for (let i = 0; i < (this.options.calibrationSamples ?? 5); i += 1) {
      const t0 = this.localNow();
      const response = await fetch(`${this.options.baseUrl}/time`);
      const { serverTime } = (await response.json()) as { serverTime: number };
      const t1 = this.localNow();

      samples.push({ t0, serverTime, t1 });
    }

    this.offsetMs = estimateBestOffset(samples);
  }

  /** Se une a la sala y abre el stream NDJSON. Resuelve cuando ya está registrado. */
  async join(): Promise<void> {
    const { baseUrl, roomId, receiverId } = this.options;

    await fetch(`${baseUrl}/rooms/${roomId}/receivers`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ receiverId }),
    });

    const response = await fetch(
      `${baseUrl}/rooms/${roomId}/stream/${receiverId}`,
      { signal: this.abort.signal },
    );

    this.started = new Promise<number>((resolve, reject) => {
      this.consume(response, resolve).catch((error: unknown) => {
        if (!this.abort.signal.aborted) {
          reject(error);
        }
      });
    });
  }

  /** Resuelve con el instante LOCAL en que el receptor "empezó a reproducir". */
  startedAtLocal(): Promise<number> {
    if (!this.started) {
      throw new Error("El receptor no se ha unido a la sala");
    }

    return this.started;
  }

  close(): void {
    this.abort.abort();
  }

  private async consume(
    response: Response,
    onStarted: (startedAtLocal: number) => void,
  ): Promise<void> {
    const reader = response.body?.getReader();

    if (!reader) {
      throw new Error("El stream no tiene cuerpo");
    }

    const decoder = new TextDecoder();
    let buffer = "";

    for (;;) {
      const { value, done } = await reader.read();

      if (done) {
        return;
      }

      buffer += decoder.decode(value, { stream: true });

      let newline = buffer.indexOf("\n");

      while (newline >= 0) {
        const line = buffer.slice(0, newline).trim();
        buffer = buffer.slice(newline + 1);
        newline = buffer.indexOf("\n");

        if (line) {
          this.handle(JSON.parse(line) as { type: string; startAt?: number }, onStarted);
        }
      }
    }
  }

  private handle(
    event: { type: string; startAt?: number },
    onStarted: (startedAtLocal: number) => void,
  ): void {
    if (event.type !== "sync.start" || event.startAt === undefined) {
      return;
    }

    const wait = this.correctClock
      ? delayUntilStart(event.startAt, this.localNow(), this.offsetMs)
      : Math.max(0, event.startAt - this.localNow());

    setTimeout(() => {
      const startedAt = this.localNow();

      void this.sendAck(startedAt).then(() => onStarted(startedAt));
    }, wait);
  }

  private async sendAck(startedAt: number): Promise<void> {
    const { baseUrl, roomId, receiverId } = this.options;

    await fetch(`${baseUrl}/rooms/${roomId}/receivers/${receiverId}/ack`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ startedAt, offsetMs: this.offsetMs }),
    });
  }
}

/**
 * Contexto Sync — dueño de la referencia temporal común (`startAt`) y de la
 * medición del desfase de arranque entre receptores (A-01 / EC-01).
 *
 * Modelo de tiempo (ver ADR-0005):
 *  - `startAt` es un instante en el reloj del SERVIDOR (epoch ms).
 *  - Cada receptor tiene un reloj local que puede estar adelantado o atrasado.
 *    Antes de programar el arranque, el receptor estima su `offsetMs`
 *    (= reloj_servidor − reloj_local) con muestras de `GET /time`.
 *  - El receptor arranca cuando `reloj_local + offsetMs >= startAt`.
 *  - Tras arrancar, reporta su instante local de inicio y su `offsetMs`
 *    (`POST .../ack`); el servidor lo lleva a su propio reloj y calcula la
 *    diferencia entre el primer y el último receptor en arrancar.
 */

/** Antelación con que `startAt` se programa respecto del momento del PLAY. */
export const START_LEAD_MS = 500;

/** Umbral de EC-01: diferencia máxima de arranque entre receptores. */
export const EC01_THRESHOLD_MS = 100;

export interface SyncStartEvent {
  type: "sync.start";
  startAt: number;
}

export interface SyncPauseEvent {
  type: "sync.pause";
  positionMs: number;
}

/**
 * Muestra de reloj tomada por un receptor:
 *  t0 = reloj local al enviar la petición, serverTime = respuesta de /time,
 *  t1 = reloj local al recibir la respuesta.
 */
export interface ClockSample {
  t0: number;
  serverTime: number;
  t1: number;
}

/**
 * Offset (reloj_servidor − reloj_local) de una muestra, suponiendo que la
 * respuesta se generó en el punto medio del viaje de ida y vuelta.
 */
export function estimateOffset(sample: ClockSample): number {
  return sample.serverTime - (sample.t0 + sample.t1) / 2;
}

/**
 * Elige la muestra con menor tiempo de ida y vuelta (la menos afectada por
 * la cola de red) y devuelve su offset.
 */
export function estimateBestOffset(samples: ClockSample[]): number {
  if (samples.length === 0) {
    throw new Error("Se necesita al menos una muestra de reloj");
  }

  const best = samples.reduce((a, b) =>
    b.t1 - b.t0 < a.t1 - a.t0 ? b : a,
  );

  return estimateOffset(best);
}

/**
 * Milisegundos que el receptor debe esperar (en su reloj local) para
 * arrancar exactamente en `startAt` del servidor. Nunca negativo: si
 * `startAt` ya pasó, arranca de inmediato.
 */
export function delayUntilStart(
  startAt: number,
  localNow: number,
  offsetMs: number,
): number {
  return Math.max(0, startAt - (localNow + offsetMs));
}

/** Lleva un instante del reloj local del receptor al reloj del servidor. */
export function toServerClock(localTime: number, offsetMs: number): number {
  return localTime + offsetMs;
}

export class SyncCoordinator {
  private positionMs = 0;
  private playing = false;

  start(): SyncStartEvent {
    this.playing = true;

    return {
      type: "sync.start",
      startAt: Date.now() + START_LEAD_MS,
    };
  }

  pause(): SyncPauseEvent {
    this.playing = false;

    return {
      type: "sync.pause",
      positionMs: this.positionMs,
    };
  }

  getState() {
    return {
      playing: this.playing,
      positionMs: this.positionMs,
    };
  }
}

export interface ReceiverAck {
  receiverId: string;
  /** Instante de arranque llevado al reloj del servidor. */
  startedAtServerClock: number;
  /** Diferencia respecto de `startAt` (positivo = arrancó tarde). */
  deviationMs: number;
}

export interface SyncReport {
  roomId: string;
  startAt: number;
  acks: ReceiverAck[];
  /** max − min de los arranques; null si hay menos de 2 receptores. */
  spreadMs: number | null;
  thresholdMs: number;
  withinThreshold: boolean | null;
}

/**
 * Medición del desfase de arranque. Es propiedad exclusiva del contexto
 * Sync: Session no escribe aquí y Audio tampoco.
 */
export class SyncMeasurements {
  // clave: `${roomId}:${startAt}` → receiverId → arranque en reloj servidor
  private readonly starts = new Map<string, Map<string, number>>();

  record(
    roomId: string,
    startAt: number,
    receiverId: string,
    startedAtServerClock: number,
  ): ReceiverAck {
    const key = `${roomId}:${startAt}`;
    const room = this.starts.get(key) ?? new Map<string, number>();

    room.set(receiverId, startedAtServerClock);
    this.starts.set(key, room);

    return {
      receiverId,
      startedAtServerClock,
      deviationMs: startedAtServerClock - startAt,
    };
  }

  report(roomId: string, startAt: number): SyncReport {
    const room = this.starts.get(`${roomId}:${startAt}`) ?? new Map();
    const acks: ReceiverAck[] = Array.from(room.entries()).map(
      ([receiverId, startedAtServerClock]) => ({
        receiverId,
        startedAtServerClock,
        deviationMs: startedAtServerClock - startAt,
      }),
    );

    const times = acks.map((ack) => ack.startedAtServerClock);
    const spreadMs =
      times.length >= 2 ? Math.max(...times) - Math.min(...times) : null;

    return {
      roomId,
      startAt,
      acks,
      spreadMs,
      thresholdMs: EC01_THRESHOLD_MS,
      withinThreshold: spreadMs === null ? null : spreadMs <= EC01_THRESHOLD_MS,
    };
  }
}

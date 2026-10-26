import {
  validateReceiverSyncMessage,
  type ReceiverSyncRequestedV1,
} from "./contract.js";

export interface MessageLog {
  event: string;
  messageId: string;
  correlationId: string;
  attempt?: number;
  delayMs?: number;
  elapsedMs?: number;
  detail?: string;
}

export interface DeadLetter {
  message: ReceiverSyncRequestedV1;
  attempts: number;
  reason: string;
}

export interface QueueOptions {
  maxAttempts?: number;
  baseBackoffMs?: number;
  log?: (entry: MessageLog) => void;
  sleep?: (milliseconds: number) => Promise<void>;
}

export type MessageHandler = (
  message: ReceiverSyncRequestedV1,
) => Promise<void>;

const defaultSleep = (
  milliseconds: number,
): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, milliseconds));

/**
 * Simulador local de una cola de mensajes.
 *
 * No utiliza RabbitMQ ni un broker externo.
 * No está conectado a los módulos de producción.
 */
export class LocalMessageQueue {
  private readonly pending: ReceiverSyncRequestedV1[] = [];

  private readonly processed = new Set<string>();

  private readonly failed: DeadLetter[] = [];

  private readonly maxAttempts: number;

  private readonly baseBackoffMs: number;

  private readonly log: (entry: MessageLog) => void;

  private readonly sleep: (
    milliseconds: number,
  ) => Promise<void>;

  constructor(
    private readonly handler: MessageHandler,
    options: QueueOptions = {},
  ) {
    this.maxAttempts = options.maxAttempts ?? 3;

    this.baseBackoffMs = options.baseBackoffMs ?? 100;

    this.log = options.log ?? (() => undefined);

    this.sleep = options.sleep ?? defaultSleep;

    if (
      !Number.isInteger(this.maxAttempts) ||
      this.maxAttempts < 1
    ) {
      throw new Error(
        "maxAttempts debe ser un entero mayor que cero",
      );
    }

    if (
      !Number.isFinite(this.baseBackoffMs) ||
      this.baseBackoffMs < 0
    ) {
      throw new Error(
        "baseBackoffMs no puede ser negativo",
      );
    }
  }

  /**
   * Publica un mensaje en la cola local.
   */
  async publish(value: unknown): Promise<void> {
    validateReceiverSyncMessage(value);

    const message = value as ReceiverSyncRequestedV1;

    this.pending.push(message);

    this.log({
      event: "message.produced",
      messageId: message.messageId,
      correlationId: message.correlationId,
    });
  }

  /**
   * Procesa los mensajes pendientes secuencialmente.
   */
  async drain(): Promise<void> {
    while (this.pending.length > 0) {
      const message = this.pending.shift();

      if (message) {
        await this.consume(message);
      }
    }
  }

  /**
   * Devuelve los mensajes que agotaron sus reintentos.
   */
  get deadLetters(): readonly DeadLetter[] {
    return this.failed;
  }

  /**
   * Devuelve los identificadores de mensajes procesados.
   */
  get processedMessageIds(): readonly string[] {
    return [...this.processed];
  }

  private async consume(
    message: ReceiverSyncRequestedV1,
  ): Promise<void> {
    if (this.processed.has(message.messageId)) {
      this.log({
        event: "message.duplicate",
        messageId: message.messageId,
        correlationId: message.correlationId,
        detail: "Mensaje duplicado ignorado",
      });

      return;
    }

    const startedAt = Date.now();

    for (
      let attempt = 1;
      attempt <= this.maxAttempts;
      attempt += 1
    ) {
      this.log({
        event: "message.consumed",
        messageId: message.messageId,
        correlationId: message.correlationId,
        attempt,
      });

      try {
        await this.handler(message);

        this.processed.add(message.messageId);

        this.log({
          event: "message.acknowledged",
          messageId: message.messageId,
          correlationId: message.correlationId,
          attempt,
          elapsedMs: Date.now() - startedAt,
        });

        return;
      } catch (error: unknown) {
        const reason =
          error instanceof Error
            ? error.message
            : String(error);

        if (attempt < this.maxAttempts) {
          const delayMs =
            this.baseBackoffMs * 2 ** (attempt - 1);

          this.log({
            event: "message.retry",
            messageId: message.messageId,
            correlationId: message.correlationId,
            attempt,
            delayMs,
            detail: reason,
          });

          await this.sleep(delayMs);

          continue;
        }

        this.failed.push({
          message,
          attempts: attempt,
          reason,
        });

        this.log({
          event: "message.dead_letter",
          messageId: message.messageId,
          correlationId: message.correlationId,
          attempt,
          elapsedMs: Date.now() - startedAt,
          detail: reason,
        });
      }
    }
  }
}

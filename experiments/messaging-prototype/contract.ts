/**
 * Contrato del mensaje de sincronización de un receptor.
 *
 * Este mensaje se utiliza en el prototipo del taller.
 * No está conectado todavía al flujo de producción de AudioShare.
 */

export interface ReceiverSyncRequestedV1 {
  schemaVersion: 1;

  messageId: string;

  type: "receiver.sync.requested";

  occurredAt: string;

  correlationId: string;

  payload: {
    roomId: string;
    receiverId: string;
    targetPositionMs: number;
  };
}

/**
 * Valida que un mensaje cumpla el contrato de la versión 1.
 */
export function validateReceiverSyncMessage(
  value: unknown,
): asserts value is ReceiverSyncRequestedV1 {
  if (typeof value !== "object" || value === null) {
    throw new Error("El mensaje debe ser un objeto");
  }

  const message = value as Record<string, unknown>;

  if (message.schemaVersion !== 1) {
    throw new Error("Versión de contrato no compatible");
  }

  if (message.type !== "receiver.sync.requested") {
    throw new Error("Tipo de mensaje no compatible");
  }

  if (
    typeof message.messageId !== "string" ||
    message.messageId.length === 0
  ) {
    throw new Error("messageId es obligatorio");
  }

  if (
    typeof message.correlationId !== "string" ||
    message.correlationId.length === 0
  ) {
    throw new Error("correlationId es obligatorio");
  }

  if (
    typeof message.occurredAt !== "string" ||
    Number.isNaN(Date.parse(message.occurredAt))
  ) {
    throw new Error("occurredAt debe ser una fecha ISO válida");
  }

  const payload = message.payload;

  if (typeof payload !== "object" || payload === null) {
    throw new Error("payload es obligatorio");
  }

  const data = payload as Record<string, unknown>;

  if (
    typeof data.roomId !== "string" ||
    data.roomId.length === 0
  ) {
    throw new Error("payload.roomId es obligatorio");
  }

  if (
    typeof data.receiverId !== "string" ||
    data.receiverId.length === 0
  ) {
    throw new Error("payload.receiverId es obligatorio");
  }

  if (
    typeof data.targetPositionMs !== "number" ||
    !Number.isFinite(data.targetPositionMs) ||
    data.targetPositionMs < 0
  ) {
    throw new Error(
      "payload.targetPositionMs debe ser un número no negativo",
    );
  }
}

import { describe, expect, it, vi } from "vitest";
import { LocalMessageQueue, type MessageLog } from "../experiments/messaging-prototype/local-message-queue.js";
import type { ReceiverSyncRequestedV1 } from "../experiments/messaging-prototype/contract.js";

function sampleMessage(): ReceiverSyncRequestedV1 {
  return {
    schemaVersion: 1,
    messageId: "msg-001",
    type: "receiver.sync.requested",
    occurredAt: "2026-10-25T12:00:00.000Z",
    correlationId: "corr-room-123",
    payload: { roomId: "room-123", receiverId: "receiver-7", targetPositionMs: 1250 },
  };
}

describe("Prototipo local de mensajería", () => {
  it("ignora un duplicado y procesa una sola vez", async () => {
    const handler = vi.fn(async (_message: ReceiverSyncRequestedV1) => undefined);
    const logs: MessageLog[] = [];
    const queue = new LocalMessageQueue(handler, { log: (entry) => logs.push(entry), sleep: async () => undefined });
    const message = sampleMessage();
    await queue.publish(message);
    await queue.publish(message);
    await queue.drain();
    expect(handler).toHaveBeenCalledTimes(1);
    expect(queue.processedMessageIds).toContain("msg-001");
    expect(logs.some((entry) => entry.event === "message.duplicate")).toBe(true);
  });

  it("reintenta un fallo recuperable y después confirma", async () => {
    let calls = 0;
    const delays: number[] = [];
    const logs: MessageLog[] = [];
    const handler = vi.fn(async (_message: ReceiverSyncRequestedV1) => {
      calls += 1;
      if (calls === 1) throw new Error("Fallo temporal simulado");
    });
    const queue = new LocalMessageQueue(handler, {
      maxAttempts: 3, baseBackoffMs: 10,
      log: (entry) => logs.push(entry),
      sleep: async (milliseconds) => { delays.push(milliseconds); },
    });
    await queue.publish(sampleMessage());
    await queue.drain();
    expect(handler).toHaveBeenCalledTimes(2);
    expect(delays).toEqual([10]);
    expect(queue.deadLetters).toHaveLength(0);
    expect(queue.processedMessageIds).toContain("msg-001");
    expect(logs.some((entry) => entry.event === "message.retry")).toBe(true);
    expect(logs.some((entry) => entry.event === "message.acknowledged")).toBe(true);
  });

  it("aplica backoff exponencial y registra el recorrido productor-consumidor", async () => {
    const delays: number[] = [];
    const logs: MessageLog[] = [];
    const handler = vi.fn(async (_message: ReceiverSyncRequestedV1) => { throw new Error("Fallo persistente simulado"); });
    const queue = new LocalMessageQueue(handler, {
      maxAttempts: 3, baseBackoffMs: 10,
      log: (entry) => logs.push(entry),
      sleep: async (milliseconds) => { delays.push(milliseconds); },
    });
    await queue.publish(sampleMessage());
    await queue.drain();
    expect(handler).toHaveBeenCalledTimes(3);
    expect(delays).toEqual([10, 20]);
    expect(queue.deadLetters).toHaveLength(1);
    expect(queue.deadLetters[0]?.attempts).toBe(3);
    const events = logs.filter((entry) => entry.messageId === "msg-001");
    expect(events[0]?.event).toBe("message.produced");
    expect(events.some((entry) => entry.event === "message.consumed")).toBe(true);
    expect(events.some((entry) => entry.event === "message.retry" && entry.delayMs === 10)).toBe(true);
    expect(events.some((entry) => entry.event === "message.retry" && entry.delayMs === 20)).toBe(true);
    expect(events.at(-1)?.event).toBe("message.dead_letter");
    expect(events.every((entry) => entry.correlationId === "corr-room-123")).toBe(true);
  });

  it("rechaza una versión de contrato incompatible", async () => {
    const handler = vi.fn(async (_message: ReceiverSyncRequestedV1) => undefined);
    const queue = new LocalMessageQueue(handler);
    const incompatible = { ...sampleMessage(), schemaVersion: 2 };
    await expect(queue.publish(incompatible)).rejects.toThrow("Versión de contrato no compatible");
    await queue.drain();
    expect(handler).not.toHaveBeenCalled();
  });

  it("acepta campos adicionales compatibles sin cambiar la semántica de V1", async () => {
    const handler = vi.fn(async (_message: ReceiverSyncRequestedV1) => undefined);
    const queue = new LocalMessageQueue(handler, { sleep: async () => undefined });
    const extension = { ...sampleMessage(), producerVersion: "1.2.0" };
    await expect(queue.publish(extension)).resolves.toBeUndefined();
    await queue.drain();
    expect(handler).toHaveBeenCalledTimes(1);
  });
});

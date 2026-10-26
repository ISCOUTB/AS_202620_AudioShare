import { describe, expect, it } from "vitest";
import { MessageQueueSimulator, type RoomAuditMessage } from "../docs/prototypes/messaging-queue.js";
const message: RoomAuditMessage = { messageId: "evt-001", schemaVersion: 1, eventType: "room.created", occurredAt: "2026-10-25T12:00:00.000Z", roomId: "room-42", producerId: "api" };
describe("isolated messaging prototype", () => {
  it("suppresses duplicate message IDs while queued", () => {
    const queue = new MessageQueueSimulator(async () => undefined);
    queue.publish(message); queue.publish(message);
    expect(queue.pending).toHaveLength(1);
    expect(queue.logs.some(x => x.stage === "duplicate")).toBe(true);
  });
  it("retries a recoverable failure and succeeds on the next attempt", async () => {
    let now = Date.parse("2026-10-25T12:00:00.000Z"); let calls = 0;
    const queue = new MessageQueueSimulator(async () => { calls++; if (calls === 1) throw new Error("temporary database unavailable"); }, 3, [100, 200], () => now);
    queue.publish(message); await queue.drainDue();
    expect(queue.pending).toHaveLength(1); expect(queue.logs.at(-1)?.stage).toBe("retry");
    now += 100; await queue.drainDue();
    expect(calls).toBe(2); expect(queue.pending).toHaveLength(0); expect(queue.deadLetters).toHaveLength(0);
    expect(queue.logs.some(x => x.stage === "consumed")).toBe(true);
    expect(queue.logs.every(x => x.messageId === "evt-001")).toBe(true);
  });
});

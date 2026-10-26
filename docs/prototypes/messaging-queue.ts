export interface RoomAuditMessage {
  messageId: string; schemaVersion: 1; eventType: "room.created";
  occurredAt: string; roomId: string; producerId: string;
}
export interface QueueRecord { message: RoomAuditMessage; attempts: number; nextAttemptAt: number }
export type LogEntry = { messageId: string; stage: "published" | "consumed" | "duplicate" | "retry" | "dead-letter"; attempt: number; timestamp: string; detail?: string };
export class MessageQueueSimulator {
  readonly pending: QueueRecord[] = []; readonly deadLetters: QueueRecord[] = []; readonly logs: LogEntry[] = [];
  private readonly processed = new Set<string>();
  constructor(private readonly handler: (message: RoomAuditMessage) => Promise<void>, private readonly maxAttempts = 3, private readonly backoffMs = [100, 200], private readonly now: () => number = () => Date.now()) {}
  publish(message: RoomAuditMessage): void {
    validateMessage(message);
    if (this.pending.some(x => x.message.messageId === message.messageId) || this.deadLetters.some(x => x.message.messageId === message.messageId)) { this.log(message.messageId, "duplicate", 0, "already queued"); return; }
    this.pending.push({ message, attempts: 0, nextAttemptAt: this.now() }); this.log(message.messageId, "published", 0);
  }
  async drainDue(): Promise<void> {
    const count = this.pending.length;
    for (let i = 0; i < count; i++) {
      const record = this.pending.shift(); if (!record) continue;
      if (record.nextAttemptAt > this.now()) { this.pending.push(record); continue; }
      if (this.processed.has(record.message.messageId)) { this.log(record.message.messageId, "duplicate", record.attempts, "already processed"); continue; }
      record.attempts++;
      try { await this.handler(record.message); this.processed.add(record.message.messageId); this.log(record.message.messageId, "consumed", record.attempts); }
      catch (error) {
        const detail = error instanceof Error ? error.message : "unknown error";
        if (record.attempts >= this.maxAttempts) { this.deadLetters.push(record); this.log(record.message.messageId, "dead-letter", record.attempts, detail); }
        else { const delay = this.backoffMs[record.attempts - 1] ?? this.backoffMs[this.backoffMs.length - 1] ?? 0; record.nextAttemptAt = this.now() + delay; this.pending.push(record); this.log(record.message.messageId, "retry", record.attempts, detail); }
      }
    }
  }
  private log(messageId: string, stage: LogEntry["stage"], attempt: number, detail?: string): void { this.logs.push({ messageId, stage, attempt, timestamp: new Date(this.now()).toISOString(), detail }); }
}
export function validateMessage(value: RoomAuditMessage): void {
  if (!value || !value.messageId?.trim()) throw new Error("messageId is required");
  if (value.schemaVersion !== 1) throw new Error("unsupported schemaVersion");
  if (value.eventType !== "room.created") throw new Error("unsupported eventType");
  if (!value.roomId || !value.producerId || !Number.isFinite(Date.parse(value.occurredAt))) throw new Error("invalid required field");
}

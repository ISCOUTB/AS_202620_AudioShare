export interface SyncStartEvent {
  type: "sync.start";
  startAt: number;
}

export interface SyncPauseEvent {
  type: "sync.pause";
  positionMs: number;
}

export class SyncCoordinator {
  private positionMs = 0;
  private playing = false;

  start(): SyncStartEvent {
    this.playing = true;

    return {
      type: "sync.start",
      startAt: Date.now() + 500,
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
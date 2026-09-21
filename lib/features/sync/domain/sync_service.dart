class SyncSnapshot {
  const SyncSnapshot({this.startAt, this.playing = false, this.positionMs = 0});

  final int? startAt;
  final bool playing;
  final int positionMs;
}

class SyncService {
  SyncSnapshot fromRoom({required int? startAt, required bool playing, required int positionMs}) =>
      SyncSnapshot(startAt: startAt, playing: playing, positionMs: positionMs);
}

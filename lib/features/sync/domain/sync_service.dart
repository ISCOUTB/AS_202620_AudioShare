class SyncSnapshot {
  const SyncSnapshot({this.startAt, this.playing = false, this.positionMs = 0});

  final int? startAt;
  final bool playing;
  final int positionMs;
}

/// Muestra de reloj tomada contra `GET /time`:
/// [t0] reloj local al enviar, [serverTime] respuesta, [t1] reloj local al recibir.
class ClockSample {
  const ClockSample({required this.t0, required this.serverTime, required this.t1});

  final int t0;
  final int serverTime;
  final int t1;

  int get roundTripMs => t1 - t0;
}

class SyncService {
  SyncSnapshot fromRoom({required int? startAt, required bool playing, required int positionMs}) =>
      SyncSnapshot(startAt: startAt, playing: playing, positionMs: positionMs);

  /// Offset (reloj_servidor − reloj_local) de una muestra, suponiendo que el
  /// servidor respondió en el punto medio del viaje de ida y vuelta.
  double estimateOffsetMs(ClockSample sample) =>
      sample.serverTime - (sample.t0 + sample.t1) / 2;

  /// Usa la muestra con menor tiempo de ida y vuelta (la menos afectada por la red).
  double estimateBestOffsetMs(List<ClockSample> samples) {
    if (samples.isEmpty) {
      throw ArgumentError('Se necesita al menos una muestra de reloj');
    }
    final best = samples.reduce((a, b) => b.roundTripMs < a.roundTripMs ? b : a);
    return estimateOffsetMs(best);
  }

  /// Milisegundos a esperar (en el reloj local) para arrancar exactamente en
  /// [startAt] del servidor. Nunca negativo: si ya pasó, arranca de inmediato.
  int delayUntilStartMs({
    required int startAt,
    required int localNow,
    required double offsetMs,
  }) {
    final delay = startAt - (localNow + offsetMs);
    return delay <= 0 ? 0 : delay.round();
  }
}

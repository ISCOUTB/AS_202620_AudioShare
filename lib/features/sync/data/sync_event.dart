import 'dart:convert';

/// Evento recibido por el stream NDJSON de un receptor
/// (`GET /rooms/{id}/stream/{receiverId}`, docs/contracts/asyncapi.yaml).
sealed class SyncEvent {
  const SyncEvent();

  /// Interpreta una línea NDJSON. Devuelve null si no es un objeto JSON válido
  /// o si un evento conocido viene mal formado: el cliente lo ignora.
  static SyncEvent? parse(String line) {
    try {
      final json = jsonDecode(line);
      if (json is! Map) return null;
      switch (json['type']) {
        case 'sync.start':
          return SyncStartEvent(
            (json['startAt'] as num).toInt(),
            positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
          );
        case 'sync.pause':
          return SyncPauseEvent((json['positionMs'] as num).toInt());
        case 'audio.chunk':
          return AudioChunkEvent((json['sequence'] as num).toInt());
        default:
          return const UnknownSyncEvent();
      }
    } catch (_) {
      return null;
    }
  }
}

/// `startAt` está en el reloj del servidor (epoch ms).
final class SyncStartEvent extends SyncEvent {
  const SyncStartEvent(this.startAt, {this.positionMs = 0});
  final int startAt;

  /// Posición de la pista (ms) que debe sonar en [startAt]; 0 si es el inicio.
  final int positionMs;
}

final class SyncPauseEvent extends SyncEvent {
  const SyncPauseEvent(this.positionMs);
  final int positionMs;
}

/// El payload no se usa: el audio real se descarga de `GET /track`.
final class AudioChunkEvent extends SyncEvent {
  const AudioChunkEvent(this.sequence);
  final int sequence;
}

final class UnknownSyncEvent extends SyncEvent {
  const UnknownSyncEvent();
}

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
        case 'participant.joined':
          final participant = (json['participant'] as Map).cast<String, dynamic>();
          return ParticipantEvent(ParticipantChange.joined, participant['id'] as String);
        case 'participant.left':
          return ParticipantEvent(
            ParticipantChange.left,
            json['receiverId'] as String,
            removed: json['reason'] == 'removed',
          );
        case 'participant.connected':
          return ParticipantEvent(ParticipantChange.connected, json['receiverId'] as String);
        case 'participant.disconnected':
          return ParticipantEvent(ParticipantChange.disconnected, json['receiverId'] as String);
        case 'track.changed':
          return TrackChangedEvent(
            json['trackName'] as String?,
            (json['trackVersion'] as num).toInt(),
          );
        case 'room.closed':
          return const RoomClosedEvent();
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

enum ParticipantChange { joined, left, connected, disconnected }

/// Alguien entró, salió, se conectó o se desconectó. Con [removed] el emisor
/// lo expulsó (solo en `left`).
final class ParticipantEvent extends SyncEvent {
  const ParticipantEvent(this.change, this.participantId, {this.removed = false});
  final ParticipantChange change;
  final String participantId;
  final bool removed;
}

/// El emisor subió una pista nueva: la sala queda detenida en 0.
final class TrackChangedEvent extends SyncEvent {
  const TrackChangedEvent(this.trackName, this.trackVersion);
  final String? trackName;
  final int trackVersion;
}

/// El emisor cerró la sala para todos.
final class RoomClosedEvent extends SyncEvent {
  const RoomClosedEvent();
}

final class UnknownSyncEvent extends SyncEvent {
  const UnknownSyncEvent();
}

// Modelos de la sala, según el contrato `RoomState` / `Participant` de
// docs/contracts/openapi.yaml.
//
// NOTA: esta carpeta fue reconstruida a partir de los usos en
// lib/features/session/presentation, test/ y el contrato OpenAPI, porque
// nunca se subió al repositorio (el patrón `data/` del .gitignore la ignoraba).

enum PlaybackStatus { stopped, playing, paused }

enum ParticipantRole { emitter, receiver }

class Participant {
  const Participant({
    required this.id,
    required this.role,
    required this.joinedAt,
  });

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        id: json['id'] as String,
        role: _roleFrom(json['role']),
        joinedAt: DateTime.parse(json['joinedAt'] as String),
      );

  final String id;
  final ParticipantRole role;
  final DateTime joinedAt;
}

class Room {
  const Room({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.playing,
    required this.positionMs,
    required this.startAt,
    required this.participants,
    this.connectedReceivers = 0,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    final state = (json['playbackState'] as Map).cast<String, dynamic>();

    return Room(
      id: json['roomId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: _statusFrom(json['status']),
      playing: state['playing'] as bool,
      positionMs: (state['positionMs'] as num).toInt(),
      startAt: (json['startAt'] as num?)?.toInt(),
      participants: (json['participants'] as List)
          .map((item) => Participant.fromJson((item as Map).cast<String, dynamic>()))
          .toList(),
      connectedReceivers: (json['connectedReceivers'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final DateTime createdAt;
  final PlaybackStatus status;
  final bool playing;
  final int positionMs;

  /// Referencia temporal común (reloj del servidor, epoch ms); null si aún
  /// no se ha iniciado la reproducción.
  final int? startAt;
  final List<Participant> participants;
  final int connectedReceivers;
}

PlaybackStatus _statusFrom(Object? raw) => PlaybackStatus.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => throw FormatException('Estado de sala desconocido: $raw'),
    );

ParticipantRole _roleFrom(Object? raw) => ParticipantRole.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => throw FormatException('Rol de participante desconocido: $raw'),
    );

import 'package:flutter_test/flutter_test.dart';
import 'package:audioshare/features/session/data/models/room.dart';

void main() {
  test('Room interpreta el contrato del backend', () {
    final room = Room.fromJson({'roomId': 'abc', 'createdAt': '2026-01-01T00:00:00Z', 'status': 'playing', 'playbackState': {'playing': true, 'positionMs': 0}, 'startAt': 123, 'participants': [{'id': 'emitter', 'role': 'emitter', 'joinedAt': '2026-01-01T00:00:00Z'}], 'connectedReceivers': 0});
    expect(room.id, 'abc');
    expect(room.status, PlaybackStatus.playing);
    expect(room.participants.single.role, ParticipantRole.emitter);
  });
}

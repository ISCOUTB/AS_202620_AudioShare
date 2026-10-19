import 'package:flutter_test/flutter_test.dart';
import 'package:audioshare/features/sync/data/sync_event.dart';

void main() {
  test('interpreta sync.start con su startAt', () {
    final event = SyncEvent.parse('{"type":"sync.start","startAt":1760000000500}');
    expect(event, isA<SyncStartEvent>());
    expect((event as SyncStartEvent).startAt, 1760000000500);
  });

  test('sync.start trae positionMs al reanudar y 0 si falta', () {
    final resumed = SyncEvent.parse('{"type":"sync.start","startAt":10,"positionMs":3000}');
    expect((resumed as SyncStartEvent).positionMs, 3000);
    final fresh = SyncEvent.parse('{"type":"sync.start","startAt":10}');
    expect((fresh as SyncStartEvent).positionMs, 0);
  });

  test('interpreta sync.pause y audio.chunk', () {
    final pause = SyncEvent.parse('{"type":"sync.pause","positionMs":0}');
    expect(pause, isA<SyncPauseEvent>());
    final chunk = SyncEvent.parse('{"type":"audio.chunk","sequence":3,"payload":"x"}');
    expect(chunk, isA<AudioChunkEvent>());
    expect((chunk as AudioChunkEvent).sequence, 3);
  });

  test('un tipo desconocido se reconoce pero no se interpreta', () {
    expect(SyncEvent.parse('{"type":"otra.cosa"}'), isA<UnknownSyncEvent>());
  });

  test('líneas inválidas o eventos mal formados se ignoran', () {
    expect(SyncEvent.parse('no es json'), isNull);
    expect(SyncEvent.parse('[1,2]'), isNull);
    expect(SyncEvent.parse('{"type":"sync.start"}'), isNull);
  });
}

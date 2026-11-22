import 'package:audioshare/features/live/domain/live_audio_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveEngineEvent.parse', () {
    test('interpreta los estados del motor', () {
      final sharing = LiveEngineEvent.parse(
        '{"type":"state","side":"emit","state":"sharing","source":"tab","label":"Una pestaña"}',
      );
      expect(sharing, isA<LiveStateEvent>());
      final state = sharing! as LiveStateEvent;
      expect(state.state, LiveLinkState.sharing);
      expect(state.source, 'tab');
      expect(state.label, 'Una pestaña');

      final connected = LiveEngineEvent.parse('{"type":"state","state":"connected"}')! as LiveStateEvent;
      expect(connected.state, LiveLinkState.waiting);

      final ended = LiveEngineEvent.parse(
        '{"type":"state","state":"ended","message":"Dejaste de compartir desde el navegador."}',
      )! as LiveStateEvent;
      expect(ended.state, LiveLinkState.idle);
      expect(ended.message, contains('navegador'));

      final failed = LiveEngineEvent.parse(
        '{"type":"state","state":"error","message":"La sala se cerró.","code":4410}',
      )! as LiveStateEvent;
      expect(failed.state, LiveLinkState.error);
      expect(failed.code, 4410);
    });

    test('interpreta si el emisor está transmitiendo', () {
      final live = LiveEngineEvent.parse(
        '{"type":"live","active":true,"source":"device","label":"Todo el dispositivo"}',
      )! as LiveBroadcastEvent;
      expect(live.active, isTrue);
      expect(live.source, 'device');

      final stopped = LiveEngineEvent.parse('{"type":"live","active":false,"source":null,"label":null}')!
          as LiveBroadcastEvent;
      expect(stopped.active, isFalse);
      expect(stopped.source, isNull);
    });

    test('interpreta las estadísticas de receptor y de emisor', () {
      final receiver = LiveEngineEvent.parse(
        '{"type":"stats","side":"receive","latencyMs":279,"played":78,"late":1,"resyncs":0}',
      )! as LiveStatsEvent;
      expect(receiver.latencyMs, 279);
      expect(receiver.late, 1);
      expect(receiver.sent, isNull);

      final emitter = LiveEngineEvent.parse('{"type":"stats","side":"emit","sent":120,"dropped":2}')!
          as LiveStatsEvent;
      expect(emitter.sent, 120);
      expect(emitter.dropped, 2);
    });

    test('ignora lo que no es un evento válido', () {
      expect(LiveEngineEvent.parse('no es json'), isNull);
      expect(LiveEngineEvent.parse('[1,2]'), isNull);
      expect(LiveEngineEvent.parse('{"type":"state","state":"desconocido"}'), isNull);
      expect(LiveEngineEvent.parse('{"type":"otra-cosa"}'), isNull);
    });
  });

  test('CaptureSource.fromWire reconoce los nombres del protocolo', () {
    expect(CaptureSource.fromWire('device'), CaptureSource.device);
    expect(CaptureSource.fromWire('app'), CaptureSource.app);
    expect(CaptureSource.fromWire('tab'), CaptureSource.tab);
    expect(CaptureSource.fromWire('radio'), isNull);
    expect(CaptureSource.fromWire(null), isNull);
  });

  test('el motor no soportado explica por qué no se puede compartir', () async {
    final engine = UnsupportedLiveAudioEngine();
    expect(engine.canReceive, isFalse);
    expect(engine.captureOptions, hasLength(CaptureSource.values.length));
    expect(engine.captureOptions.every((option) => !option.available && option.reason != null), isTrue);
    await expectLater(
      engine.startEmitting(
        url: Uri.parse('wss://audioshare.test/rooms/1/live'),
        emitterKey: 'llave',
        source: CaptureSource.tab,
        offsetMs: 0,
      ),
      throwsA(isA<LiveEngineException>()),
    );
    await engine.dispose();
  });
}

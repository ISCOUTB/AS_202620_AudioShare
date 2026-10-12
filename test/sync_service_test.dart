import 'package:flutter_test/flutter_test.dart';
import 'package:audioshare/features/sync/domain/sync_service.dart';

// Mismos casos que tests/sync-a01.test.ts (lado backend): el algoritmo de
// corrección de reloj debe comportarse igual en ambos lados (ADR-0007).
void main() {
  final sync = SyncService();

  test('estima el offset como servidor − punto medio local', () {
    // Reloj local 3000 ms adelantado; ida y vuelta de 20 ms.
    const sample = ClockSample(t0: 13000, serverTime: 10010, t1: 13020);
    expect(sync.estimateOffsetMs(sample), -3000);
  });

  test('elige la muestra con menor tiempo de ida y vuelta', () {
    const noisy = ClockSample(t0: 0, serverTime: 5000, t1: 400);
    const clean = ClockSample(t0: 1000, serverTime: 5995, t1: 1010);
    expect(sync.estimateBestOffsetMs([noisy, clean]), 4990);
  });

  test('espera hasta startAt en el reloj del servidor, no en el local', () {
    expect(sync.delayUntilStartMs(startAt: 10500, localNow: 8000, offsetMs: 2000), 500);
    expect(sync.delayUntilStartMs(startAt: 10500, localNow: 9000, offsetMs: 2000), 0);
  });

  test('sin muestras lanza ArgumentError', () {
    expect(() => sync.estimateBestOffsetMs([]), throwsArgumentError);
  });
}

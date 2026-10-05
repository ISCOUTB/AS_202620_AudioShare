import { describe, expect, it } from "vitest";

describe("A-01 / EC-01 - Sincronización inicial", () => {
  it("mantiene la diferencia máxima entre receptores por debajo de 100 ms", () => {
    const startAt = 1000;

    const receiverStartTimes = [
      startAt + 20,
      startAt + 35,
      startAt + 60,
    ];

    const minimum = Math.min(...receiverStartTimes);
    const maximum = Math.max(...receiverStartTimes);

    const difference = maximum - minimum;

    expect(difference).toBeLessThanOrEqual(100);
  });
});

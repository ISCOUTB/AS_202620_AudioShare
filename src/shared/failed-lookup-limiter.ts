/**
 * Limita los intentos fallidos de consultar salas que no existen (AM-04).
 *
 * El código de sala es de 6 dígitos (un millón de combinaciones): sin un tope
 * a los intentos fallidos se podría recorrer por fuerza bruta. Solo cuentan
 * los códigos inexistentes, así que el uso normal (acertar el código, o
 * equivocarse un par de veces) nunca llega al tope. Superado el tope, el
 * origen queda bloqueado hasta que termina la ventana, incluso para códigos
 * válidos: de lo contrario un acierto atravesaría el límite.
 *
 * Es memoria del proceso: se reinicia con el servicio y no se comparte entre
 * instancias, lo que basta para un único contenedor.
 */
export class FailedLookupLimiter {
  private readonly entries = new Map<string, { windowStart: number; failures: number }>();

  constructor(
    private readonly max: number,
    private readonly windowMs: number,
  ) {}

  /** Segundos de espera si el origen está bloqueado; 0 si puede continuar. */
  retryAfterSeconds(key: string, now: number): number {
    if (this.max <= 0) {
      return 0;
    }

    const entry = this.entries.get(key);

    if (!entry) {
      return 0;
    }

    if (now - entry.windowStart >= this.windowMs) {
      this.entries.delete(key);
      return 0;
    }

    if (entry.failures < this.max) {
      return 0;
    }

    return Math.max(1, Math.ceil((entry.windowStart + this.windowMs - now) / 1000));
  }

  recordFailure(key: string, now: number): void {
    if (this.max <= 0) {
      return;
    }

    this.prune(now);
    const entry = this.entries.get(key);

    if (!entry || now - entry.windowStart >= this.windowMs) {
      this.entries.set(key, { windowStart: now, failures: 1 });
      return;
    }

    entry.failures += 1;
  }

  private prune(now: number): void {
    if (this.entries.size < 1000) {
      return;
    }

    for (const [key, entry] of this.entries) {
      if (now - entry.windowStart >= this.windowMs) {
        this.entries.delete(key);
      }
    }
  }
}

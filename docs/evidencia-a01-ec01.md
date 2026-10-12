# Evidencia A-01 / EC-01 — sincronización inicial

Cadena: [EC-01](./escenarios_calidad.md#ec-01--sincronización-inicial) →
[ADR-0005](./adr/0005-validacion-sincronizacion-inicial.md) y
[ADR-0007](./adr/0007-correccion-de-reloj-y-ack-de-arranque.md) →
`src/modules/sync/index.ts` → `tests/sync-a01.test.ts` → medición de abajo.

## Qué se mide (y qué no)

Se mide el **protocolo**: tres receptores simulados (proceso Node, reloj local
desfasado +3000 ms, −2500 ms y +120 ms) se conectan al servidor real,
calibran su reloj con `GET /time`, reciben `sync.start`, esperan hasta
`startAt` y reportan su instante de arranque por ACK. El servidor calcula la
diferencia entre el primer y el último arranque.

**No** se mide reproducción de audio en dispositivos físicos ni latencia real
de Wi-Fi; eso sigue pendiente (README, "Limitaciones conocidas").

## Cómo reproducirlo

```bash
npm ci
npx vitest run tests/sync-a01.test.ts
```

Las líneas `receiver.ack` del log traen `deviationMs` y `spreadMs` (acumulado;
el valor final de cada sala es el desfase entre receptores).

## Resultado (2026-10-12, Windows, Node v25.9.0)

| Escenario | Desfase entre receptores | Umbral EC-01 |
|---|---|---|
| Con corrección de reloj | 4,5 ms | ≤ 100 ms — cumple |
| Sin corrección (defecto del ADR-0005, alternativa 2) | 2509 ms | ≤ 100 ms — no cumple |

Tras restaurar el código, la prueba se ejecutó 5 veces seguidas y pasó las 5.

Una ejecución previa en Linux con Node 22 dio 1,5 ms con corrección y
2503 ms sin ella.

## Mutación: la prueba falla ante el defecto

Procedimiento: en `src/modules/sync/index.ts`, función `delayUntilStart`,
cambiar

```ts
return Math.max(0, startAt - (localNow + offsetMs));
```

por

```ts
return Math.max(0, startAt - localNow);
```

y ejecutar `npx vitest run tests/sync-a01.test.ts`. Resultado observado
(2 pruebas en rojo, 3 en verde):

```
expected 2500 to be 500                              (prueba unitaria)
expected 2984 to be less than or equal to 100        (receptores simulados)
```

Al revertir el cambio las 5 pruebas pasan.
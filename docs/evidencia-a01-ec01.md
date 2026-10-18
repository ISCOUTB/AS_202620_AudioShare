# Evidencia A-01 / EC-01 — sincronización inicial

Cadena: [EC-01](./escenarios_calidad.md#ec-01--sincronización-inicial) →
[ADR-0005](./adr/0005-validacion-sincronizacion-inicial.md) y
[ADR-0007](./adr/0007-correccion-de-reloj-y-ack-de-arranque.md) →
`src/modules/sync/index.ts` → `tests/sync-a01.test.ts` → medición de abajo.

## Qué se mide (y qué no)

Se mide el **protocolo**: tres receptores simulados (proceso Node, reloj local
desfasado +3000 ms, −2500 ms y +120 ms) se conectan al servidor real,
calibran su reloj con `GET /time`, reciben `sync.start`, esperan hasta
`startAt` y reportan su instante de arranque por ACK.

**No** se mide reproducción de audio en dispositivos físicos ni latencia real
de Wi-Fi; eso sigue pendiente (README, «Limitaciones conocidas»).

## Dos medidas del mismo desfase, y por qué importa

La prueba obtiene el desfase entre el primer y el último receptor en
arrancar de dos maneras:

- **Desfase reportado por el servidor** (`GET /rooms/:roomId/sync`): el
  servidor convierte cada instante de arranque a su propio reloj con el
  `offsetMs` que informa cada receptor.
- **Desfase real**: diferencia medida con un único reloj de referencia, el
  del proceso de prueba (`Date.now()`), que es común a todos los receptores
  simulados. Es la verdad contra la que se contrasta lo anterior.

La primera versión de esta evidencia comparaba únicamente el valor
reportado en los dos escenarios, y esa comparación **mezclaba relojes**:
en el escenario sin corrección los receptores informan `offsetMs = 0`, así
que el servidor suma instantes de relojes locales distintos como si
fueran del mismo reloj. Resultado: reportaba ≈ 2500 ms cuando el desfase
real era ≈ 3000 ms. Con corrección ambas medidas coinciden, y eso es lo
que valida la estimación de reloj. Las dos cifras **no son comparables
entre escenarios**; la que vale para el defecto es el desfase real.

## Cómo reproducirlo

```bash
npm ci
npx vitest run tests/sync-a01.test.ts
```

La prueba imprime una línea JSON por escenario con
`spreadReportadoPorServidorMs` y `spreadRealMs`.

## Resultados

Prueba actual (con reloj de referencia único), tres ejecuciones seguidas,
Linux, Node 22, entorno de desarrollo del asistente:

| Ejecución | Escenario | Desfase reportado por el servidor | Desfase real | Umbral EC-01 (≤ 100 ms) |
|---|---|---|---|---|
| 1 | Con corrección | 3,5 ms | 4 ms | cumple |
| 1 | Sin corrección | 2504 ms | 2996 ms | no cumple |
| 2 | Con corrección | 5,5 ms | 5 ms | cumple |
| 2 | Sin corrección | 2502 ms | 2998 ms | no cumple |
| 3 | Con corrección | 1,5 ms | 2 ms | cumple |
| 3 | Sin corrección | 2504 ms | 2996 ms | no cumple |

Prueba actual en el equipo de desarrollo (Windows, Node v25.9.0), cuatro
ejecuciones: la primera dentro de `npm run verify` y las otras tres
seguidas:

| Ejecución | Escenario | Desfase reportado por el servidor | Desfase real | Umbral EC-01 (≤ 100 ms) |
|---|---|---|---|---|
| 1 | Con corrección | 4,5 ms | 5 ms | cumple |
| 1 | Sin corrección | 2513 ms | 2991 ms | no cumple |
| 2 | Con corrección | 6,5 ms | 7 ms | cumple |
| 2 | Sin corrección | 2546 ms | 2958 ms | no cumple |
| 3 | Con corrección | 2,5 ms | 3 ms | cumple |
| 3 | Sin corrección | 2502 ms | 2998 ms | no cumple |
| 4 | Con corrección | 3 ms | 4 ms | cumple |
| 4 | Sin corrección | 2502 ms | 2998 ms | no cumple |

Lectura de los resultados de Windows:

- Con corrección, el desfase real fue de 3 a 7 ms, y el que reporta el
  servidor difirió del real en 1 ms como máximo. La estimación de reloj
  coincide con la verdad de referencia.
- Sin corrección, el desfase real fue de 2958 a 2998 ms. El valor reportado
  (2502 a 2546 ms) mezcla relojes locales y no es comparable con el del
  escenario corregido.

Medición anterior del equipo, con la prueba previa que no registraba el
reloj de referencia: reportado 4,5 ms con corrección y 2509 ms sin ella. El
desfase real de esa ejecución no se midió.

Los números anteriores son del protocolo con receptores simulados en una
misma máquina; no son una medición con dispositivos físicos.

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

y ejecutar `npx vitest run tests/sync-a01.test.ts`. Resultado observado con
la prueba actual (Linux, Node 22; 2 pruebas en rojo, 3 en verde):

```
expected 2500 to be 500                              (prueba unitaria)
expected 2996.5 to be less than or equal to 100      (receptores simulados)
```

Al revertir el cambio las 5 pruebas pasan. Con la prueba anterior, en
Windows, el mismo cambio produjo `expected 2984 to be less than or equal to
100`.

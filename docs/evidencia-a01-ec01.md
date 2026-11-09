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

**No** se mide con ello la reproducción de audio en dispositivos físicos ni la
latencia real de Wi-Fi; las corridas con dispositivos reales están en
[«Medición con dispositivos físicos»](#medición-con-dispositivos-físicos) y
siguen siendo insuficientes para dar el escenario por cumplido.

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

## Medición con dispositivos físicos

Corridas hechas por el equipo contra la API publicada
(`https://audioshare.iscoutb.dev`, Dokploy), con la app Flutter como receptor.
El valor que se contrasta es `spreadMs` de `GET /rooms/:roomId/sync`: la
diferencia entre el primer y el último receptor en arrancar, con cada
instante llevado al reloj del servidor mediante el `offsetMs` que estimó el
propio receptor. El umbral es el de
[EC-01](./escenarios_calidad.md#ec-01--sincronización-inicial): **≤ 100 ms**
(`EC01_THRESHOLD_MS`).

| Fecha | Receptores | Offset de reloj estimado | `deviationMs` por receptor | `spreadMs` | Umbral ≤ 100 ms |
|---|---|---|---|---|---|
| 2026-10-18 | 1 PC con Windows | −31880 ms | 21 ms | `null` (un solo receptor) | no evaluable |
| 2026-10-19 | 2 PC con Windows (`receiver-pc3`, `receiver-pc`) | no registrado | 355 ms y 21,5 ms | **333,5 ms** | **no cumple** (3,3 veces el umbral) |
| 2026-10-19 | Celular Android (SM-A127M) y app de Windows | −367 ms (celular) y −32441 ms (PC) | 6 ms (celular) y 40 ms (PC) | **34 ms** | **cumple** (`withinThreshold: true`) |

### Contraste con el umbral

| Medición | Receptores | Desfase | ¿≤ 100 ms? |
|---|---|---|---|
| Protocolo simulado, Linux (3 ejecuciones) | 3 simulados | 2 a 5 ms reales | Sí |
| Protocolo simulado, Windows (4 ejecuciones) | 3 simulados | 3 a 7 ms reales | Sí |
| Física: 2 PC con Windows | 2 | 333,5 ms | **No** |
| Física: celular Android y PC con Windows | 2 | 34 ms | Sí, con la salvedad de abajo |

**Veredicto.** EC-01 **no está demostrado** con dispositivos físicos. De las
dos corridas físicas evaluables, una cumple (34 ms) y una no (333,5 ms), y
dos corridas no bastan para sostener ninguna de las dos conclusiones. Lo que
sí está demostrado es que el protocolo con reloj corregido cumple en un
entorno controlado (secciones anteriores) y que la corrección absorbe
desfases de reloj grandes: los PC difieren del servidor en unos 32 s
(−31880 y −32441 ms en corridas distintas) y el celular en 367 ms, sin que
eso aparezca en el `spreadMs`.

### Por qué 34 ms todavía no cierra EC-01

1. **El instante medido es el que declara el receptor**, no el sonido. Es el
   momento en que la app informa que arrancó, convertido con su propia
   estimación de reloj. No incluye la latencia de salida de audio de cada
   dispositivo, que puede sumar decenas o cientos de milisegundos y es
   distinta en un celular Android y en un PC con Windows. Esa latencia solo se
   cuantifica con una medición acústica.
2. **El `spreadMs` es autodeclarado.** Cualquier cliente puede enviar ACK
   (AM-08 en [`amenazas-priorizadas.md`](./amenazas-priorizadas.md)); el
   servidor no verifica el instante.
3. **NC-03 pide una referencia externa** y esta medición no la tiene.
4. **N = 2 corridas con dos receptores.** El plan era repetir al menos cinco.

### Sobre la corrida que no cumple (333,5 ms)

La causa **no se determinó**. El `receiver-pc3` arrancó 355 ms tarde respecto
de `startAt` y el otro 21,5 ms. Hipótesis sin comprobar, ordenadas por
cercanía al código (ver FM-11 en [`modos-de-fallo.md`](./modos-de-fallo.md)):

- Estimación de reloj mala en ese receptor (muestra con RTT alto): el error
  de la estimación puede llegar a RTT/2.
- `sync.start` llegó después de `startAt` con `START_LEAD_MS = 500`, y
  `delayUntilStart` devolvió 0, así que arrancó apenas se enteró.
- Que ambos receptores compartieran máquina o que `just_audio_windows` tardara
  en iniciar el reproductor (DEP-11).

Para separar estas causas hay que registrar el RTT de las muestras de
`GET /time` y el instante en que cada receptor recibió el evento; hoy no se
guardan.

### Qué hace falta para cerrar EC-01

- **Repetir la corrida con celular y PC al menos cinco veces** y registrar
  cada una con `scripts/capturar-corrida.ps1` (genera
  `docs/evidencia-corridas.csv`).
- **Referencia externa por medición acústica**, al menos en tres de esas
  corridas: poner ambos dispositivos a la misma distancia de un micrófono
  (una diferencia de 30 cm equivale a 1 ms), reproducir una pista que empiece
  con un pulso corto, grabar con un tercer dispositivo y medir en el editor de
  audio la distancia entre los dos pulsos. Esa diferencia es el desfase real
  que oye una persona.
- **Registrar el entorno de cada corrida**: modelo de los dispositivos, red
  Wi-Fi, si la API era la publicada o una local, y el RTT mínimo de `/time`.
- Decidir con el resultado: si el desfase acústico supera 100 ms de forma
  sistemática en el celular, corresponde compensar la latencia de salida por
  dispositivo o revisar el umbral (ADR-0007 prevé revisarlo si el audio real
  exige otra precisión).

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

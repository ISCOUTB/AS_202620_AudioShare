# ADR-0011 — Separar estado transaccional y archivos de audio

- **Estado:** aceptado
- **Fecha:** 2026-10-25
- **Decide:** equipo AudioShare (AS_202620_AudioShare)
- **Complementa:** [ADR-0001 — Monolito modular](./0001-usar-monolito-modular.md), [ADR-0009 — No extraer módulos](./0009-no-extraer-modulos-como-servicios.md) y [ADR-0010 — Transporte de pista por HTTP](./0010-transporte-de-pista-por-http.md)
- **Aspecto:** A-01 — Sincronización de reproducción de audio
- **Contexto técnico:** cliente Flutter, backend Node/Express modular y SQLite

## Contexto y problema

AudioShare persiste salas, participantes y estado de reproducción, y almacena pistas MP3 que los receptores descargan para reproducir localmente. El estado relacional cambia con frecuencia y necesita transacciones; una pista es un objeto binario grande (límite de 50 MiB, `POST /rooms/:roomId/track`). SQLite y el sistema de archivos no comparten una transacción atómica: el archivo y la fila pueden fallar en momentos distintos.

Hay que fijar dónde viven los bytes de la pista y quién es la fuente de verdad de cada dato. Esta decisión se toma ahora porque cada pista subida y cada despliegue la consolidan.

## Por qué es la decisión de datos más costosa de revertir

Se compararon las decisiones de datos vigentes con cuatro dimensiones de costo de reversión. El criterio es cuántas dimensiones cruza una decisión, porque cada una exige un cambio coordinado distinto.

| Decisión de datos | Código a cambiar | Datos a migrar | Contrato y clientes | Infraestructura y operación | Costo de revertir |
|---|---|---|---|---|---|
| SQLite como motor (`better-sqlite3`) | Un repositorio detrás de la interfaz `RoomRepository` (`sqlite-room-repository.ts`) | Filas de dos tablas (`rooms`, `participants`), pequeñas | Ninguno: la API no expone SQL | Un archivo en el volumen | **Bajo** |
| Estado de reproducción (`playback_state`, `start_at`) guardado en `rooms` y propiedad de Session (NC-10) | Repositorio y la frontera Session/Sync | Dos columnas | `playbackState` y `startAt` están en `openapi.yaml` y en los modelos Flutter | Ninguna | **Medio** |
| Pistas como archivos fuera de SQLite, asociadas por `roomId` | `AudioTrackStore`, dos rutas de pista, protocolo de publicación y reconciliación | Archivos y referencias deben migrar juntos sin transacción común | URL estable, bajo | Volumen persistente (`audioshare-data`), backups coordinados DB + `tracks/`, despliegue en Dokploy | **Alto** |

La separación entre estado y archivos es la única que toca las cuatro dimensiones a la vez: define el formato de lo que ya está en el volumen, obliga a un protocolo propio de consistencia, condiciona el backup y el despliegue, y no puede deshacerse sin migrar los datos de todas las salas existentes. La decisión de motor se revierte cambiando una clase; el estado de reproducción, cambiando un esquema y un contrato. El estilo monolítico no es una decisión de datos y su costo de reversión se compara en el [ADR-0009](./0009-no-extraer-modulos-como-servicios.md).

## Decisión

1. SQLite es la fuente de verdad para salas, participantes y estado de reproducción.
2. Los bytes MP3 se guardan como archivos en `data/tracks/` (volumen persistente), con nombre derivado del identificador de sala generado por el servidor; nunca se usa un nombre elegido por el usuario como ruta.
3. Una pista no queda disponible hasta que está completa: se escribe en un archivo temporal del mismo directorio y se publica con un renombrado atómico.
4. La caché es derivada y descartable; no es fuente de verdad para reproducción ni permisos.
5. Los eventos se publican después de confirmar la escritura. Tras perder el stream, el cliente recupera el estado con `GET /rooms/:roomId`.

## Alternativas

### A. MP3 como BLOB en SQLite
**Ventajas:** bytes y metadatos podrían confirmarse en la misma transacción; backup unificado.
**Desventajas:** base de datos más grande, backups y restauraciones pesados, y entrega de archivos grandes menos conveniente (se pierde el soporte Range de `sendFile`).

### B. SQLite para estado y archivos persistentes para pistas — elegida
**Ventajas:** separa datos transaccionales de binarios, permite servir descargas con Range y no infla la base.
**Desventajas:** requiere publicación ordenada, reconciliación de huérfanos y backups coordinados.

### C. Almacenamiento de objetos externo
**Ventajas:** escalabilidad y separación operativa.
**Desventajas:** agrega configuración, credenciales, dependencia externa y posible costo; no se justifica para el alcance académico actual.

## Consecuencias

- SQLite es autoridad para estado; el archivo es autoridad para los bytes.
- Las copias deben incluir la base y `data/tracks/` de forma coherente.
- El volumen Docker debe ser persistente; un contenedor efímero no puede ser el único almacenamiento.
- Una migración futura a almacenamiento de objetos debe conservar el contrato HTTP y cambiar la implementación detrás de `AudioTrackStore`.

## Estado de implementación

| Elemento | Estado | Evidencia |
|---|---|---|
| Pista como archivo en `data/tracks/{roomId}.mp3` y descarga con Range | Implementado | `AudioTrackStore`, README, prueba de identidad de bytes en `tests/a01.test.ts` |
| Publicación atómica: temporal + renombrado, limpieza si falla | **Implementado el 2026-10-25** | `AudioTrackStore.save`; `tests/consistency-cache.test.ts` (incluye fallo simulado del renombrado) |
| Persistir en SQLite antes de publicar eventos | Implementado en PLAY y PAUSE | `src/app.ts`, manejadores `play` y `pause`; prueba solo de PLAY en `tests/consistency-cache.test.ts` |
| `GET /track` revalidable y `GET /rooms/:roomId/track` sin caché | Implementado | `docs/diseno-cache.md`; `tests/consistency-cache.test.ts` |
| Metadatos de la pista en SQLite | **No implementado.** Hoy la asociación sala → pista es el nombre del archivo |  |
| Versionar la pista en vez de sobrescribirla | **No implementado.** El renombrado atómico evita lecturas parciales, pero conserva el mismo nombre |  |
| Reconciliación de temporales y archivos huérfanos al arrancar | **No implementado** |  |
| Backup coordinado y prueba de restauración | **No implementado** |  |

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Caída entre la escritura del temporal y el renombrado | Queda un `.tmp` sin referencia; pendiente de limpieza al arrancar |
| Fila o sala sin archivo (o archivo sin sala) | `GET .../track` responde 404 si no existe el archivo; pendiente de comprobación de integridad |
| Se pierde el contenedor | Volumen persistente `audioshare-data`; prueba de reinicio pendiente |
| Backup incoherente | Pendiente: backup coordinado y prueba de restauración |
| Reemplazo durante una descarga | En Linux la descarga en curso conserva el archivo anterior y las nuevas ven el nuevo; en Windows el renombrado puede fallar si el archivo está abierto |

## Verificación

Automatizada hoy: subida y descarga con identidad de bytes; reemplazo completo sin temporales; pista anterior intacta si falla la publicación; cabeceras de caché; coherencia entre la respuesta de PLAY y la lectura posterior. Pendiente: reinicio del contenedor con pistas, restauración de backup y limpieza de huérfanos.

## Relación con otras decisiones

Complementa el monolito modular y el ADR-0010 sobre transporte HTTP de una pista MP3. Compartir una pista completa no equivale a capturar y transmitir audio en vivo.

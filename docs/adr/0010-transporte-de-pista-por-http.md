# ADR-0010 — Distribuir una pista MP3 por sala mediante HTTP

- **Estado:** aceptado
- **Fecha:** 2026-10-25
- **Decide:** equipo AudioShare (AS_202620_AudioShare)
- **Complementa:** [ADR-0002 — Estrategia de integración](./0002-estrategia-integracion.md), [ADR-0005 — Sincronización inicial](./0005-validacion-sincronizacion-inicial.md) y [ADR-0009 — Monolito modular](./0009-no-extraer-modulos-como-servicios.md)
- **Aspecto:** A-01 — Sincronización de reproducción de audio

## Contexto

El sistema ya distribuía una referencia temporal `sync.start` por NDJSON y
los receptores Flutter ya cargaban una pista por URL con `just_audio`. Sin
embargo, esa URL apuntaba a un MP3 fijo de demostración. El evento
`audio.chunk` transporta un `payload` de texto y el cliente no lo reproduce;
no es un transporte de audio.

## Decisión

El emisor selecciona un archivo MP3 (máximo 50 MiB) al crear la sala y lo
sube como `audio/mpeg` a `POST /rooms/{roomId}/track`. El módulo Audio lo
guarda en `data/tracks/{roomId}.mp3`, dentro del volumen persistente ya
montado por Docker Compose. Los receptores descargan la misma pista mediante
`GET /rooms/{roomId}/track`; Express admite peticiones `Range` para el seek
de `just_audio`. `startAt`, pausa/reanudación, reloj y ACK permanecen en sus
contratos existentes.

`audio.chunk` se conserva por compatibilidad como evento demostrativo y no
se presenta como contenido de audio. Esta decisión distribuye una pista
completa; no implementa captura de micrófono ni streaming en vivo.

## Alternativas consideradas

### WebRTC o streaming de chunks

Se descarta para este alcance porque reemplazaría el modelo de pista por
sesión ya implementado, requeriría señalización y cambios en los contratos
de sincronización/transporte. Se reconsiderará si el requisito pasa a ser
captura de micrófono en vivo o latencia interactiva, después de medir la
solución actual.

### Mantener el MP3 global de demostración

Se descarta porque los receptores no reproducirían contenido elegido por el
emisor.

## Consecuencias y verificación

- Se reutilizan HTTP, el volumen persistente, `just_audio` y el `startAt`
  existente; no se añade un servidor de medios ni se modifica Session/Sync.
- El costo de almacenamiento y transferencia crece con las pistas y los
  receptores; se limita el tamaño de carga a 50 MiB.
- `tests/a01.test.ts` verifica subida, descarga byte a byte y Range; las
  pruebas Flutter verifican el cuerpo binario enviado y la URL/posición que
  usa el receptor.
- La salida audible y los límites EC-01/EC-02 todavía requieren pruebas con
  dispositivos físicos. Tampoco se afirma que `audio.chunk` transporte el
  MP3.

## Trazabilidad

- Código: `src/modules/audio/index.ts`, `src/app.ts`,
  `lib/features/audio/data/audio_track_repository.dart`,
  `lib/features/audio/data/just_audio_service.dart` y
  `lib/features/session/presentation/viewmodels/session_view_model.dart`.
- Contrato: `docs/contracts/openapi.yaml`; evento de control:
  `docs/contracts/asyncapi.yaml`.
- Pruebas: `tests/a01.test.ts`, `tests/contract.test.ts`,
  `test/audio_track_repository_test.dart` y `test/receiver_sync_test.dart`.
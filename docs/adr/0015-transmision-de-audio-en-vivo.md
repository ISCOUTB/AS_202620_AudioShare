# ADR-0015 — Transmitir el audio del dispositivo en vivo por WebSocket

- **Estado:** aceptada (2026-11-22)
- **Sustituye en la práctica a:** [ADR-0010](0010-transporte-de-pista-por-http.md) para el flujo de la app. El endpoint de pista MP3 se conserva en el backend, pero el cliente Flutter ya no lo usa.

## Contexto

AudioShare repartía un MP3 que el emisor subía al crear la sala; cada receptor lo descargaba y lo reproducía en `startAt`. El objetivo del producto es otro: **transmitir en tiempo real el audio de un dispositivo a varios**, y que el emisor elija qué compartir: todo el dispositivo, una aplicación o una pestaña.

## Decisión

1. **Captura en el emisor.** En Flutter Web se usa `getDisplayMedia` (audio de una pestaña, o del sistema en Windows y ChromeOS). Un `AudioWorklet` convierte el audio en paquetes PCM de 16 bits, estéreo, 48 kHz, de 1024 muestras (≈21 ms).
2. **Transporte por WebSocket** en `/rooms/:roomId/live`, en el mismo servidor Express. El módulo `live` del backend solo **reenvía** los paquetes del emisor a los receptores de la sala; no decodifica ni mezcla. Un `hello` inicial autentica: el emisor con su `emitterKey` (no va en la URL) y el receptor con su identificador de participante.
3. **Sincronización entre receptores** con la referencia temporal que ya existe (ADR-0005 y ADR-0007): el emisor marca cada paquete con su instante de captura en reloj del servidor (offset calibrado con `GET /time`), y cada receptor lo reproduce en `captura + 400 ms`, también convertido con su offset. La reproducción es continua y solo se reajusta si se desvía más de 60 ms.
4. **Estado de la transmisión.** El WebSocket envía `live.state` a los receptores (activo, origen, etiqueta). `GET /rooms/:roomId/live` lo expone por HTTP. No se tocó el esquema de SQLite ni `RoomState`.
5. **Presencia y permisos sin cambios.** Expulsar a un receptor, que salga o que se cierre la sala corta también su WebSocket de audio. El origen del WebSocket se valida igual que el CORS, y los intentos con códigos de sala inexistentes cuentan en el mismo límite de AM-04.
6. **Contrapresión.** Si un receptor acumula más de 1 MiB sin enviarse, se le descartan paquetes: en vivo no sirve entregar audio atrasado. El emisor hace lo mismo con 512 KiB.

## Qué puede compartir cada plataforma

| Origen | Navegador (Chrome/Edge, escritorio) | Android nativo | Windows nativo |
|---|---|---|---|
| Todo el dispositivo | Solo Windows y ChromeOS | Pendiente (MediaProjection) | Pendiente (WASAPI loopback) |
| Una aplicación | **No** (el navegador no lo permite) | Pendiente (MediaProjection por UID, Android 10+) | Pendiente (loopback por proceso) |
| Una pestaña | Sí | — | — |

Firefox y Safari no entregan audio al compartir pantalla, y los navegadores de teléfono no ofrecen `getDisplayMedia`. Cualquier navegador moderno **sí puede ser receptor**, incluso el del teléfono.

## Consecuencias

- **Ancho de banda:** PCM sin comprimir son ≈1,5 Mbit/s por receptor. Es razonable en Wi-Fi local (R-02) y caro en datos móviles. El byte de códec del paquete deja espacio para añadir Opus sin cambiar el protocolo.
- **Retardo extremo a extremo** ≈ 400 ms más la latencia de captura. EC-01 (≤ 100 ms de diferencia entre receptores) y EC-02 hay que medirlos con dispositivos reales; el receptor publica retardo, paquetes tardíos y resincronizaciones en «Detalles técnicos».
- **Las apps nativas de Android y Windows** no reproducen ni capturan todavía: muestran un aviso. Hasta entonces, usar la app desde el navegador.
- Se añade la dependencia `ws` al backend y `web` a la app.
- Alternativa descartada: **WebRTC**. Mejor latencia, pero exige señalización, STUN/TURN y un SFU para varios receptores; es demasiado para esta etapa.

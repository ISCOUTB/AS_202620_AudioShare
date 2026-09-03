# AS_202620_AudioShare

Plataforma para transmitir audio en tiempo real desde un dispositivo a
múltiples dispositivos conectados.

## Arranque

Requisitos: Node.js 20+.

Instala las dependencias una vez con `npm install`. Después, el **único
comando de arranque** del proyecto es:

```bash
npm run dev
```

El servidor queda disponible en `http://localhost:3000`.

## Pruebas

```bash
npm test
```

La prueba `tests/a01.test.ts` recorre el corte vertical A-01 desde la API,
pasa por `Session`, persiste la sala y sus participantes, ejecuta
`SyncCoordinator` y genera un `audio.chunk`.

## Arquitectura

AudioShare utiliza un **monolito modular**. La decisión está documentada en
[`docs/adr/0001-usar-monolito-modular.md`](docs/adr/0001-usar-monolito-modular.md).

```text
src/
  app.ts
  server.ts
  shared/
  modules/
    session/   salas, participantes y persistencia
    audio/     paquetes de audio
    sync/      eventos de sincronización

tests/
  health.test.ts
  a01.test.ts
```

## Corte vertical A-01

```text
HTTP /rooms
    ↓
SessionManager
    ↓
RoomRepository
    ↓
data/rooms.json
    ↓
HTTP /rooms/:roomId/play
    ↓
SyncCoordinator → sync.start
    ↓
HTTP /rooms/:roomId/audio
    ↓
AudioStreamHub → audio.chunk
```

La captura de audio físico y la reproducción real en dispositivos quedan
fuera de este corte; el recorrido demuestra la integración ejecutable de la
lógica de sesión, persistencia, sincronización y representación del flujo de
audio.

## CI

GitHub Actions ejecuta `npm test` automáticamente en cada push y pull
request. El estado verde del workflow constituye la evidencia de ejecución
automática de las pruebas.

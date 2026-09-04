# AS_202620_AudioShare

Plataforma para transmitir audio en tiempo real desde un dispositivo a
múltiples dispositivos conectados.

## Qué busca el proyecto

AudioShare busca que un dispositivo emisor cree una sala y comparta audio
sincronizado con varios receptores en la misma red Wi-Fi. El primer corte
vertical demostrable es A-01: crear la sala, registrar receptores, iniciar la
reproducción con una referencia temporal común y distribuir paquetes de audio.
La sala queda persistida para que el flujo no dependa de una única instancia
del proceso.

## Cómo arrancar

Requisitos: Node.js 20+.

Instala las dependencias una vez con `npm install`. Después, el **único
comando de arranque** del proyecto es:

```bash
npm run dev
```

El servidor queda disponible en `http://localhost:3000`.

```bash
curl http://localhost:3000/health
```

También puedes abrir `http://localhost:3000/` en el navegador para ver el
propósito de AudioShare y sus endpoints principales.

La raíz sirve el dashboard de demostración A-01. Sus controles consumen la API
real: `POST /rooms`, `POST /rooms/:roomId/receivers`, `GET /rooms/:roomId`,
`POST /rooms/:roomId/play` y `POST /rooms/:roomId/pause`. La pantalla vuelve a
consultar la sala después de cada operación para mostrar el estado persistido
en SQLite.

## Cómo probar

```bash
npm test
```

La prueba `tests/a01.test.ts` recorre el corte vertical A-01 desde la API,
pasa por `Session`, persiste la sala y sus participantes, ejecuta
`SyncCoordinator` y genera un `audio.chunk`.

La verificación completa, usada también por la integración continua, es:

```bash
npm run verify
```

La persistencia usa SQLite en `data/audioshare.sqlite` por defecto y se puede
cambiar con `DATABASE_FILE`.

## Estructura

## Arquitectura

AudioShare utiliza un **monolito modular**. La decisión está documentada en
[`docs/adr/0001-usar-monolito-modular.md`](docs/adr/0001-usar-monolito-modular.md).

```text
src/
  app.ts              composition root: ensambla los módulos y sus casos de uso
  server.ts           punto de entrada del proceso
  shared/             configuración transversal (único lugar que lee variables de entorno)
  modules/
    session/          dominio, casos de uso y persistencia SQLite de salas
    audio/             captura, empaquetado y transmisión del audio
    sync/               coordinación de reproducción entre receptores
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

El corte vertical A-01 está implementado y probado de extremo a extremo a
nivel HTTP, incluida la recuperación de una sala desde SQLite tras reabrir la
base. La captura de audio desde un dispositivo físico y su reproducción mediante
altavoces quedan fuera de este corte. La trazabilidad está en
[`docs/aspectos.md`](docs/aspectos.md).

## CI

GitHub Actions ejecuta `npm test` automáticamente en cada push y pull request.
El estado verde del workflow constituye la evidencia de ejecución automática de
las pruebas.

El corte vertical A-01 implementa un flujo básico de sincronización de
reproducción entre un emisor y múltiples receptores.

### Flujo implementado

1. El emisor crea una sala.
2. Se pueden agregar múltiples receptores.
3. Los receptores se registran en la sala.
4. El emisor puede iniciar la reproducción mediante `PLAY`.
5. El módulo `Sync` genera un `startAt` común.
6. El módulo `Audio` genera y distribuye paquetes de audio.
7. Se puede consultar el estado de la sala.
8. El estado de reproducción y `startAt` quedan persistidos en SQLite.

La petición atraviesa `app.ts`, `SessionApplication`, el puerto
`RoomRepository` y `SQLiteRoomRepository` antes de volver como respuesta HTTP.
El `audio.chunk` continúa siendo una representación simulada; la captura y
reproducción física de audio quedan fuera de este corte.

### Ejecución

Instalar dependencias:

```bash
npm install

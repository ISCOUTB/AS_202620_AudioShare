# AS_202620_AudioShare

Plataforma para transmitir audio en tiempo real desde un dispositivo a múltiples dispositivos conectados.

## Cómo arrancar

Requisitos: Node.js 20+.

```bash
npm install
npm run dev
```

Con eso el sistema queda escuchando en `http://localhost:3000` (configurable con `PORT`, ver `.env.example`). Para comprobar que arrancó:

```bash
curl http://localhost:3000/health
```

## Cómo probar

```bash
npm test
```

## Estructura

Arquitectura: **monolito modular** (ver [`docs/adr/0001-usar-monolito-modular.md`](docs/adr/0001-usar-monolito-modular.md) y [`docs/Matriz_Comparativa.md`](docs/Matriz_Comparativa.md)).

```
src/
  app.ts              composition root: ensambla los módulos, sin lógica de negocio
  server.ts           punto de entrada del proceso
  shared/             configuración transversal (único lugar que lee variables de entorno)
  modules/
    session/          salas y roles (emisor, receptor, moderador)
    audio/             captura, empaquetado y transmisión del audio
    sync/               coordinación de reproducción entre receptores
tests/
  health.test.ts       verifica que el esqueleto arranca y expone los tres módulos
docs/                  arc42, ADR, C4, aspectos y registro de uso de IA
```

Cada módulo expone su API pública únicamente a través de su `index.ts`. Ningún módulo importa archivos internos de otro módulo; si dos módulos necesitan comunicarse, ese cableado se decide en `src/app.ts` o se documenta en un ADR si implica una decisión estructural.

## Estado

Esqueleto ejecutable de la semana 3: aún sin lógica de negocio. La implementación de cada módulo se construye a partir de los aspectos declarados en [`docs/aspectos.md`](docs/aspectos.md).

## Corte vertical A-01 — Sincronización de reproducción de audio

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

### Ejecución

Instalar dependencias:

```bash
npm install
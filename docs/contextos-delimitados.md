# Contextos delimitados

AudioShare se organiza como un monolito modular compuesto por tres contextos
delimitados principales: **Session, Sync y Audio**. Cada contexto tiene una
responsabilidad específica y es responsable de los datos relacionados con su
funcionalidad.

## 1. Contexto Session

El contexto **Session** se encarga de la gestión de las salas y de los
dispositivos participantes en una sesión de AudioShare.

### Responsabilidades

- Crear y gestionar salas.
- Registrar y consultar los dispositivos participantes.
- Mantener la información de la sesión.
- Gestionar la persistencia de los datos propios de las salas.

### Datos propios

- `roomId`
- Información de la sala.
- Participantes de la sala.
- Estado de la sesión.

---

## 2. Contexto Sync

El contexto **Sync** se encarga de coordinar la sincronización de la
reproducción de audio entre los dispositivos conectados a una misma sesión.

### Responsabilidades

- Coordinar el inicio sincronizado de la reproducción.
- Generar la referencia temporal `startAt`.
- Generar y gestionar los eventos de sincronización.
- Coordinar la información necesaria para que los receptores comiencen
  la reproducción al mismo tiempo.

### Datos propios

- `startAt`
- Información temporal de sincronización.
- Eventos `sync.start`.

---

## 3. Contexto Audio

El contexto **Audio** se encarga del manejo y distribución de los datos de
audio que serán recibidos por los dispositivos participantes.

### Responsabilidades

- Gestionar los datos de audio.
- Procesar y distribuir los paquetes de audio.
- Generar y gestionar los mensajes relacionados con la transmisión de audio.

### Datos propios

- Paquetes de audio.
- Datos relacionados con el flujo de audio.
- Eventos `audio.chunk`.

---

## Mapa de contextos

```text
                         AudioShare
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
          ▼                  ▼                  ▼
     ┌──────────┐       ┌──────────┐       ┌──────────┐
     │ Session  │       │   Sync   │       │  Audio   │
     ├──────────┤       ├──────────┤       ├──────────┤
     │ Salas    │       │startAt   │       │ Audio    │
     │Particip. │──────►│sync.start│──────►│ chunks   │
     │ Sesiones │       │          │       │Streaming │
     └──────────┘       └──────────┘       └──────────┘

     Gestión de          Sincronización       Transmisión
       sesiones          de reproducción       de audio

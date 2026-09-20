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
```

## Relaciones tipificadas

`app.ts` es el composition root: instancia `SessionApplication`,
`SyncCoordinator` y `AudioStreamHub` y orquesta las llamadas entre ellos en
cada endpoint. Ningún módulo importa tipos de otro módulo directamente (una
auditoría sobre el código — ver
[`docs/auditoria-propiedad-datos.md`](./auditoria-propiedad-datos.md) — solo
encuentra imports relativos dentro del propio módulo `session`), así que a
nivel de tipos los tres contextos están desacoplados. La tipificación de
cada relación, con el vocabulario de context mapping (DDD), es la siguiente:

### `app.ts` → Session, `app.ts` → Sync, `app.ts` → Audio: **Cliente-Proveedor (Customer-Supplier)**

Cada módulo expone una API pública propia (`SessionApplication`,
`SyncCoordinator`, `AudioStreamHub`) que `app.ts` consume sin tocar sus
internos (SQLite en el caso de Session, contadores en memoria en Sync y
Audio). Cada módulo es el proveedor (upstream) de su propio comportamiento;
`app.ts`, como cliente (downstream), decide cuándo y en qué orden invocar a
cada uno. Es una relación sana: el acoplamiento es solo a través de la
interfaz pública de cada clase.

### Session ↔ Sync: **Núcleo compartido (Shared Kernel) no intencional — anomalía**

Este es el caso que no debería existir tal como está. La tabla `rooms` de
`SQLiteRoomRepository` (módulo **Session**) tiene columnas `status`,
`playback_state` y `start_at` — exactamente los datos que
`docs/contextos-delimitados.md` (sección 2, arriba) declara como propios de
**Sync**. `SessionApplication.startPlayback()` y `.pausePlayback()` reciben
ese dato desde `app.ts` (que lo obtuvo de un `SyncCoordinator` efímero,
creado por request) y lo persisten como si fuera su propio modelo. No hay
traducción ni contrato entre los dos: Session simplemente guarda una copia
del estado de Sync en su propia tabla.

Esto no es un Shared Kernel deliberado (que exigiría que ambos módulos
acuerden y versionen conjuntamente ese subconjunto del modelo) — es una
violación de propiedad de datos que se declara como no conformidad en
[`docs/no_conformidades.md`](./no_conformidades.md) (NC-10). La relación
objetivo, una vez corregida, debería ser **Cliente-Proveedor**: Sync como
proveedor (dueño de `startAt` y del estado de reproducción), Session como
cliente que solo guarda una referencia (`roomId`, `syncSessionId`) sin
duplicar el modelo de Sync.

### Session ↔ Audio: **Vías separadas (Separate Ways)**

No hay import de tipos entre `session` y `audio`, ni persistencia
compartida: `AudioStreamHub` es puramente transitorio (contador en memoria
por sala) y `app.ts` solo pasa el `AudioChunk` ya construido a los
`streams` de la sala. Los dos contextos evolucionan de forma
independiente.

### Contrato hacia el cliente móvil: **Lenguaje Publicado (Published Language)**

`docs/contracts/openapi.yaml` y `docs/contracts/asyncapi.yaml`
(ver [ADR-0002](./adr/0002-estrategia-integracion.md)) formalizan el
formato de intercambio entre el backend y cualquier consumidor externo
(hoy el cliente HTML de `public/`, luego el cliente Flutter). Es un
lenguaje publicado porque su forma no depende del modelo interno de
ningún módulo — es el contrato que consumidores externos pueden validar
sin conocer la implementación.
# Auditoría de propiedad de datos

Recorrido realizado sobre el estado del repositorio en el commit:

```
4a0eba994357cba432178075dd872e0b52643595 (2026-09-13 22:01:57 -0500)
"Revise documentation for week 6 updates"
```

Objetivo: confirmar, contra el código real (no solo contra la
documentación), qué módulo escribe cada dato y si esa escritura coincide
con la propiedad declarada en
[`docs/modulos_datos.md`](./modulos_datos.md) y
[`docs/contextos-delimitados.md`](./contextos-delimitados.md).

## 1. Dónde ocurren las escrituras de persistencia

```bash
grep -rn "INSERT INTO\|UPDATE \|\.run(\|\.exec(" src/modules --include="*.ts"
```

Salida:

```
src/modules/session/infrastructure/persistence/sqlite-room-repository.ts:35:    this.database.exec(`
src/modules/session/infrastructure/persistence/sqlite-room-repository.ts:73:          "INSERT INTO rooms (id, created_at, status, playback_state, start_at) VALUES (?, ?, ?, ?, ?)",
src/modules/session/infrastructure/persistence/sqlite-room-repository.ts:75:        .run(
src/modules/session/infrastructure/persistence/sqlite-room-repository.ts:139:        "UPDATE rooms SET status = ?, playback_state = ?, start_at = ? WHERE id = ?",
src/modules/session/infrastructure/persistence/sqlite-room-repository.ts:141:      .run(status, JSON.stringify(playbackState), startAt, roomId);
src/modules/session/infrastructure/persistence/sqlite-room-repository.ts:157:        "INSERT INTO participants (id, room_id, role, joined_at) VALUES (?, ?, ?, ?)",
src/modules/session/infrastructure/persistence/sqlite-room-repository.ts:159:      .run(participant.id, roomId, participant.role, participant.joinedAt);
```

**Hallazgo:** la única clase que escribe a persistencia en todo el
proyecto es `SQLiteRoomRepository`, dentro del módulo **Session**. Los
módulos `audio` y `sync` no tienen infraestructura de persistencia propia
(confirmado en el punto 3).

## 2. Qué columnas escribe esa única fuente de escrituras

De la sentencia `UPDATE rooms SET status = ?, playback_state = ?, start_at
= ? WHERE id = ?` (línea 139-141 de
`sqlite-room-repository.ts`): las columnas escritas son `status`,
`playback_state` y `start_at`.

Contraste contra `docs/contextos-delimitados.md`:

| Columna escrita por Session | Contexto que la declara como propia |
|---|---|
| `start_at` | **Sync** ("Datos propios: `startAt`") |
| `playback_state` / `status` | **Sync** (estado de reproducción es resultado de coordinar la sincronización) |

**Conclusión:** Session escribe y es dueña de facto de datos que la propia
documentación del proyecto asigna a Sync. Esto se declara como NC-10 en
[`docs/no_conformidades.md`](./no_conformidades.md).

## 3. Dependencias de tipos entre módulos

```bash
grep -rn "from \"\.\./\|from \"\.\./\.\./" src/modules --include="*.ts"
```

Salida:

```
src/modules/session/infrastructure/persistence/sqlite-room-repository.ts:11:} from "../../domain/models.js";
src/modules/session/infrastructure/persistence/sqlite-room-repository.ts:12:import type { RoomRepository } from "../../application/room-repository.js";
src/modules/session/application/session-application.ts:1:import type { Participant, Room } from "../domain/models.js";
src/modules/session/application/room-repository.ts:6:} from "../domain/models.js";
```

**Hallazgo:** todos los imports relativos que cruzan carpetas son
*internos* al propio módulo `session` (de `application/` o
`infrastructure/` hacia `domain/`, dentro de `session`). Ningún archivo de
`audio` o `sync` importa tipos de otro módulo, y ningún archivo de
`session` importa tipos de `audio` o `sync`. A nivel de tipos, los tres
contextos están desacoplados — el acoplamiento real ocurre solo en tiempo
de ejecución, a través de `app.ts` (ver punto 4) y de las columnas
compartidas descritas en el punto 2.

## 4. Cómo se junta todo: `app.ts` como composition root

En `src/app.ts`, el endpoint `POST /rooms/:roomId/play` crea un
`SyncCoordinator` nuevo por request, le pide `sync.start()` (que calcula
`startAt` internamente, sin persistencia propia), y pasa ese `startAt` a
`sessions.startPlayback(roomId, event.startAt)` — que es quien finalmente
lo persiste en la tabla `rooms` de Session. Sync nunca vuelve a ver ese
valor después de generarlo: no hay una fuente de verdad de Sync a la que
Session esté sincronizada, hay una única escritura que ocurre en la tabla
de Session.

## Resumen para la planilla

- Única fuente de escrituras de persistencia: `SQLiteRoomRepository`
  (módulo Session).
- Datos ajenos que persiste: `start_at`, `playback_state`, `status`
  (propiedad de Sync según la documentación del propio proyecto).
- Sin imports cruzados de tipos entre módulos — el acoplamiento es de
  datos, no de código.
- No conformidad declarada: NC-10 en `docs/no_conformidades.md`.
- Relación tipificada en `docs/contextos-delimitados.md`, sección
  "Relaciones tipificadas" → Session ↔ Sync: Núcleo Compartido no
  intencional (anomalía a corregir).

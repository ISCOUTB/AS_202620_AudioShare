| Módulo             | Datos que posee                                                                              | Operaciones principales                             | Dueño único                  |
| ------------------ | -------------------------------------------------------------------------------------------- | --------------------------------------------------- | ---------------------------- |
| **Session**        | `roomId`, nombre/código de sala, participantes, rol del participante, estado de reproducción | Crear sala, agregar receptor, consultar sala        | **Session**                  |
| **Sync**           | `startAt`, eventos `sync.start`, coordinación de reproducción                                | Iniciar sincronización, generar referencia temporal | **Sync**                     |
| **Audio**          | `audio.chunk`, secuencia de paquetes, datos de transmisión                                   | Generar y distribuir paquetes de audio              | **Audio**                    |
| **Persistencia**   | Representación persistente de `rooms` y `participants`                                       | Guardar/recuperar información                       | **Session → RoomRepository** |
| **API / `app.ts`** | No posee datos de dominio                                                                    | Recibir HTTP y delegar                              | **Ninguno**                  |


# Privacidad

Elaborado el 2026-11-01. Describe qué datos trata AudioShare hoy, dónde
quedan, quién puede verlos y qué falta para tratarlos de forma responsable.
Todo lo que dice «hoy» sale de leer el código; lo que dice «propuesta» es una
decisión que el equipo todavía tiene que tomar. Este documento no es asesoría
legal.

## Resumen

- AudioShare **no pide cuenta, correo, teléfono ni nombre real**. Los
  participantes se identifican con un identificador que genera la aplicación
  (`emisor-xxxxxx`, `receptor-xxxxxx`) y que la persona puede cambiar a mano.
- Lo único de contenido personal es la **pista MP3 que sube el emisor**, que
  puede tener derechos de autor o ser una grabación propia.
- **Hoy no existe una forma de borrar una sala, una pista ni un participante**,
  y cualquiera que conozca el código de una sala puede descargar su pista
  (AM-01, AM-02 y AM-11 en [`amenazas-priorizadas.md`](./amenazas-priorizadas.md)).
  Es la brecha de privacidad más importante.

## Datos que se tratan

| Dato | Origen | Dónde queda | Quién puede verlo hoy | Retención hoy |
| --- | --- | --- | --- | --- |
| Identificador de participante (`emitterId`, `receiverId`) y rol | Lo genera la app o lo escribe la persona | SQLite, tabla `participants` (`data/audioshare.sqlite`) | Cualquiera que conozca el `roomId` (`GET /rooms/:id`) y, por `GET /rooms`, **cualquiera** sin credenciales | Indefinida |
| Fecha y hora de unión (`joined_at`) y de creación de la sala | El servidor | SQLite | Igual que el anterior | Indefinida |
| Estado de reproducción (`status`, `startAt`, posición) | El servidor | SQLite, tabla `rooms` | Igual | Indefinida |
| Pista MP3 | El emisor la elige y la sube | `data/tracks/<roomId>.mp3` en el volumen; copia temporal en cada receptor | Cualquiera que conozca el `roomId` (`GET /rooms/:id/track`) | Indefinida en el servidor; en el cliente, la copia temporal se borra con `deleteLocalTrack` al cambiar o liberar la pista |
| Desfase de reloj y ACK (`offsetMs`, `startedAt`, `deviationMs`) | El receptor | Memoria del proceso | Quien consulte `GET /rooms/:id/sync` | Hasta reiniciar el servicio |
| Registros del servidor | El servidor | Salida estándar (JSON): `roomId`, `emitterId`, `receiverId`, `startAt`, `deviationMs` | Quien administre Dokploy | Según la plataforma; no se verificó |
| Métricas agregadas (`/metrics`) | El servidor | Memoria | Cualquiera (el endpoint es público) | Hasta reiniciar |

### Lo que la aplicación no hace

- No usa cookies, almacenamiento local del navegador, analítica ni
  publicidad (no hay dependencias de ese tipo en `pubspec.yaml` y
  `public/app.js` no las usa).
- El manifiesto de Android solicita únicamente el permiso `INTERNET`. No pide
  micrófono, ubicación, contactos ni almacenamiento general; el selector de
  archivos accede solo al MP3 que la persona elige.
- La aplicación no registra direcciones IP. **Esto no cubre al proxy** de
  Dokploy/Traefik, que sí podría guardarlas; no se verificó su configuración.
- SonarCloud y GitHub reciben el código del repositorio, no datos de usuarios.

## Riesgos de privacidad

1. **Datos personales por elección de la persona.** El campo del identificador
   es libre: alguien puede escribir su nombre. Como `GET /rooms` lista los
   participantes de todas las salas, ese nombre queda expuesto a cualquiera.
2. **Contenido con derechos de autor o grabaciones propias** accesibles sin
   autenticación mientras la sala exista.
3. **Retención sin fin:** las salas y las pistas solo desaparecen si se borra
   el volumen.
4. **Sin forma de ejercer derechos:** no hay mecanismo para que una persona
   pida ver, corregir o borrar lo que se guardó sobre ella o su pista.
5. **Los registros contienen identificadores** (`emitterId`, `receiverId`) y
   no tienen política de conservación documentada.

## Principios que adopta el equipo

| Principio | Cómo se aplica en AudioShare |
| --- | --- |
| Minimización | Sin cuentas ni datos de contacto; identificadores aleatorios por defecto; no registrar IP en la aplicación. |
| Finalidad | Los datos sirven solo para coordinar la reproducción de la sala. No se usan para analítica ni se comparten con terceros. |
| Transparencia | Aviso corto en la pantalla de inicio y en el README (texto propuesto más abajo). |
| Limitación de la conservación | Caducidad de salas y pistas (propuesta abajo). |
| Seguridad | Token de emisor y de receptor, HTTPS, límites (AM-01, AM-03, AM-04, AM-06). |
| Acceso y supresión | `DELETE /rooms/:roomId` autenticado con el token de emisor (AM-11). |

## Retención propuesta

Valores de partida para discutir; el equipo los fija y los registra en un ADR.

| Dato | Propuesta | Cómo se implementa |
| --- | --- | --- |
| Pista MP3 en el servidor | Se borra al cerrar la sala o tras un periodo corto sin actividad | Tarea periódica en el módulo Audio y borrado en `DELETE /rooms/:roomId` |
| Sala y participantes | Se borran tras un periodo sin actividad más largo que el de la pista | Tarea periódica en Session; `ON DELETE CASCADE` ya borra los participantes |
| Registros del servidor | Conservación acotada, sin datos personales adicionales | Configurar la rotación en Dokploy |
| Copia temporal en el dispositivo | Se borra al terminar o cambiar de pista | Ya implementado (`deleteLocalTrack`) |

## Marco legal

El proyecto se desarrolla en Colombia (la interfaz usa `es-CO`). La norma
general de protección de datos personales es la **Ley 1581 de 2012**, con su
reglamentación. Que aplique a un prototipo académico sin cuentas y con
identificadores aleatorios es discutible; el riesgo aparece cuando una persona
escribe su nombre o sube una grabación propia. Antes de abrir el sistema a
usuarios fuera del curso conviene confirmar con el docente cómo se
interpreta el alcance y qué aviso de privacidad corresponde.

## Aviso de privacidad (texto propuesto)

> AudioShare no te pide cuenta ni datos de contacto. Para coordinar la sala se
> guarda un identificador de dispositivo (generado al azar, puedes cambiarlo;
> no escribas tu nombre real), el rol y la hora en que entraste. Si eres el
> emisor, también se guarda en el servidor el MP3 que subas, y lo descargan los
> receptores de tu sala. Los datos se usan solo para sincronizar la
> reproducción, no se comparten con terceros y se borran cuando la sala
> caduca. No subas contenido sobre el que no tengas derechos.

## Pendiente

- Decidir los plazos de retención y registrarlos en un ADR.
- Implementar `DELETE /rooms/:roomId`, la caducidad y la protección de
  `GET .../track` (depende de AM-01).
- Definir un canal de contacto del equipo para solicitudes de borrado y
  añadirlo al README.
- Revisar la retención de registros y de IP en el proxy de Dokploy.
- Mostrar el aviso de privacidad en la pantalla de inicio de la app.

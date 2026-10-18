# Uso de Inteligencia Artificial

## Propósito

Durante el desarrollo de AudioShare se utilizarán herramientas de
Inteligencia Artificial como apoyo para la investigación, diseño,
desarrollo y documentación del proyecto.

La IA será utilizada como una herramienta de apoyo y no como reemplazo
del análisis y las decisiones tomadas por los integrantes del equipo.

## Usos realizados de la IA

Durante las primeras etapas del proyecto, la Inteligencia Artificial
ha sido utilizada como apoyo en las siguientes actividades:

* Generación y evaluación de ideas para el proyecto de Arquitectura de
  Software.
* Apoyo en la definición y redacción del problema de AudioShare.
* Apoyo en la estructuración de la documentación utilizando el enfoque
  arc42.
* Revisión y formulación de restricciones arquitectónicas justificadas.
* Identificación y priorización de atributos de calidad para el árbol
  de utilidad.
* Propuesta de escenarios de calidad y métricas para su evaluación.
* Apoyo en la elaboración del diagrama C4 de contexto.
* Generación y revisión del código Mermaid utilizado como fuente del
  diagrama C4.
* Revisión de la organización de los archivos de documentación dentro
  del repositorio.
* Explicación de conceptos relacionados con arquitectura de software,
  C4 y arc42.
* Apoyo en la investigación y comparación de estilos arquitectónicos.
* Apoyo en la implementación y documentación del corte vertical A-01.
* Apoyo en el diseño y revisión de pruebas de integración.
* Revisión cruzada de la documentación del repositorio contra la Guía
  del curso y el feedback recibido, previa al corte 1.
* Apoyo en la elaboración del mapa de contextos de AudioShare,
  identificando los principales contextos del sistema y sus relaciones.
* Apoyo en la identificación de las responsabilidades de los módulos
  `Session`, `Sync` y `Audio`.
* Apoyo en la elaboración de la tabla módulo → datos, identificando los
  datos manejados por cada módulo y estableciendo un dueño único para
  cada dato.
* Revisión de la separación de responsabilidades entre los módulos para
  evitar que diferentes módulos sean responsables del mismo dato.
* Apoyo en la identificación de errores y no conformidades presentes en
  el estado actual del proyecto.
* Apoyo en la clasificación de las no conformidades según su impacto y
  prioridad de corrección.
* Apoyo en la elaboración del plan de corrección de las no conformidades
  detectadas.
* Revisión de la diferencia entre funcionalidades actualmente
  implementadas, funcionalidades simuladas y funcionalidades pendientes
  del prototipo.
* Apoyo en la organización de los nuevos documentos de arquitectura
  dentro del directorio `docs/`.
* Revisión de la coherencia entre la documentación de arquitectura y la
  estructura actual de los módulos del código.

## Herramientas utilizadas

* ChatGPT.
* Claude (Anthropic), usado en la revisión previa al corte 1 para
  contrastar la documentación del repositorio contra la Guía del curso
  y el historial de feedback, y en la semana 10 (2026-10-12) para
  contrastar el repositorio con el feedback de S9 y S10 y apoyar la
  corrección de reloj, el ACK de arranque y la recuperación de la capa
  `data/` del cliente Flutter.
  Después del cierre de S10 se usó de nuevo para contrastar el feedback
  vigente con el repositorio y proponer correcciones documentales (C4 nivel 2,
  trazabilidad del ADR-0009, este registro).
* GitHub Copilot, utilizado durante la semana 7 como herramienta de
  apoyo para la migración del prototipo web de AudioShare hacia una
  aplicación desarrollada con Flutter.

Otras herramientas de Inteligencia Artificial podrán utilizarse durante
las siguientes etapas cuando sean necesarias.

## Verificación de resultados

Las respuestas, propuestas y contenido generado mediante Inteligencia
Artificial serán revisados por los integrantes del equipo antes de ser
incorporados al proyecto.

El equipo será responsable de comprobar que las propuestas sean
correctas, coherentes con el problema de AudioShare y compatibles con
los requisitos y restricciones definidos.

Las decisiones arquitectónicas finales serán tomadas por los integrantes
del equipo y no por la herramienta de Inteligencia Artificial.

## Registro del uso de IA

| Etapa | Uso | Propósito | Resultado | Propuesta de IA rechazada y motivo |
| --- | --- | --- | --- | --- |
| Semana 1 | Generación y evaluación de ideas | Explorar posibles proyectos para la asignatura | Se seleccionó AudioShare como propuesta de proyecto | Se descartaron ideas que no permitían evidenciar adecuadamente decisiones de arquitectura y atributos de calidad. Se priorizó AudioShare por permitir trabajar sincronización, comunicación entre clientes y restricciones de rendimiento. |
| Semana 1 | Redacción y revisión | Estructurar la ficha del problema | Se definió el problema y el prototipo de AudioShare | Se rechazaron formulaciones demasiado generales que no identificaban claramente a los usuarios ni las necesidades del sistema. Se ajustó el problema para delimitar el alcance del prototipo. |
| Semana 2 | arc42 | Apoyar la organización de las secciones 1–3 | Se estructuró la documentación inicial de arquitectura | Se descartaron explicaciones que agregaban contenido no requerido para el alcance de la entrega. Se mantuvieron únicamente las secciones y decisiones relevantes para AudioShare. |
| Semana 2 | Requisitos de calidad | Identificar atributos y escenarios medibles | Se propusieron objetivos de calidad y métricas | Se rechazaron atributos o escenarios demasiado generales o difíciles de medir. Se priorizaron escenarios relacionados con rendimiento, disponibilidad/confiabilidad y usabilidad. |
| Semana 2 | C4 | Elaborar el diagrama de contexto | Se generó el código Mermaid y la imagen del C4 de contexto | Se rechazaron elementos que pertenecían a niveles inferiores de C4 y no al contexto. El diagrama se limitó al sistema AudioShare, sus usuarios y sistemas externos relevantes. |
| Semana 2 | Documentación | Revisar la organización de los documentos | Se estructuró la documentación dentro del repositorio | Se descartaron estructuras de carpetas innecesariamente complejas para el alcance actual del proyecto. Se mantuvo una organización compatible con arc42, ADR, C4 y los documentos solicitados. |
| Semana 3 | Consulta | Investigación de los estilos arquitectónicos | Se generó la matriz comparativa | Se rechazó una comparación basada únicamente en ventajas y desventajas generales. Se decidió relacionar cada estilo directamente con los escenarios EC-01 a EC-04 del árbol de utilidad. |
| Semana 4 | Corte vertical A-01 | Apoyar la implementación del corte vertical ejecutable de sincronización de reproducción de audio | Se implementó el flujo de creación de salas, incorporación de receptores, sincronización mediante `startAt` y generación de eventos `audio.chunk` | Se descartaron propuestas que ampliaban el alcance del corte vertical con funcionalidades no necesarias para demostrar la sincronización. Se mantuvo el flujo mínimo necesario para validar A-01. |
| Semana 4 | Pruebas | Diseñar y revisar la prueba de integración del corte vertical A-01 | Se creó `tests/a01.test.ts`, verificando la creación de una sala, dos receptores, la operación `PLAY` y la generación de eventos de sincronización y audio | Se rechazaron pruebas que verificaban únicamente funciones aisladas. Se priorizó una prueba de integración que recorriera el flujo completo del corte vertical. |
| Semana 4 | Documentación técnica | Actualizar el README y la documentación del aspecto A-01 | Se documentaron la implementación, el flujo de ejecución y las pruebas realizadas | Se descartó documentar funcionalidades que todavía no forman parte del corte vertical implementado. La documentación se limitó al comportamiento realmente disponible y verificable. |
| Semana 4 | Revisión y corrección | Analizar errores encontrados durante la ejecución de las pruebas | Se corrigió la prueba de integración hasta obtener 3 pruebas aprobadas en 2 archivos | Se rechazaron correcciones que modificaban el comportamiento esperado del sistema únicamente para hacer pasar las pruebas. Se corrigió la implementación o la prueba según el comportamiento definido. |
| Semana 4 | Corrección de matriz comparativa | Comparar escenarios de utilidad por cada fila | Se rehízo la matriz con los escenarios propuestos | Se rechazó la versión anterior porque comparaba los estilos arquitectónicos mediante criterios generales y no mostraba claramente el impacto sobre cada escenario del árbol de utilidad. La nueva matriz utiliza EC-01 a EC-04 como filas y especifica qué mejora y qué empeora con cada estilo. |
| Semana 4 | Persistencia del corte vertical | Incorporar persistencia real al corte vertical A-01 | Se implementó `SQLiteRoomRepository` con tablas `rooms` y `participants`, y se extendió `tests/a01.test.ts` para verificar la recuperación de una sala tras reabrir la base de datos | Se rechazó mantener el estado únicamente en memoria del proceso, porque no permitía demostrar persistencia real ni sobrevivir a un reinicio del servidor. También se rechazó introducir un motor de base de datos externo (por ejemplo PostgreSQL) por añadir una dependencia de infraestructura innecesaria para el alcance actual del prototipo. |
| Semana 4 | Corrección del C4 Nivel 2 | Alinear el diagrama de contenedores con el código real | Se rehízo `C4 Nivel 2 - Contenedores.mmd` para mostrar el cliente web, el servidor de aplicación y la base SQLite reales | Se rechazó la versión anterior del diagrama, que mostraba un Frontend SPA, un servicio de Discovery, un servidor de Signaling y un Media Engine que nunca se implementaron. Se descartó mantenerlos como "plan futuro" dentro del mismo diagrama para no mezclar lo implementado con lo especulativo; ese contenido se dejará para una futura actualización del diagrama cuando exista código real que lo respalde. |
| Semana 5 | Revisión pre-corte 1 | Contrastar `docs/aspectos.md`, `docs/ia.md`, arc42 y el ADR contra la Guía del curso y el feedback recibido en semanas 1 a 4 | Se identificó que `docs/aspectos.md` contenía dos tablas de trazabilidad casi idénticas, una de ellas con un enlace roto al diagrama C4 Nivel 2 (`Contenedor - Nivel 2.mmd`, un nombre de archivo que ya no existe) | Se rechazó conservar ambas tablas "por si acaso": se consolidaron en una sola tabla, usando las columnas y el nivel de detalle de la más completa, y se corrigió la ruta del enlace al nombre real del archivo (`C4 Nivel 2 - Contenedores.mmd`). También se rechazó reescribir el resto del documento desde cero: se conservó el contenido ya aceptado en semanas anteriores (descripción, requisitos, implementación, pruebas) sin modificarlo. |
| Semana 6 | Mapa de contextos | Apoyar la identificación y organización de los principales contextos del sistema AudioShare y sus relaciones | Se elaboró el mapa de contextos para representar de forma clara los límites y relaciones entre los contextos principales del sistema | Se rechazó incluir elementos que no correspondían al alcance actual de AudioShare o que representaban detalles internos que debían documentarse en niveles inferiores de arquitectura. |
| Semana 6 | Módulo → datos | Identificar qué datos son responsabilidad de cada módulo y establecer un dueño único para cada dato | Se elaboró la tabla módulo → datos, relacionando `Session`, `Sync`, `Audio` y persistencia con los datos que manejan y sus responsabilidades | Se rechazó una distribución en la que varios módulos fueran responsables de modificar directamente el mismo dato. Se estableció un único dueño por dato para mejorar la separación de responsabilidades. |
| Semana 6 | Separación de responsabilidades | Revisar que las responsabilidades de los módulos sean coherentes con la arquitectura de Monolito Modular | Se revisó la responsabilidad de los módulos `Session`, `Sync` y `Audio`, evitando duplicidad en el manejo de datos | Se rechazó asignar responsabilidades de persistencia, sincronización y transmisión de audio de forma indistinta entre módulos. Cada módulo mantiene una responsabilidad específica y se comunica mediante sus interfaces. |
| Semana 6 | No conformidades | Identificar errores, funcionalidades pendientes y diferencias entre el estado actual del prototipo y el comportamiento esperado | Se elaboró una lista de no conformidades identificando aspectos como audio simulado, reproducción física pendiente, validación de sincronización, pausa/reanudación, incorporación de nuevos receptores y medición de latencia | Se rechazó considerar como completamente implementadas funcionalidades que actualmente solo están simuladas o documentadas. Se diferenciaron las funcionalidades implementadas de las pendientes. |
| Semana 6 | Plan de corrección | Organizar las acciones necesarias para resolver las no conformidades detectadas | Se elaboró un plan de corrección con prioridad para transmisión de audio real, reproducción en receptores, validación de sincronización, pausa/reanudación, nuevos receptores y métricas de latencia | Se rechazó intentar corregir todas las no conformidades simultáneamente. Se estableció un orden de corrección basado en dependencias e impacto sobre el funcionamiento del sistema. |
| Semana 6 | Organización de documentación | Definir la ubicación de los nuevos documentos relacionados con el análisis arquitectónico | Se organizaron los documentos `docs/mapa_contextos.md`, `docs/modulos_datos.md` y `docs/no_conformidades.md` dentro del directorio `docs/` | Se rechazó colocar estos documentos fuera de la estructura de documentación existente, manteniendo la organización del repositorio y la trazabilidad de la arquitectura. |
| Semana 8 | Implementación y validación de A-01 — Sincronización de reproducción de audio | Diseño de prueba, revisión de código y documentación arquitectónica | Crear una prueba para validar EC-01 mediante `startAt` y comprobar que la diferencia de inicio entre receptores sea ≤ 100 ms. También propuso documentar la decisión mediante un ADR y registrar la trazabilidad entre aspecto, código y prueba. | Aceptada parcialmente. El equipo decidió utilizar `startAt` como referencia temporal común y crear una prueba específica para EC-01. La decisión arquitectónica fue tomada por el equipo. | Se corrigieron propuestas que solamente comprobaban la existencia de `startAt`. La prueba se ajustó para medir la diferencia temporal entre receptores. También se revisó que `Sync`, `Audio` y `Session` mantuvieran sus responsabilidades y que no se cruzaran límites de contexto. | Se agregó evidencia para A-01: ADR, prueba automatizada, medición de EC-01 y revisión de erosión arquitectónica. |
| Semana 9 | Porción real de A-01 (sincronización inicial) con su cadena: prueba `tests/sync-a01.test.ts`, ADR-0005 y fila A-01 de `docs/aspectos.md`; decisión sobre el componente generativo (ADR-0006); verificación de dependencias y credenciales | Cumplir lo pedido para S9: porción real con cadena completa, extracto de este documento, auditoría de erosión, verificación de dependencias y credenciales, y decisión sobre un componente generativo | Entregado en el estado `6a03a97`: ADR-0005, ADR-0006 (no incorporar un componente generativo) y las secciones de auditoría y verificación de este documento. En ese estado la prueba solo comprobaba constantes y no había medición de receptores; ambas cosas se resolvieron en la semana 10 (`404947a`). La ubicación de cada elemento está en «Entregables de la semana 9». | Sin registro por propuesta; no se reconstruye de memoria. Lo que se comprobó después sobre el trabajo de esta semana está documentado en la semana 10. |
| Semana 10 (2026-10-12) | Revisión del feedback de S9 y S10 contra el repositorio, diseño e implementación de la corrección de reloj y del ACK de arranque, y reconstrucción de la capa `data/` del cliente Flutter (Claude) | Subsanar los hallazgos de S9 y S10: prueba sintética de EC-01, cadena A-01 incompleta, ADR con nombre fuera de convención y Flutter CI en rojo | Se implementaron `GET /time`, `POST /rooms/:roomId/receivers/:receiverId/ack` y `GET /rooms/:roomId/sync` (commit `404947a`), una prueba con receptores simulados verificada por mutación y el ADR-0007. Se versionó la capa `data/` del cliente (commit `1da287c`). CI, publicación de imagen y Flutter quedaron en verde. | Se rechazó conservar la prueba de constantes de EC-01 porque no ejercitaba el sistema, y se rechazó subir `pubspec.lock` y `analysis_options.yaml` regenerados por el Flutter local. Motivos en «Propuestas de IA rechazadas», semana 10. |
| Posterior al cierre de S10 | Contraste del feedback vigente (consolidación del 13 de octubre) con el repositorio y borrador de correcciones documentales (Claude) | Subsanar la deriva D1 (C4 nivel 2 sin Flutter), dejar alcanzable el ADR-0009 desde arc42 §9, `docs/aspectos.md` y los escenarios EC-01, EC-02 y EC-04, y registrar el uso de IA | Se actualizó `docs/c4/C4 Nivel 2 - Contenedores.mmd` con Flutter y el cliente web legado como alternativas, protocolo y formato en cada flecha, y los flujos NDJSON, `/time` y ACK de Flutter marcados como pendientes; se comprobó en `public/app.js` que el cliente web legado tampoco consume NDJSON, por lo que se corrigió la afirmación anterior del diagrama. Se enlazaron los ADR 0001 a 0009 en arc42 §9 y ADR-0009 en la fila A-01 y en los escenarios. No se ejecutaron pruebas ni se regeneró el PNG del C4. | **Por completar por el equipo:** este registro se redactó con apoyo de la IA y no incluye propuestas rechazadas. Aquí se anota qué propuesta se descartó y por qué; no se reconstruye de memoria. |


## Clasificación de propuestas de IA

Las propuestas generadas mediante herramientas de Inteligencia
Artificial fueron revisadas por los integrantes del equipo antes de
incorporarse al proyecto.

Para efectos de trazabilidad, las propuestas se clasifican en tres
categorías:

| Estado | Descripción |
| --- | --- |
| **Aceptada** | La propuesta fue revisada por el equipo y se incorporó al proyecto porque era compatible con los requisitos, restricciones y arquitectura definida. |
| **Corregida** | La propuesta contenía elementos útiles, pero necesitó modificaciones realizadas por el equipo antes de incorporarse. |
| **Rechazada** | La propuesta no fue incorporada porque no era necesaria, no correspondía al alcance, no respetaba las decisiones arquitectónicas o introducía complejidad innecesaria. |

### Ejemplos de propuestas aceptadas

- Propuestas para estructurar la documentación de arquitectura.
- Apoyo en la elaboración de escenarios de calidad.
- Apoyo en la elaboración y revisión de diagramas C4.
- Apoyo en la identificación de responsabilidades de los módulos.
- Apoyo en la migración del cliente hacia Flutter.

Estas propuestas fueron revisadas y adaptadas por el equipo antes de
su incorporación.

### Ejemplos de propuestas corregidas

Las propuestas relacionadas con la implementación y documentación no
se incorporaron automáticamente. Cuando la respuesta de la IA no
coincidía exactamente con la estructura actual del proyecto, los
integrantes del equipo modificaron el contenido antes de incorporarlo.

Durante la migración a Flutter, por ejemplo, las propuestas generadas
como apoyo fueron adaptadas a la estructura real del proyecto y a las
responsabilidades definidas para sus componentes.

### Ejemplos de propuestas rechazadas

Se rechazaron propuestas que:

- ampliaban innecesariamente el alcance del corte vertical;
- representaban funcionalidades que todavía no estaban implementadas;
- asignaban responsabilidades duplicadas a diferentes módulos;
- proponían componentes arquitectónicos que no estaban respaldados
  por código real;
- agregaban dependencias o infraestructura innecesaria;
- modificaban el comportamiento esperado únicamente para hacer pasar
  una prueba.

La decisión final de aceptar, corregir o rechazar una propuesta
corresponde al equipo y no a la herramienta de Inteligencia Artificial.


## Propuestas de IA rechazadas

* **Semana 1 — Ideas de proyecto:** se descartaron ideas que no permitían
  evidenciar adecuadamente decisiones de arquitectura y atributos de
  calidad. Se priorizó AudioShare por permitir trabajar sincronización,
  comunicación entre clientes y restricciones de rendimiento.
* **Semana 1 — Ficha del problema:** se rechazaron formulaciones demasiado
  generales que no identificaban claramente a los usuarios ni las
  necesidades del sistema. Se ajustó el problema para delimitar el
  alcance del prototipo.
* **Semana 2 — arc42 (secciones 1–3):** se descartaron explicaciones que
  agregaban contenido no requerido para el alcance de la entrega. Se
  mantuvieron únicamente las secciones y decisiones relevantes para
  AudioShare.
* **Semana 2 — Requisitos de calidad:** se rechazaron atributos o
  escenarios demasiado generales o difíciles de medir. Se priorizaron
  escenarios relacionados con rendimiento, disponibilidad/confiabilidad
  y usabilidad.
* **Semana 2 — C4 de contexto:** se rechazaron elementos que pertenecían
  a niveles inferiores de C4 y no al contexto. El diagrama se limitó al
  sistema AudioShare, sus usuarios y sistemas externos relevantes.
* **Semana 2 — Organización de la documentación:** se descartaron
  estructuras de carpetas innecesariamente complejas para el alcance
  actual del proyecto. Se mantuvo una organización compatible con arc42,
  ADR, C4 y los documentos solicitados.
* **Semana 3 — Estilos arquitectónicos:** se rechazó una comparación
  basada únicamente en ventajas y desventajas generales. Se decidió
  relacionar cada estilo directamente con los escenarios EC-01 a EC-04
  del árbol de utilidad.
* **Semana 4 — Alcance del corte vertical A-01:** se descartaron
  propuestas que ampliaban el alcance del corte vertical con
  funcionalidades no necesarias para demostrar la sincronización. Se
  mantuvo el flujo mínimo necesario para validar A-01.
* **Semana 4 — Pruebas del corte vertical:** se rechazaron pruebas que
  verificaban únicamente funciones aisladas. Se priorizó una prueba de
  integración que recorriera el flujo completo del corte vertical.
* **Semana 4 — Documentación técnica:** se descartó documentar
  funcionalidades que todavía no forman parte del corte vertical
  implementado. La documentación se limitó al comportamiento realmente
  disponible y verificable.
* **Semana 4 — Corrección de pruebas fallidas:** se rechazaron
  correcciones que modificaban el comportamiento esperado del sistema
  únicamente para hacer pasar las pruebas. Se corrigió la implementación
  o la prueba según el comportamiento definido.
* **Semana 4 — Matriz comparativa:** se rechazó la versión anterior
  porque comparaba los estilos arquitectónicos mediante criterios
  generales y no mostraba claramente el impacto sobre cada escenario del
  árbol de utilidad. La nueva matriz utiliza EC-01 a EC-04 como filas y
  especifica qué mejora y qué empeora con cada estilo.
* **Semana 6 — Mapa de contextos:** se rechazó incluir detalles de
  implementación dentro del mapa de contextos, ya que este debe
  representar los límites y relaciones de los contextos y no reemplazar
  los diagramas C4 ni la documentación de módulos.
* **Semana 6 — Módulo → datos:** se rechazó asignar el mismo dato a
  varios módulos como responsables directos. Se estableció el principio
  de dueño único para evitar responsabilidades duplicadas y facilitar el
  mantenimiento.
* **Semana 6 — No conformidades:** se rechazó presentar como errores
  únicamente los problemas de código. También se registraron
  funcionalidades pendientes o no validadas experimentalmente cuando
  afectan el cumplimiento de los requisitos y escenarios de calidad.
* **Semana 6 — Plan de corrección:** se rechazó un plan sin prioridades.
  Las correcciones se organizaron según su impacto y dependencia,
  comenzando por la transmisión y reproducción de audio antes de
  realizar las validaciones avanzadas de sincronización y latencia.
* **Semana 6 — Organización de documentación:** se rechazó colocar los
  nuevos documentos fuera de la estructura `docs/`, manteniendo la
  organización existente del proyecto y facilitando la trazabilidad de
  la arquitectura.

* **Semana 7 — Migración a Flutter:** se utilizó GitHub Copilot como
  herramienta de apoyo para transferir el prototipo de AudioShare desde
  su implementación web hacia una aplicación desarrollada con Flutter.
  Se rechazaron propuestas que trasladaban directamente la estructura
  del proyecto web sin considerar las diferencias entre ambas
  tecnologías. También se descartaron cambios que incorporaban
  funcionalidades nuevas durante la migración y que no eran necesarias
  para el alcance actual. La migración se enfocó en conservar las
  funcionalidades existentes y adaptar su implementación a la nueva
  tecnología. También se rechazó la redacción de Copilot a la hora de documentar.


* **Semana 9 — Sin registro por propuesta:** para esta semana se pedía
  el extracto de este documento con lo aceptado, lo corregido y lo
  rechazado con su motivo. No se llevó ese registro por propuesta, y el
  feedback de S9 lo señaló. No se reconstruyen rechazos de memoria. Lo
  que se pudo comprobar después sobre el trabajo de la semana está en la
  semana 10.
* **Semana 10 — Prueba de constantes de EC-01:** se rechazó conservar
  `tests/sync-a01.test.ts` tal como estaba, una prueba incorporada
  hacia el cierre de la semana 9 con apoyo de IA (ver la fila de la
  semana 8). Calculaba 40 ms a partir de 20, 35 y 60 sin importar
  ningún módulo del sistema, de modo que no podía fallar ante un
  defecto de sincronización. Se reemplazó por receptores simulados
  contra el servidor real y se verificó con una mutación: al hacer que
  `delayUntilStart` ignore el offset, la prueba falla
  (`expected 2984 to be less than or equal to 100`). Procedimiento en
  `docs/evidencia-a01-ec01.md`.

La decisión final sobre aceptar, modificar o rechazar una propuesta
corresponde al equipo.

## Auditoría de erosión

La generación asistida por Inteligencia Artificial fue revisada
considerando los límites de los contextos y las reglas de propiedad de
datos definidas para la arquitectura de AudioShare.

### Límites de contexto

Las propuestas generadas por IA fueron contrastadas con la separación
de responsabilidades definida para los módulos `Session`, `Sync` y
`Audio`.

La revisión buscó detectar propuestas que asignaran a un módulo
responsabilidades pertenecientes a otro contexto o que mezclaran
responsabilidades de presentación, sincronización, audio y
persistencia.

Cuando una propuesta no correspondía con los límites definidos, fue
corregida o rechazada antes de incorporarse al proyecto.

### Propiedad de datos

También se revisó que cada dato tuviera un responsable definido y que
los diferentes módulos no asumieran simultáneamente la responsabilidad
de modificar directamente el mismo dato.

Esta revisión se realizó utilizando como referencia la definición de
responsabilidades y la tabla módulo → datos del proyecto.

### Detección y corrección

La posible erosión se detectó mediante revisión manual de las
propuestas generadas por IA y su comparación con la arquitectura,
los límites de los módulos y la propiedad de los datos previamente
definidos.

Cuando una propuesta cruzaba un límite de responsabilidad, el equipo
la modificó para respetar la separación existente o la rechazó cuando
no era necesaria para el alcance del proyecto.

La decisión de incorporar una propuesta siempre fue tomada por los
integrantes del equipo.

### Hallazgos localizados (semana 10)

Revisión contra el código y contra `docs/modulos_datos.md`
(«API / `app.ts`: no posee datos de dominio»):

| # | Hallazgo | Ubicación | Límite o dato afectado | Estado |
| --- | --- | --- | --- | --- |
| 1 | El patrón `data/` del `.gitignore` ignoraba toda carpeta con ese nombre, incluida `lib/features/session/data/`. La capa de datos del cliente nunca se versionó y el Flutter CI falló por imports inexistentes desde el commit «Migrar AudioShare a Flutter» (`453710f`). | `.gitignore`, línea 9 | Capa de datos del cliente (`Room`, `RoomRepository`) del contexto Session | **Corregido** en `1da287c`: el patrón pasó a `/data/` y se agregó la capa, reconstruida a partir de sus usos y del contrato OpenAPI (no son los archivos originales). |
| 2 | Los handlers de `/play` y `/pause` creaban un `SyncCoordinator` nuevo en cada petición, por lo que el estado del contexto Sync se perdía entre llamadas. | `src/app.ts` (hasta `6a03a97`) | Estado de Sync | **Corregido** en `404947a`: un coordinador por sala. |
| 3 | `app.ts` mantiene estado de aplicación: los mapas `streams`, `coordinators` y `measurements`, y escribe en `metrics`. Esto contradice «API / `app.ts` no posee datos» y, además, `metrics.lastSyncSpreadMs` duplica fuera de Sync un dato que el ADR-0007 declara propiedad de `SyncMeasurements`. Los dos últimos mapas se añadieron en `404947a`, así que ese commit profundizó el desvío. | `src/app.ts`, `src/shared/metrics.ts` | Dueño único de `startAt`/arranques (Sync); `app.ts` sin datos | **Detectado, no corregido.** Propuesta: mover `coordinators` y `measurements` a una fachada del módulo Sync, mover `streams` al módulo que distribuye eventos, y exponer el desfase mediante una función de Sync que `/metrics` consulte, en lugar de que `app.ts` escriba el valor. |
| 4 | `start_at` está declarado como dato de Sync, pero lo persiste Session (`SessionApplication.startPlayback` recibe y guarda `startAt`). Ya figura en `docs/auditoria-propiedad-datos.md`. | `src/modules/session/application/session-application.ts` | `start_at` | **Sigue vigente, no corregido.** |

## Verificación de dependencias y credenciales

Como parte de la revisión del código generado o modificado con apoyo
de Inteligencia Artificial, se verificó que las dependencias utilizadas
por el proyecto correspondieran a dependencias existentes y
justificadas por la implementación.

### Dependencias

Las dependencias incorporadas al proyecto fueron contrastadas con los
archivos de configuración correspondientes antes de considerarlas
parte de la implementación.

Para cada dependencia se verificó:

- que el paquete exista;
- que corresponda con la tecnología utilizada;
- que esté declarado en el archivo de dependencias correspondiente;
- que sea necesario para la funcionalidad implementada;
- que no haya sido incorporado únicamente por una sugerencia de IA
  sin justificación técnica.

La incorporación final de una dependencia corresponde al equipo.

#### Inventario verificado (2026-10-12)

Método: `npm ls --depth=0` y `package-lock.json` para lo instalado,
`npm view <paquete> version` contra el registro oficial (npmjs.org) para
la última versión publicada, y `pubspec.lock` y la salida de
`flutter pub get` para Dart (pub.dev). Los commits `404947a` y `1da287c`
no modificaron `package.json` ni `pubspec.yaml`: en la semana 10 no
se propuso ni se agregó ninguna dependencia nueva. En semanas anteriores
no se llevó el registro de qué dependencias sugirió una herramienta de
IA, por lo que este inventario verifica existencia y versión de todas
las declaradas, sin asignarles origen.

| Paquete (npm) | Declarada | Instalada | Última en el registro | Observación |
| --- | --- | --- | --- | --- |
| `better-sqlite3` | ^13.0.3 | 13.0.3 | 13.0.3 | Al día |
| `express` | ^4.19.2 | 4.22.2 | 5.3.0 | Se mantiene la serie 4; la 5 es un salto mayor no evaluado |
| `ajv` | ^8.17.1 | 8.20.0 | 8.20.0 | Al día |
| `js-yaml` | ^4.1.0 | 4.3.2 | 5.4.3 | Serie 5 no evaluada |
| `supertest` | ^7.0.0 | 7.2.2 | 7.3.1 | Dentro del rango |
| `vitest` | ^2.0.5 | 2.1.9 | 5.0.4 | Ver vulnerabilidades (solo desarrollo) |
| `typescript` | ^5.5.3 | 5.9.3 | 7.0.2 | Serie 7 no evaluada |
| `tsx` | ^4.16.2 | 4.23.12 | 4.23.15 | Dentro del rango |
| `@types/better-sqlite3` | ^9.6.0 | 9.6.0 | 9.6.0 | Tipos en 9 mientras la librería está en 13; revisar |
| `@types/express` | ^4.17.21 | 4.17.25 | 5.0.6 | Coherente con express 4 |
| `@types/js-yaml` | ^4.0.9 | 4.0.9 | 4.0.9 | Al día |
| `@types/node` | ^20.14.10 | 20.19.43 | 26.6.5 | Se mantiene 20 |
| `@types/supertest` | ^6.0.2 | 6.0.3 | 7.2.1 | Dentro del rango |

Dart (`pubspec.lock`): `http` ^1.2.2 resuelto en 1.6.0, `cupertino_icons`
^1.0.8 en 1.0.9 (la 2.0.0 existe y no es compatible con la restricción),
`flutter_lints` ^4.0.0 en 4.0.0 (la 6.0.0 existe y no es compatible).

Vulnerabilidades: `npm ci` reportó 11 (6 moderate, 2 high, 3 critical).
Con `npm audit --omit=dev` quedan 4 en dependencias de producción: 1
critical (`proxy-addr`, transitiva de `express` 4.22.2) y 3 moderate
(`body-parser`, `express`, `qs`), todas con corrección disponible. El
código no usa `req.ip` ni `trust proxy`, y no se aplicó ninguna
corrección todavía. Las otras 7 (`vitest`, `vite`, `tinypool`,
`source-map-js` y relacionadas) son de desarrollo; el `Dockerfile` instala
solo producción en la imagen final (`npm ci --omit=dev`). Pendiente: un
commit aparte que actualice las dependencias de producción dentro de su
rango y valide con `npm run verify`; la actualización mayor de `vitest`
es una decisión del equipo.

### Credenciales y secretos

También se revisó el código y los ejemplos del repositorio para evitar
la incorporación de:

- contraseñas;
- API keys;
- tokens;
- credenciales de servicios;
- secretos de despliegue;
- claves privadas.

Las credenciales necesarias para servicios externos o despliegues no
deben quedar escritas directamente en el código fuente ni en los
ejemplos versionados.

La revisión de credenciales forma parte de la verificación realizada
antes de considerar completa la contribución generada o modificada con
IA.

## Componente generativo dentro del sistema

AudioShare utiliza herramientas de Inteligencia Artificial como apoyo
durante el proceso de desarrollo, pero actualmente no incorpora un
modelo generativo como componente funcional del sistema.

La IA utilizada durante el desarrollo no forma parte de la ejecución
normal de AudioShare.

El equipo decidió no incorporar un componente generativo dentro del
producto para el alcance actual, debido a que las funcionalidades
principales del sistema —creación de salas, incorporación de
receptores, coordinación de reproducción y sincronización— no
requieren generación de contenido mediante un modelo generativo.

La decisión está documentada en:

[ADR-0006 — No incorporación de un componente generativo](./adr/0006-no-incorporar-componente-generativo.md).

Por esta razón, para el alcance actual no se incorpora un conjunto de
evaluación de respuestas generativas ni una estimación de costo y
latencia de inferencia como parte del sistema.

## Estado

Documento actualizado después del cierre de S10.

En la semana 10 (2026-10-12) se atendieron hallazgos del feedback de S9 y S10: prueba real
de EC-01 verificada por mutación, ADR-0007 (hoy aceptado), nombre del ADR-0005 conforme
a la convención, capa `data/` del cliente Flutter y Flutter CI en verde.
Con posterioridad al cierre se actualizó el C4 nivel 2 (D1) y se enlazaron los ADR en
arc42 §9, `docs/aspectos.md` y los escenarios.
Quedan pendientes, y no se presentan como resueltos: el cableado del cliente Flutter a
`GET /time`, al ACK y al stream NDJSON; la medición con dispositivos físicos; la
no conformidad NC-10 (propiedad del estado de reproducción entre Session y Sync); el
PNG del C4 nivel 2, que hay que regenerar desde el `.mmd`; la URL pública de SonarCloud con su
Quality Gate; los hallazgos 3 y 4 de la auditoría de erosión; la actualización de
dependencias de producción con vulnerabilidades; y el barrido del historial de Git en
busca de credenciales, que no se ha completado.

Durante la semana 6 se incorporó el análisis del mapa de contextos,
la relación módulo → datos con definición de dueño único y la
identificación de errores o no conformidades del estado actual del
proyecto junto con su correspondiente plan de corrección.

Durante la semana 7 se utilizó GitHub Copilot como herramienta de apoyo
para transferir el proyecto AudioShare desde su implementación web hacia
una aplicación desarrollada con Flutter. La IA fue utilizada
principalmente como apoyo para adaptar la estructura y los componentes
existentes a la nueva tecnología, manteniendo el alcance y las
funcionalidades definidas previamente.

La migración tecnológica no implica por sí misma una modificación de
las decisiones arquitectónicas previamente documentadas. Sin embargo,
la documentación del proyecto deberá actualizarse para reflejar la
nueva tecnología utilizada en la implementación y verificar que los
diagramas, descripciones, pruebas y referencias al código sean
coherentes con el estado actual del sistema.

Para la presente entrega también se documenta la clasificación de las
propuestas de IA como aceptadas, corregidas o rechazadas, junto con la
auditoría de límites de contexto, propiedad de datos, dependencias y
credenciales.

AudioShare no incorpora actualmente un componente generativo de IA
dentro del producto. Esta decisión se encuentra documentada en el
ADR-0006.

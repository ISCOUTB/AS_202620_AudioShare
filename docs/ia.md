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

## Herramientas utilizadas

* ChatGPT.
* Claude (Anthropic), usado en la revisión previa al corte 1 para
  contrastar la documentación del repositorio contra la Guía del curso
  y el historial de feedback.

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
| Semana 4 | Corte vertical A-01 | Apoyar la implementación del corte vertical ejecutable de sincronización de reproducción de audio | Se implementó el flujo de creación de salas, incorporación de receptores, sincronización mediante `startAt` y generación de paquetes `audio.chunk` | Se descartaron propuestas que ampliaban el alcance del corte vertical con funcionalidades no necesarias para demostrar la sincronización. Se mantuvo el flujo mínimo necesario para validar A-01. |
| Semana 4 | Pruebas | Diseñar y revisar la prueba de integración del corte vertical A-01 | Se creó `tests/a01.test.ts`, verificando la creación de una sala, dos receptores, la operación `PLAY` y la generación de eventos de sincronización y audio | Se rechazaron pruebas que verificaban únicamente funciones aisladas. Se priorizó una prueba de integración que recorriera el flujo completo del corte vertical. |
| Semana 4 | Documentación técnica | Actualizar el README y la documentación del aspecto A-01 | Se documentaron la implementación, el flujo de ejecución y las pruebas realizadas | Se descartó documentar funcionalidades que todavía no forman parte del corte vertical implementado. La documentación se limitó al comportamiento realmente disponible y verificable. |
| Semana 4 | Revisión y corrección | Analizar errores encontrados durante la ejecución de las pruebas | Se corrigió la prueba de integración hasta obtener 3 pruebas aprobadas en 2 archivos | Se rechazaron correcciones que modificaban el comportamiento esperado del sistema únicamente para hacer pasar las pruebas. Se corrigió la implementación o la prueba según el comportamiento definido. |
| Semana 4 | Corrección de matriz comparativa | Comparar escenarios de utilidad por cada fila | Se rehízo la matriz con los escenarios propuestos | Se rechazó la versión anterior porque comparaba los estilos arquitectónicos mediante criterios generales y no mostraba claramente el impacto sobre cada escenario del árbol de utilidad. La nueva matriz utiliza EC-01 a EC-04 como filas y especifica qué mejora y qué empeora con cada estilo. |
| Semana 4 | Persistencia del corte vertical | Incorporar persistencia real al corte vertical A-01 | Se implementó `SQLiteRoomRepository` con tablas `rooms` y `participants`, y se extendió `tests/a01.test.ts` para verificar la recuperación de una sala tras reabrir la base de datos | Se rechazó mantener el estado únicamente en memoria del proceso, porque no permitía demostrar persistencia real ni sobrevivir a un reinicio del servidor. También se rechazó introducir un motor de base de datos externo (por ejemplo PostgreSQL) por añadir una dependencia de infraestructura innecesaria para el alcance actual del prototipo. |
| Semana 4 | Corrección del C4 Nivel 2 | Alinear el diagrama de contenedores con el código real | Se rehízo `C4 Nivel 2 - Contenedores.mmd` para mostrar el cliente web, el servidor de aplicación y la base SQLite reales | Se rechazó la versión anterior del diagrama, que mostraba un Frontend SPA, un servicio de Discovery, un servidor de Signaling y un Media Engine que nunca se implementaron. Se descartó mantenerlos como "plan futuro" dentro del mismo diagrama para no mezclar lo implementado con lo especulativo; ese contenido se dejará para una futura actualización del diagrama cuando exista código real que lo respalde. |
| Semana 5 | Revisión pre-corte 1 | Contrastar `docs/aspectos.md`, `docs/ia.md`, arc42 y el ADR contra la Guía del curso y el feedback recibido en semanas 1 a 4 | Se identificó que `docs/aspectos.md` contenía dos tablas de trazabilidad casi idénticas, una de ellas con un enlace roto al diagrama C4 Nivel 2 (`Contenedor - Nivel 2.mmd`, un nombre de archivo que ya no existe) | Se rechazó conservar ambas tablas "por si acaso": se consolidaron en una sola tabla, usando las columnas y el nivel de detalle de la más completa, y se corrigió la ruta del enlace al nombre real del archivo (`C4 Nivel 2 - Contenedores.mmd`). También se rechazó reescribir el resto del documento desde cero: se conservó el contenido ya aceptado en semanas anteriores (descripción, requisitos, implementación, pruebas) sin modificarlo. |

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

La decisión final sobre aceptar, modificar o rechazar una propuesta
corresponde al equipo.

## Estado

Documento actualizado durante la semana 5, previo al corte 1.

El registro continuará actualizándose durante las siguientes etapas del
proyecto, indicando los usos relevantes de Inteligencia Artificial,
las propuestas consideradas, aquellas que fueron rechazadas y la
justificación de las decisiones tomadas por el equipo.

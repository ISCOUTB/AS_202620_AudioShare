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

## Herramientas utilizadas

* ChatGPT.
* Claude (Anthropic), usado en la revisión previa al corte 1 para
  contrastar la documentación del repositorio contra la Guía del curso
  y el historial de feedback.
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


La decisión final sobre aceptar, modificar o rechazar una propuesta
corresponde al equipo.

## Estado

Documento actualizado durante la semana 7.

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


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

## Herramientas utilizadas

* ChatGPT.

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

| Etapa    | Uso                              | Propósito                                                                                         | Resultado                                                                                                                                                  | Propuesta de IA rechazada y motivo                                                                                                                                                                                                                                                               |
| -------- | -------------------------------- | ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Semana 1 | Generación y evaluación de ideas | Explorar posibles proyectos para la asignatura                                                    | Se seleccionó AudioShare como propuesta de proyecto                                                                                                        | Se descartaron ideas que no permitían evidenciar adecuadamente decisiones de arquitectura y atributos de calidad. Se priorizó AudioShare por permitir trabajar sincronización, comunicación entre clientes y restricciones de rendimiento.                                                       |
| Semana 1 | Redacción y revisión             | Estructurar la ficha del problema                                                                 | Se definió el problema y el prototipo de AudioShare                                                                                                        | Se rechazaron formulaciones demasiado generales que no identificaban claramente a los usuarios ni las necesidades del sistema. Se ajustó el problema para delimitar el alcance del prototipo.                                                                                                    |
| Semana 2 | arc42                            | Apoyar la organización de las secciones 1–3                                                       | Se estructuró la documentación inicial de arquitectura                                                                                                     | Se descartaron explicaciones que agregaban contenido no requerido para el alcance de la entrega. Se mantuvieron únicamente las secciones y decisiones relevantes para AudioShare.                                                                                                                |
| Semana 2 | Requisitos de calidad            | Identificar atributos y escenarios medibles                                                       | Se propusieron objetivos de calidad y métricas                                                                                                             | Se rechazaron atributos o escenarios demasiado generales o difíciles de medir. Se priorizaron escenarios relacionados con rendimiento, disponibilidad/confiabilidad y usabilidad.                                                                                                                |
| Semana 2 | C4                               | Elaborar el diagrama de contexto                                                                  | Se generó el código Mermaid y la imagen del C4 de contexto                                                                                                 | Se rechazaron elementos que pertenecían a niveles inferiores de C4 y no al contexto. El diagrama se limitó al sistema AudioShare, sus usuarios y sistemas externos relevantes.                                                                                                                   |
| Semana 2 | Documentación                    | Revisar la organización de los documentos                                                         | Se estructuró la documentación dentro del repositorio                                                                                                      | Se descartaron estructuras de carpetas innecesariamente complejas para el alcance actual del proyecto. Se mantuvo una organización compatible con arc42, ADR, C4 y los documentos solicitados.                                                                                                   |
| Semana 3 | Consulta                         | Investigación de los estilos arquitectónicos                                                      | Se generó la matriz comparativa                                                                                                                            | Se rechazó una comparación basada únicamente en ventajas y desventajas generales. Se decidió relacionar cada estilo directamente con los escenarios EC-01 a EC-04 del árbol de utilidad.                                                                                                         |
| Semana 4 | Corte vertical A-01              | Apoyar la implementación del corte vertical ejecutable de sincronización de reproducción de audio | Se implementó el flujo de creación de salas, incorporación de receptores, sincronización mediante `startAt` y generación de paquetes `audio.chunk`         | Se descartaron propuestas que ampliaban el alcance del corte vertical con funcionalidades no necesarias para demostrar la sincronización. Se mantuvo el flujo mínimo necesario para validar A-01.                                                                                                |
| Semana 4 | Pruebas                          | Diseñar y revisar la prueba de integración del corte vertical A-01                                | Se creó `tests/a01.test.ts`, verificando la creación de una sala, dos receptores, la operación `PLAY` y la generación de eventos de sincronización y audio | Se rechazaron pruebas que verificaban únicamente funciones aisladas. Se priorizó una prueba de integración que recorriera el flujo completo del corte vertical.                                                                                                                                  |
| Semana 4 | Documentación técnica            | Actualizar el README y la documentación del aspecto A-01                                          | Se documentaron la implementación, el flujo de ejecución y las pruebas realizadas                                                                          | Se descartó documentar funcionalidades que todavía no forman parte del corte vertical implementado. La documentación se limitó al comportamiento realmente disponible y verificable.                                                                                                             |
| Semana 4 | Revisión y corrección            | Analizar errores encontrados durante la ejecución de las pruebas                                  | Se corrigió la prueba de integración hasta obtener 3 pruebas aprobadas en 2 archivos                                                                       | Se rechazaron correcciones que modificaban el comportamiento esperado del sistema únicamente para hacer pasar las pruebas. Se corrigió la implementación o la prueba según el comportamiento definido.                                                                                           |
| Semana 4 | Corrección de matriz comparativa | Comparar escenarios de utilidad por cada fila                                                     | Se rehízo la matriz con los escenarios propuestos                                                                                                          | Se rechazó la versión anterior porque comparaba los estilos arquitectónicos mediante criterios generales y no mostraba claramente el impacto sobre cada escenario del árbol de utilidad. La nueva matriz utiliza EC-01 a EC-04 como filas y especifica qué mejora y qué empeora con cada estilo. |

## Criterio para rechazar propuestas de IA

Las propuestas generadas por Inteligencia Artificial no se incorporan
automáticamente al proyecto. Una propuesta puede ser rechazada cuando:

* No corresponde con el alcance definido para AudioShare.
* No puede comprobarse mediante una prueba o evidencia en el
  repositorio.
* Introduce complejidad innecesaria para el prototipo.
* No está relacionada con los atributos de calidad priorizados.
* Contradice una restricción o decisión arquitectónica previamente
  establecida.
* Presenta información técnicamente incorrecta o insuficientemente
  justificada.
* Amplía el alcance de una entrega más allá de lo solicitado.

La decisión final sobre aceptar, modificar o rechazar una propuesta
corresponde al equipo.

## Estado

Documento actualizado durante la semana 4.

El registro continuará actualizándose durante las siguientes etapas del
proyecto, indicando los usos relevantes de Inteligencia Artificial,
las propuestas consideradas, aquellas que fueron rechazadas y la
justificación de las decisiones tomadas por el equipo.

# ADR-0006 — No incorporación de un componente generativo

- **Estado:** aceptado
- **Fecha:** 2026-10-04
- **Decide:** Equipo AudioShare
- **Relacionado con:** A-01 — Sincronización de reproducción de audio

## Contexto

Durante el desarrollo de AudioShare se utilizó inteligencia artificial
como herramienta de apoyo para actividades de desarrollo, análisis,
documentación y generación de propuestas.

Sin embargo, el sistema AudioShare no requiere actualmente un
componente generativo de inteligencia artificial como parte de su
funcionalidad.

El alcance actual se concentra en la creación de salas, registro de
participantes, control de reproducción, generación de `startAt`,
distribución de eventos y sincronización de los dispositivos.

## Decisión

Se decide no incorporar un componente generativo de inteligencia
artificial dentro del sistema AudioShare para el alcance actual.

La inteligencia artificial se utilizará únicamente como herramienta
de apoyo durante el proceso de desarrollo y no como componente de
ejecución del sistema.

## Justificación

La incorporación de un modelo generativo no aporta un beneficio
necesario para cumplir los escenarios de calidad definidos para
AudioShare.

Además, incorporarlo introduciría:

- una dependencia adicional;
- posibles costos por operación;
- latencia adicional;
- necesidad de evaluar las respuestas generadas;
- una nueva superficie de seguridad y mantenimiento.

Por estas razones, el equipo considera que su incorporación no está
justificada para el alcance actual del proyecto.

## Consecuencias

### Positivas

- Se mantiene una arquitectura más sencilla.
- No se agrega una dependencia de un proveedor de IA.
- No se generan costos de inferencia.
- No se introduce latencia asociada a un modelo generativo.
- No es necesario mantener un conjunto de evaluación de respuestas
  generativas.

### Negativas

Si en el futuro aparece un requisito que necesite generación
automática de contenido, será necesario evaluar nuevamente esta
decisión y posiblemente crear un nuevo ADR.

## Alcance de la decisión

Esta decisión se refiere al uso de IA como **componente del producto**.

No impide el uso de herramientas de IA durante el desarrollo del
proyecto. Dicho uso se documenta en `docs/ia.md`.

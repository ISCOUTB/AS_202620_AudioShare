# 0001 — Selección del estilo arquitectónico

- **Estado:** propuesto
- **Fecha:** 2026-08-23
- **Decide:** Yeiver Andres Verjel Perez, Elian Daniel Perea Vanegas, Santiago Adolfo Camacho Hernandez y Vincent Cardona Castro.
- **Escenario de calidad relacionado:** EC-nn

## Contexto

En AudioShare requiere una estructura arquitectónica en la cual permita organizar diferentes funcionalidades de una manera clara y desde el inicio del desarrollo.
El proyecto debe contar con una separación muy adecuada de responsabilidades y funciones para facilitar las pruebas y permitir su desarrollo a medida que se incorporen nuevas funcionalidades, asimismo, se busca evitar una complejidad arquitectónica innecesaria para la etapa actual del proyecto. 

## Alternativas consideradas

### A. Arquitectura en capas
Organiza la aplicación mediante capas con responsabilidades específicas, como presentación, aplicación, dominio y acceso a datos.
- **A favor:** estructura sencilla de comprender y separación clara de responsabilidades.
- **En contra:** las dependencias entre capas pueden generar acoplamiento y dificultar la evolución de funcionalidades cuando el sistema aumenta en complejidad.
- **Por qué no se eligió:** aunque proporciona una organización inicial adecuada, ofrece una separación menos orientada a las funcionalidades del sistema que el monolito modular.

### B. Arquitectura hexagonal
Organiza el sistema alrededor de la lógica central y utiliza puertos y adaptadores para separar el núcleo de las dependencias externas.

- **A favor:** favorece la testabilidad, reduce el acoplamiento con componentes externos y facilita el reemplazo de implementaciones.
- **En contra:** introduce una mayor complejidad inicial y requiere más abstracciones y estructuras.
- **Por qué no se eligió:** para la etapa actual de AudioShare se consideró que la complejidad adicional no resulta necesaria frente a las necesidades actuales del proyecto.

###C. Monolito modular
Mantiene la aplicación como una única unidad de ejecución, pero divide internamente sus responsabilidades en módulos independientes y claramente delimitados.
- **A favor:** permite mantener una estructura organizada, separar responsabilidades y facilitar el mantenimiento y las pruebas sin introducir la complejidad de una aplicación distribuida.
- **En contra:** los módulos continúan formando parte de una misma aplicación y requieren reglas claras para evitar dependencias innecesarias entre ellos.
- **Por qué se eligió:** ofrece un equilibrio adecuado entre organización, mantenibilidad, facilidad de desarrollo y complejidad inicial para AudioShare.

## Decisión

Se elige Monolito Modular como estilo arquitectónico para AudioShare.
La decisión se toma a partir de la comparación realizada en la Sección 4 de arc42, considerando las necesidades actuales del proyecto y los criterios establecidos en la matriz comparativa, el monolito modular permite mantener una única aplicación, pero establece límites entre las diferentes responsabilidades del sistema y esto va a permitir comenzar el desarrollo con una estructura controlada y facilita la evolución posterior del proyecto.

## Consecuencias

- **Positivas:** se obtiene una estructura modular desde el inicio, se facilita la organización del código y se favorecen el mantenimiento y las pruebas. Además, se evita introducir una complejidad de despliegue innecesaria para la etapa actual.
- **Negativas / costos asumidos:** será necesario definir y respetar los límites entre módulos. Al tratarse de una única aplicación, los módulos continúan.
- **Riesgos y qué los dispararía:** existe el riesgo de que los módulos desarrollen dependencias innecesarias y el sistema termine comportándose como un monolito sin separación interna. Este riesgo se incrementaría si no se respetan las responsabilidades y reglas de dependencia establecidas para cada módulo.
- **Qué habría que revisar si cambia Y:** si el sistema requiere una distribución independiente de sus funcionalidades, un crecimiento significativo de determinados módulos o necesidades de escalabilidad independiente, se deberá revisar la decisión arquitectónica y evaluar nuevamente alternativas como una arquitectura hexagonal o una arquitectura distribuida.

## Trazabilidad

- Requisito / aspecto: organización, mantenibilidad, testabilidad y evolución de la arquitectura de AudioShare.
- Elementos C4 afectados: …
- Implementación: commit / PR …
- Pruebas que lo cubren: …

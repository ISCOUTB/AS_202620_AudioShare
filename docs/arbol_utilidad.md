# Árbol de utilidad – AudioShare

El árbol de utilidad permite identificar los atributos de calidad más
importantes para AudioShare y establecer cuáles deben ser priorizados
durante el diseño y desarrollo del sistema.

La prioridad se establece teniendo en cuenta que la función principal
de AudioShare es transmitir audio en tiempo real y mantener una
reproducción sincronizada entre varios dispositivos.

## 1. Rendimiento — Alta prioridad

El rendimiento es el atributo de mayor prioridad debido a que la
función principal de AudioShare es transmitir audio entre dispositivos
en tiempo real. Una latencia elevada afectaría directamente la
sincronización de la reproducción y la experiencia de los usuarios.

Se busca mantener una baja latencia y una diferencia mínima en el
inicio y reproducción del audio entre los dispositivos receptores.

**Escenarios relacionados:** EC-01, EC-02 y EC-03.

## 2. Disponibilidad y confiabilidad — Alta prioridad

La disponibilidad y confiabilidad son importantes porque AudioShare
depende de una comunicación constante entre los dispositivos
conectados a una sala.

Si la conexión se interrumpe constantemente o la sala deja de
funcionar ante una variación de la red, la experiencia de uso se ve
afectada. Por esta razón, se prioriza que la transmisión permanezca
funcional mientras exista una conexión de red disponible y que el
sistema pueda manejar adecuadamente situaciones de pérdida o
recuperación de conexión.

**Escenarios relacionados:** EC-02 y EC-04.

## 3. Usabilidad — Prioridad media

La usabilidad es importante porque AudioShare busca permitir que los
usuarios compartan audio de una manera sencilla.

La creación de una sala, la incorporación de dispositivos receptores
y el control de la reproducción deben realizarse mediante
interacciones fáciles de comprender, evitando procedimientos
innecesariamente complejos.

**Escenarios relacionados:** EC-04.

## 4. Seguridad — Prioridad media

La seguridad es relevante debido a que AudioShare utiliza salas para
establecer la comunicación entre los usuarios.

El sistema debe evitar que dispositivos que no pertenecen a una
sesión puedan acceder a ella sin autorización. Para ello, se deberán
considerar mecanismos que permitan controlar el acceso a las salas y
limitar la comunicación a los participantes correspondientes.

Este atributo será refinado mediante escenarios de calidad específicos
a medida que se defina el mecanismo de autenticación y control de
acceso.

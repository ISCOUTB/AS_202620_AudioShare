# Restricciones justificadas

## R-01 — Uso de herramientas gratuitas

**Restricción:**  
El primer prototipo de AudioShare deberá desarrollarse utilizando
herramientas y servicios gratuitos que no generen costos económicos
obligatorios.

**Justificación:**  
El proyecto busca validar inicialmente la estructura arquitectónica
del sistema sin requerir inversión económica. Esto permite que el
equipo pueda desarrollar, probar y evaluar el prototipo utilizando
los recursos disponibles.

**Consecuencia arquitectónica:**  
Las tecnologías y servicios seleccionados deberán contar con opciones
gratuitas suficientes para desarrollar y probar el prototipo.

---

## R-02 — Funcionamiento sobre una red Wi-Fi local

**Restricción:**  
El prototipo deberá funcionar inicialmente dentro de una misma red
Wi-Fi local.

**Justificación:**  
El objetivo de AudioShare es permitir que varios dispositivos cercanos
compartan el mismo audio sin utilizar cables, adaptadores o depender
de conexiones Bluetooth múltiples. Una red Wi-Fi local permite realizar
estas pruebas sin necesidad de infraestructura pública.

**Consecuencia arquitectónica:**  
La arquitectura deberá permitir la comunicación y transmisión de audio
entre dispositivos conectados a la misma red local.

---

## R-03 — Transmisión de audio en tiempo real

**Restricción:**  
La solución deberá utilizar un mecanismo de comunicación que permita
transmitir el audio mientras se reproduce en el dispositivo emisor.

**Justificación:**  
AudioShare tiene como objetivo que los dispositivos receptores puedan
escuchar simultáneamente el audio compartido. Por lo tanto, una solución
basada únicamente en la transferencia completa de archivos no cumpliría
el propósito principal del sistema.

**Consecuencia arquitectónica:**  
El mecanismo de comunicación deberá ser evaluado teniendo en cuenta
principalmente la latencia y la continuidad de la transmisión.

---

## R-04 — Evaluación del mecanismo de comunicación

**Restricción:**  
No se establecerá inicialmente una tecnología definitiva para la
transmisión de audio. Se deberán evaluar diferentes alternativas antes
de seleccionar el mecanismo de comunicación.

**Justificación:**  
El equipo considera alternativas como WebRTC y WebSockets, pero la
elección debe realizarse considerando las necesidades del proyecto,
especialmente la latencia y las características de la transmisión.

**Consecuencia arquitectónica:**  
La selección de la tecnología deberá justificarse posteriormente
mediante la comparación de alternativas y las decisiones arquitectónicas
correspondientes.

---

## R-05 — Múltiples dispositivos receptores

**Restricción:**  
La solución deberá permitir que una sala pueda manejar varios
dispositivos receptores simultáneamente.

**Justificación:**  
El propósito de AudioShare es compartir el mismo audio entre varias
personas y dispositivos dentro de una misma sala.

**Consecuencia arquitectónica:**  
La arquitectura deberá considerar el impacto que tiene el número de
receptores sobre la latencia, la transmisión y el consumo de recursos
de la red.

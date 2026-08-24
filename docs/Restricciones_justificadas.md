# Restricciones justificadas

## R-01 — Uso de herramientas gratuitas

Tipo: Organizativa

*Restricción:**  
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

**Tipo:** Técnica

**Restricción:**  
El primer prototipo deberá funcionar inicialmente dentro de una misma
red Wi-Fi local.

**Justificación:**  
El objetivo de AudioShare es permitir que varios dispositivos cercanos
compartan el mismo audio sin utilizar cables, adaptadores o depender
de múltiples conexiones Bluetooth. Una red Wi-Fi local permite realizar
las pruebas sin necesidad de infraestructura pública.

**Consecuencia arquitectónica:**  
La arquitectura deberá permitir la comunicación y transmisión de audio
entre dispositivos conectados a la misma red local.

---

## R-03 — Evaluación del mecanismo de comunicación

**Tipo:** Técnica

**Restricción:**  
El mecanismo de comunicación para la transmisión de audio deberá
seleccionarse después de evaluar diferentes alternativas tecnológicas.

**Justificación:**  
AudioShare necesita transmitir audio en tiempo real entre dispositivos.
El equipo considera alternativas como WebRTC y WebSockets, pero la
tecnología definitiva deberá seleccionarse teniendo en cuenta las
necesidades del sistema, especialmente la latencia y la continuidad
de la transmisión.

**Consecuencia arquitectónica:**  
La selección del mecanismo de comunicación deberá justificarse mediante
la comparación de las alternativas consideradas y una decisión
arquitectónica documentada en un ADR.

---

## R-04 — Restricciones legales

**Tipo:** Legal

**Restricción:**  
En el alcance actual del prototipo no se ha identificado una
restricción legal específica que limite la arquitectura del sistema.

**Justificación:**  
El primer prototipo funcionará dentro de una red Wi-Fi local y se
utilizará con fines académicos. Por el momento no se ha establecido
un requisito legal específico que obligue a adoptar una determinada
tecnología o arquitectura.

**Consecuencia arquitectónica:**  
Si durante el desarrollo se identifican requisitos relacionados con
licencias, derechos de autor, privacidad o tratamiento de datos,
deberán incorporarse como restricciones legales y reflejarse en la
arquitectura.

---


# Escenarios de Calidad

Los siguientes escenarios de calidad permiten evaluar aspectos
importantes del funcionamiento de AudioShare, especialmente la
sincronización de reproducción entre el dispositivo emisor y los
dispositivos receptores conectados a la misma red Wi-Fi.

## EC-01 — Sincronización inicial

### Estímulo

Un dispositivo emisor inicia la reproducción de audio mientras uno o
varios dispositivos receptores están conectados a la misma red Wi-Fi.

### Respuesta esperada

Todos los dispositivos receptores deben comenzar la reproducción del
audio de manera prácticamente simultánea.

### Medida

La diferencia máxima entre el inicio de reproducción de los receptores
no debe superar los **100 ms**.

### Restricción

Los dispositivos deben estar conectados a la misma red Wi-Fi y mantener
una conexión estable durante toda la prueba.

### Justificación

Esta restricción permite evaluar la sincronización bajo las condiciones
normales de funcionamiento previstas para AudioShare.

---

## EC-02 — Variación moderada de latencia

### Estímulo

Durante la reproducción se presenta un aumento moderado de la latencia
de la red Wi-Fi.

### Respuesta esperada

Los dispositivos receptores deben continuar reproduciendo el audio,
intentando mantener la sincronización entre ellos.

### Medida

La diferencia de reproducción entre los receptores no debe superar los
**200 ms** durante la variación de la red.

### Restricción

La variación de latencia debe ser moderada y no representar una pérdida
completa de conexión con la red Wi-Fi.

### Justificación

Las condiciones de una red Wi-Fi pueden variar durante el
funcionamiento del sistema. AudioShare debe tolerar variaciones
moderadas sin perder significativamente la sincronización.

---

## EC-03 — Pausa y reanudación

### Estímulo

El dispositivo emisor pausa el audio y posteriormente reanuda la
reproducción.

### Respuesta esperada

Los dispositivos receptores deben pausar y reanudar la reproducción de
acuerdo con las acciones realizadas por el dispositivo emisor.

### Medida

Después de reanudar la reproducción, la diferencia entre los receptores
no debe superar los **100 ms**.

### Restricción

Los dispositivos receptores deben permanecer conectados a la misma red
Wi-Fi durante la pausa y la reanudación.

### Justificación

Permite verificar que las acciones realizadas desde el dispositivo
emisor se reflejen de manera sincronizada en todos los receptores.

---

## EC-04 — Incorporación de nuevo receptor

### Estímulo

Un nuevo dispositivo receptor se conecta a la red Wi-Fi mientras el
audio ya está siendo reproducido.

### Respuesta esperada

El nuevo receptor debe incorporarse a la reproducción y sincronizarse
con los demás dispositivos.

### Medida

El nuevo receptor debe alcanzar la sincronización con los demás
dispositivos en un tiempo máximo de **3 segundos**.

### Restricción

El nuevo dispositivo debe conectarse correctamente a la misma red Wi-Fi
y contar con las condiciones necesarias para recibir el audio.

### Justificación

Permite comprobar que un nuevo receptor puede incorporarse al sistema
sin afectar la reproducción de los dispositivos que ya se encuentran
conectados.

---

## Relación con los aspectos

Los escenarios definidos se relacionan con el aspecto arquitectónico
**A-01 — Sincronización de reproducción de audio**, documentado en
`docs/aspectos.md`.

- **EC-01** evalúa la sincronización inicial.
- **EC-02** evalúa la sincronización ante variaciones moderadas de
  latencia.
- **EC-03** evalúa la sincronización después de una pausa y reanudación.
- **EC-04** evalúa la incorporación de un nuevo dispositivo receptor.

Estos escenarios podrán ampliarse o modificarse a medida que avance el
desarrollo y se obtenga información adicional mediante las pruebas del
prototipo.

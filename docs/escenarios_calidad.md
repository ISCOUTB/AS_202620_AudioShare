# Escenarios de Calidad

Los siguientes escenarios de calidad permiten evaluar aspectos
importantes del funcionamiento de AudioShare, especialmente la
sincronización de reproducción entre el dispositivo emisor y los
dispositivos receptores conectados a la misma red Wi-Fi.

## EC-01 — Sincronización inicial

### Fuente

Dispositivo emisor que inicia la reproducción del audio.

### Estímulo

El dispositivo emisor inicia la reproducción de audio mientras uno o varios
dispositivos receptores están conectados a la misma red Wi-Fi local.

### Artefacto

Es el mecanismo de transmisión y sincronización de AudioShare, junto con los
dispositivos receptores conectados a la sala.

### Entorno

Funcionamiento normal del sistema dentro de una red Wi-Fi local estable,
con los dispositivos conectados a la misma sala.

### Respuesta esperada

Todos los dispositivos receptores deben comenzar la reproducción del audio
de manera simultanea o muy parecida.

### Medida

La diferencia máxima entre el inicio de reproducción de los receptores no
debe superar los 100 ms.

### Restricción

Los dispositivos deben estar conectados a la misma red Wi-Fi y mantener
una conexión estable durante la prueba.

### Justificación

Permite evaluar si AudioShare puede mantener una reproducción sincronizada
entre varios dispositivos bajo las condiciones normales previstas para el
primer prototipo.

### EC-01 — Sincronización inicial

...

**Aspecto relacionado:** [A-01 — Sincronización de reproducción de audio](./aspectos.md#a-01--sincronización-de-reproducción-de-audio)

**ADR relacionado:** [ADR-0001 — Selección del estilo arquitectónico](./adr/0001-usar-monolito-modular.md)

---

## EC-02 — Variación moderada de latencia

### Fuente

La red Wi-Fi utilizada por los dispositivos conectados a la sala.

### Estímulo

Durante la reproducción se presenta un aumento moderado de la latencia
de la red Wi-Fi.

### Artefacto

Mecanismo de transmisión de audio de AudioShare y dispositivos receptores
que participan en la reproducción.

### Entorno

Sistema funcionando dentro de una red Wi-Fi local que presenta una
variación moderada de latencia, sin pérdida completa de conexión.

### Respuesta esperada

Los dispositivos receptores deben continuar reproduciendo el audio,
intentando mantener la sincronización entre ellos.

### Medida

La diferencia de reproducción entre los receptores no debe superar los
200 ms durante la variación de la red.

### Restricción

La variación de latencia debe ser moderada y no representar una pérdida
completa de conexión con la red Wi-Fi.

### Justificación

Permite comprobar la tolerancia del sistema ante variaciones normales
que pueden presentarse en una red Wi-Fi.

---

## EC-03 — Pausa y reanudación

### Fuente

Usuario del dispositivo emisor que controla la reproducción.

### Estímulo

El dispositivo emisor pausa el audio y posteriormente reanuda la
reproducción.

### Artefacto

Mecanismo de control de reproducción y dispositivos receptores
conectados a la sala.

### Entorno

AudioShare funcionando normalmente dentro de una red Wi-Fi local estable,
con los dispositivos receptores conectados a la sala.

### Respuesta esperada

Los dispositivos receptores deben pausar y reanudar la reproducción de
acuerdo con las acciones realizadas desde el dispositivo emisor.

### Medida

Después de reanudar la reproducción, la diferencia entre los receptores
no debe superar los 100 ms.

### Restricción

Los dispositivos receptores deben permanecer conectados a la misma red
Wi-Fi durante la pausa y la reanudación.

### Justificación

Permite verificar que las acciones de reproducción realizadas por el
emisor se reflejen de manera sincronizada en los receptores.

---

## EC-04 — Incorporación de nuevo receptor

### Fuente

Usuario que desea incorporarse a una sala existente.

### Estímulo

Un nuevo dispositivo receptor se conecta a la sala mientras el audio ya
está siendo reproducido.

### Artefacto

Mecanismo de incorporación de usuarios, sala de AudioShare y mecanismo
de transmisión de audio.

### Entorno

AudioShare funcionando dentro de una red Wi-Fi local, con una sala
existente y otros dispositivos reproduciendo audio.

### Respuesta esperada

El nuevo receptor debe incorporarse a la reproducción y sincronizarse
con los demás dispositivos sin interrumpir la reproducción existente.

### Medida

El nuevo receptor debe alcanzar la sincronización con los demás
dispositivos en un tiempo máximo de 3 segundos.

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

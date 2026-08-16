# Arc42

AudioShare permite que se pueda transmitir en tiempo real el audio reproducido en un dispositivo emisor hacia otros dispositivos receptores
conectados en una misma sala. Se piensa para cuando varias personas quieren escuchar audio al mismo tiempo sin estar utilizando
físicamente un único dispositivo de reproducción y funcionará sobre una red de wifi local donde se podrá crear una sala y los demás usuarios
se podrán conectar con un código de acceso y escuchar simultáneamente el audio compartido.

# Restricciones de arquitectura

El primer prototipo va a desarrollarse sin ningún costo económico por lo que utilizaremos herramientas gratuitas que no impliquen ello, se 
busca validar la estructura arquitectónica en esta primera versión. A su vez, el programa funcionará localmente sobre una red wifi, lo que nos 
permitirá hacer pruebas de la transmisión sin usar infraestructura publica. Se deberá seleccionar un mecanismo que ayude con la transmisión de 
audio y comunicación, por lo que se van a evaluar alternativas como WebRTC y WebSockets considerando cosas como la latencia y las necesidades
del proyecto. 

# Objetivos de calidad

Buscaremos principalmente los siguientes aspectos: 
- Rendimiento: Tratar de mantener una baja latencia durante la transmisión para que no haya mucho retraso al escuchar el audio.
- Disponibilidad: Tratar de mantener activa y funcional la transmisión el mayor tiempo posible siempre que exista una conexión estable entre
  los dispositivos.
- Tolerancia a fallos: Buscar que en caso de una interrupción en la conexión, se pueda poder reconectar.
- Escalabilidad: Permitir que una sala pueda tener y manejar a varios dispositivos receptores. 

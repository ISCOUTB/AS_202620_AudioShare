# Escenarios de Calidad
Como nos menciono/sugirio el profesor para unos posibles escenarios serian los siguientes:

## Ec 1: 
Un dispositivo emisor debe iniciar la reproducción mientras que otro/s dispositivo/s receptores están conectados a la misma red Wi-Fi

Respuesta: Todos los dispositivos receptores deben comenzar simultaneamente la reproducir del audio de manera prácticamente instantaneas

Medidas: La diferencia máxima entre el inicio de reproducción de los receptores no debe superar los 100 ms

## Ec 2:
Durante la reproducción se podria presenta un aumento moderado de la latencia de la red Wi-Fi

Respuesta: Los dispositivos receptores deben continuar reproduciendo del audio intentando mantener la sincronización

Medida: La diferencia de reproducción entre los receptores no debe superar los 200 ms durante la variación de la red

## Ec 3:
El dispositivo emisor pausa el audio y posteriormente reanuda la reproducción del audio

Respuesta: Los dispositivos receptores deben pausar y reanudar la reproducción de acuerdo con las acciones realizadas por el dispositivo emisor

Medida: Después de reanudar, la diferencia de reproducción entre los receptores no debe superar los 100 ms

## Ec 4:
Un nuevo dispositivo receptor se conecta a la red Wi-Fi mientras el audio ya está siendo reproducido

Respuesta: El nuevo receptor debe incorporarse a la reproducción y sincronizarse con los demás dispositivos

Medida: El nuevo receptor debe alcanzar la sincronización con los demás dispositivos en un tiempo máximo de 3 segundos

##

Estos serian algunos de los casos principales para verificar el correcto funcionamiento de nuestro proyecto
Mientras avancemos, plantearemos otros escenarios posibles


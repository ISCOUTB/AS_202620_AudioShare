## Matriz Comparativa de Arquitectura

| Criterio / Requisito | Arquitectura por Capas | Arquitectura Hexagonal | Monolito Modular |
| :--- | :--- | :--- | :--- |
| **Aislamiento de Lógica de Sincronización** | **Medio:** La lógica del estado de reproducción puede mezclarse con la capa de servicio/controlador. | **Alto:** La lógica central (play/pause/sync) queda totalmente aislada de la infraestructura (WebSockets/WebRTC). | **Alto:** La lógica se aísla por módulos de dominio (`sync`, `audio`, `session`). |
| **Intercambiabilidad de Protocolos de Red** | **Bajo:** Cambiar el protocolo de red impacta directamente las capas superiores. | **Alto:** Permite cambiar el transporte creando un nuevo *Adapter* sin alterar las reglas del juego. | **Medio:** Depende del acoplamiento entre los módulos y los drivers de red. |
| **Facilidad para Pruebas Automatizadas** | **Medio:** Requiere simular capas inferiores de persistencia o red. | **Excelente:** Permite testear el control del "Host/Líder" con *mocks* del bus de eventos/red. | **Alto:** Permite probar módulos de manera aislada dentro del mismo proceso. |
| **Gestión de Eventos en Tiempo Real** | **Baja/Media:** Las llamadas entre capas añaden indirección no orientada a eventos. | **Alta:** Ideal para manejar comandos reactivos (`PAUSE`, `PLAY`, `SEEK`) en tiempo real. | **Alta:** Comunicación in-memory ultrarrápida entre módulos dentro del mismo servicio. |
| **Complejidad de Mantenimiento Inicial** | **Baja:** Estructura tradicional y rápida de montar. | **Media:** Requiere definir explícitamente puertos y adaptadores. | **Media:** Requiere definir límites rígidos entre módulos. |

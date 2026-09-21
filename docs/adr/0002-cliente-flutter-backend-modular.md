# ADR-0002: Cliente Flutter y backend modular existente

## Contexto
AudioShare necesita una experiencia multiplataforma en Android y Web, pero la persistencia SQLite, el contrato HTTP y el stream NDJSON ya implementan el corte A-01 en el servidor.

## Problema
Trasladar SQLite y el servidor de salas al proceso Flutter duplicaría la persistencia y rompería la comunicación entre dispositivos de la red local.

## Alternativas consideradas
- Reescribir el servidor en Flutter/Dart: no aporta una ventaja clara para un servidor compartido y obliga a duplicar la persistencia.
- Mantener la interfaz web anterior: no cumple el objetivo de una aplicación Flutter.
- Mantener el backend y crear un cliente Flutter: conserva el contrato y permite Android/Web.

## Decisión
AudioShare queda como un monolito modular de backend Node/Express con SQLite, consumido por una aplicación Flutter. Flutter separa UI, ViewModels, repositorios y servicios. El backend sigue siendo la fuente de verdad de salas y estados.

## Consecuencias
- La aplicación requiere un backend accesible en la red local.
- No se duplica SQLite en cada dispositivo.
- El transporte de audio físico permanece pendiente; Dart expone `AudioService` y usa `MockAudioService`.
- Las metas EC-01 y EC-02 no se declaran cumplidas sin mediciones de red.

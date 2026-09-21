# ADR 0002 — Transición del cliente web a aplicación móvil Flutter

- Estado: Aceptado
- Fecha: 2026-09-20

## Contexto

AudioShare se desarrollaria inicialmente utilizando un cliente web
para interactuar con el backend del sistema.

Durante la evolución del proyecto se decidió orientar el cliente hacia
una aplicación móvil (*Flutter*), con el objetivo de adaptar AudioShare al uso
directo desde dispositivos móviles.

## Decisión

Se decide realizar la transición del cliente web hacia una aplicación
móvil desarrollada utilizando Flutter.

Flutter será responsable de la interfaz y de la interacción con el
usuario, mientras que el backend de AudioShare mantendrá las
responsabilidades relacionadas con las sesiones, el audio y la
sincronización.

La comunicación entre la aplicación Flutter y el backend se realizará
mediante la API existente del sistema.

## Arquitectura propuesta

La arquitectura general queda organizada de la siguiente manera:

```text
Usuario
   |
   v
Aplicación móvil Flutter
   |
   v
Backend AudioShare
   |
   +-- Session
   +-- Audio
   +-- Sync
   +-- Shared
```

## Justificación

La transición permite orientar el cliente hacia dispositivos móviles
sin modificar las responsabilidades principales establecidas para el
backend, siendo asi mucho mas facil a las funcionalidades que queremos implementar.

Además, permite mantener separada la interfaz de usuario de la lógica
del servidor y conservar la organización modular existente.

## Consecuencias positivas

- El cliente estará orientado a dispositivos móviles.
- Se mantiene la separación entre cliente y backend.
- Se conserva la organización modular del backend.
- Flutter permite desarrollar el cliente móvil utilizando una única
  base de código para las plataformas móviles soportadas.

## Consecuencias negativas

- Será necesario desarrollar la interfaz del cliente.
- Se deben adaptar las funcionalidades existentes al entorno móvil.
- Será necesario realizar pruebas adicionales de integración.
- Se deberá validar la comunicación entre Flutter y el backend.

## Impacto en los módulos

La transición afecta principalmente al cliente.

Los módulos del backend mantienen sus responsabilidades:

- Session: gestión de salas, participantes y roles.
- Audio: manejo y transmisión del audio.
- Sync: coordinación de la reproducción.
- Shared: elementos transversales.

## Estado de implementación

La transición se encuentra en proceso.

### Pendiente

- Crear la aplicación Flutter.
- Implementar la interfaz móvil.
- Conectar Flutter con la API.
- Migrar las funcionalidades principales.
- Integrar el flujo de sincronización.
- Realizar pruebas en dispositivos móviles.

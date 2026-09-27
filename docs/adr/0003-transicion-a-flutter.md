# 0003 — Transición del cliente web a aplicación móvil Flutter

- Estado: Aceptado 
- Fecha: 2026-09-20

## Contexto

AudioShare se desarrollaria inicialmente utilizando un cliente web
para interactuar con el backend del sistema.

Durante la evolución del proyecto se decidió orientar el cliente hacia
una aplicación móvil (*Flutter*), con el objetivo de adaptar AudioShare al uso
directo desde dispositivos móviles.

## Alternativas consideradas

### A. Mantener el cliente web (sin migración)
Continuar la implementación del prototipo como aplicación web servida
por el mismo backend Node/Express.
- **A favor:** cero costo de migración; reutiliza `public/` tal como
  estaba; un solo entorno de ejecución para probar.
- **En contra:** el reto que motivó AudioShare (compartir audio entre
  varios dispositivos en una red Wi-Fi local) encaja mejor con un
  cliente instalado en el dispositivo, con acceso a APIs nativas de
  audio y red que un navegador restringe o no expone.
- **Por qué no se eligió:** para demostrar reproducción física
  sincronizada en dispositivos reales (NC-01, NC-02, NC-03 en
  `docs/no_conformidades.md`) se necesita acceso a APIs de audio nativo
  que el cliente web no puede ofrecer sin trabajo adicional
  significativo.

### B. Cliente nativo independiente por plataforma (Android/Kotlin, iOS/Swift)
Dos bases de código nativas, una por plataforma.
- **A favor:** acceso completo a las APIs de audio y red de cada
  plataforma, sin capas de abstracción intermedias.
- **En contra:** duplica el esfuerzo de desarrollo y de pruebas entre
  dos equipos de código distintos; el equipo no tiene experiencia previa
  en desarrollo nativo dual.
- **Por qué no se eligió:** el tamaño del equipo (4 integrantes) y el
  tiempo disponible en el curso no permiten mantener dos bases de código
  nativas en paralelo sin sacrificar avance en el backend.

### C. Flutter (multiplataforma)
Una sola base de código Dart, compilada a Android, iOS y Web.
- **A favor:** un solo código fuente para varias plataformas; acceso a
  plugins de audio y red vía paquetes del ecosistema Flutter; permite
  seguir compilando a Web durante la transición (`flutter build web`)
  sin bloquear las pruebas del corte vertical existente.
- **En contra:** introduce una nueva tecnología (Dart) que el equipo
  debe aprender en paralelo al resto del curso; el rendimiento de audio
  en tiempo real depende de qué tan bien los plugins de Flutter exponen
  las APIs nativas subyacentes.
- **Por qué se eligió:** ofrece el mejor equilibrio entre acceso a
  capacidades nativas de audio y costo de mantener una sola base de
  código, dado el tamaño del equipo y el tiempo restante del curso.

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

La aplicación Flutter ya existe en `lib/` (`Home`, `SessionViewModel`,
`RoomRepository`, `ApiClient`, `SyncService`, `AudioService`) y se
conecta a la API existente del backend; ver la implementación completa
del corte A-01 en `docs/aspectos.md`.

### Pendiente

- Reemplazar `MockAudioService` por captura y transmisión de audio real
  (NC-01, NC-07 en `docs/no_conformidades.md`).
- Consumir el stream NDJSON de eventos de sincronización desde Flutter
  (hoy solo lo expone el backend).
- Reconexión automática del cliente ante caída de red.
- Medición experimental en dispositivos reales de EC-01/EC-02
  (actualmente son objetivos arquitectónicos, no resultados medidos;
  ver `docs/aspectos.md#pruebas`).

## Trazabilidad

- Requisito / aspecto: RF-01 y RF-02 (ver `docs/aspectos.md`), acceso a
  APIs nativas de audio y red desde un cliente instalado en el
  dispositivo.
- Elementos C4 afectados: [C4 Nivel 3 — Componentes](../c4/Componentes%20-%20Nivel%203.mmd),
  que documenta los componentes Flutter (`Home`, `SessionViewModel`,
  `RoomRepository`, `ApiClient`, `SyncService`, `AudioService`).
- Implementación: `lib/app/`, `lib/core/network/`,
  `lib/features/session/`, `lib/features/audio/`, `lib/features/sync/`.
- Pruebas que lo cubren: `test/models_test.dart`,
  `test/view_model_test.dart`, `test/widget_test.dart`.

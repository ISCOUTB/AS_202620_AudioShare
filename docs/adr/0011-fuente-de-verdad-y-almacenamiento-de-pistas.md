# ADR-0011 — Separar estado transaccional y archivos de audio

- **Estado:** Propuesto como línea base de consistencia.
- **Fecha:** 2026-10-25.
- **Contexto:** cliente Flutter, backend Node/Express modular y SQLite.

## Contexto y problema
AudioShare persiste salas, participantes y estado de reproducción, y almacena pistas MP3 que los receptores descargan para reproducir localmente. El estado relacional cambia con frecuencia y necesita transacciones; una pista es un objeto binario grande (el README documenta un límite de 50 MiB). SQLite y el sistema de archivos no comparten una transacción atómica: el archivo y la fila pueden fallar en momentos distintos.

Esta decisión es costosa de revertir porque afecta modelo de datos, endpoints, backups, despliegue, migración y recuperación ante fallos.

## Decisión
1. SQLite es la fuente de verdad para salas, participantes, estado de reproducción y metadatos que asocian una sala con su pista.
2. Los bytes MP3 se guardan como archivos en almacenamiento persistente, con identificadores internos generados por el servidor; nunca se usa el nombre del usuario como ruta.
3. La pista no se declara disponible hasta que la carga está completa, validada y publicada desde un archivo temporal mediante renombrado atómico en el mismo volumen.
4. La API sirve la pista solo después de validar la asociación vigente entre sala y archivo.
5. La caché es derivada y descartable; no es fuente de verdad para reproducción ni permisos.
6. Los eventos de estado se publican tras confirmar la escritura. Tras perder el stream, el cliente recupera un snapshot por API.

## Protocolo propuesto de escritura
1. Validar sala, tipo y tamaño.
2. Escribir a archivo temporal dentro del volumen persistente; comprobar tamaño y, opcionalmente, hash SHA-256.
3. Finalizar y renombrar a una ruta interna versionada.
4. En una transacción SQLite, actualizar metadatos para apuntar al archivo completo.
5. Si falla la transacción, eliminar el archivo nuevo o marcarlo para reconciliación; no publicarlo como pista activa.
6. Tras el commit, limpiar la versión anterior cuando ninguna referencia la utilice.
7. Al arrancar, identificar temporales y archivos no referenciados; aplicar periodo de gracia antes de eliminarlos.

Esto reduce ventanas de inconsistencia, pero no crea una transacción única entre SQLite y el sistema de archivos. La reconciliación y las pruebas de fallo son parte de la solución.

## Alternativas
### A. MP3 como BLOB en SQLite
**Ventajas:** bytes y metadatos podrían confirmarse en la misma transacción; backup unificado.  
**Desventajas:** base de datos más grande, backups/restauraciones pesadas y entrega de archivos grandes menos conveniente.

### B. SQLite para metadatos y archivos persistentes — elegida
**Ventajas:** separa datos transaccionales de binarios, permite servir descargas/Range y evita inflar la base.  
**Desventajas:** requiere publicación ordenada, reconciliación de huérfanos y backups coordinados.

### C. Almacenamiento de objetos externo
**Ventajas:** escalabilidad y separación operativa.  
**Desventajas:** agrega configuración, credenciales, dependencia externa y posible coste; no es necesario para el alcance académico actual.

## Consecuencias
- SQLite es autoridad para estado y metadatos; el archivo es autoridad para los bytes.
- Las copias deben incluir DB y directorio de pistas de forma coherente o usar un procedimiento que valide las referencias restauradas.
- El volumen Docker debe ser persistente; un contenedor efímero no puede ser el único almacenamiento.
- Reemplazar pista creando una versión nueva, no sobrescribiendo bytes que pueden estar descargándose.
- Coordinar eliminación con metadatos y descargas activas; usar borrado diferido si es necesario.
- Una migración futura a object storage debe conservar el contrato API y cambiar la implementación detrás de una interfaz.

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Archivo escrito, transacción falla | Borrar o reconciliar archivo no referenciado |
| Fila apunta a archivo ausente | Comprobación de integridad y restauración desde backup |
| Se pierde el contenedor | Volumen persistente y prueba de reinicio |
| Backup incoherente | Backup coordinado y prueba de restauración |
| Reemplazo durante descarga | Versionar archivos y limpiar de forma diferida |
| Metadatos cacheados obsoletos | Invalidar tras commit, TTL limitado y validación en origen |

## Verificación requerida
- Subir una pista y comparar bytes descargados.
- Simular error de DB después de escribir el archivo y comprobar que no queda activo.
- Reiniciar el contenedor y verificar persistencia.
- Reemplazar pista durante una descarga y verificar versiones completas.
- Restaurar backup y validar todas las referencias.
- Confirmar que play/pause solo publica estado después del commit.

## Relación con otras decisiones
Complementa el monolito modular y ADR-0010 sobre transporte HTTP de una pista MP3. Compartir una pista completa no equivale a capturar y transmitir audio en vivo.

## Estado de evidencia
El README documenta SQLite, data/tracks, endpoints de subida/descarga y prueba de identidad de bytes. Reconciliación de huérfanos, pruebas de fallo, backups coordinados y limpieza segura son requisitos de diseño que deben verificarse antes de declararlos completados.

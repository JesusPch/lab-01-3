## Respuestas a las preguntas

### 1. ¿Por qué `logging_collector` requiere reinicio y `log_statement` solo recarga?
* **`logging_collector` requiere reinicio** porque activa o detiene un proceso dedicado en segundo plano del servidor encargado de capturar toda la salida estándar de error (`stderr`) y redirigirla hacia archivos dentro de `log_directory`. Esta redirigencia de flujos entre el proceso principal y los procesos hijos solo puede establecerse al arrancar el motor.
* **`log_statement` solo requiere recarga** (`SELECT pg_reload_conf()`) porque funciona como una regla o filtro de evaluación en tiempo de ejecución que cada sesión consulta antes de ejecutar una sentencia SQL, permitiendo actualizar su comportamiento sin interrumpir las conexiones activas.

### 2. ¿Qué ventaja tiene que la bitácora se lea con SQL y no con una herramienta del sistema operativo o del contenedor? ¿Qué riesgo introduce?
* **Ventajas:**
  * Es independiente de la plataforma o forma de despliegue (Linux, Windows, macOS o contenedor), sin necesidad de conocer dónde se ubica el archivo en el sistema.
  * Evita requerir acceso o privilegios a nivel de sistema operativo o contenedor para leer archivos que pertenecen al usuario del servicio y tienen permisos restringidos.
  * Permite aprovechar las capacidades de SQL (vistas como `dba.bitacora`, ordenamiento por número de línea con `WITH ORDINALITY`, filtros con `ILIKE` y expresiones regulares `~`) para analizar eventos directamente desde el motor.
* **Riesgos:**
  * Se apoya en la función `pg_read_file()`, la cual permite leer cualquier archivo del servidor al que tenga acceso el proceso de PostgreSQL, por lo que otorgar acceso indebido compromete la confidencialidad del servidor.
  * Expone dentro del entorno SQL el contenido completo de la bitácora, la cual puede incluir contraseñas en texto claro, datos personales dentro de sentencias o rutas internas del sistema.

### 3. ¿Quién debería poder consultar `dba.bitacora`?
* **Únicamente el administrador de la base de datos** (superusuario, como `postgres`) o un rol específico de auditoría y seguridad debidamente autorizado tras un análisis de riesgo.
* El acceso debe permanecer revocado para `PUBLIC` (`REVOKE ALL ON SCHEMA dba FROM PUBLIC`) y negado tanto a aplicaciones (`app_ventas`) como a usuarios de soporte (`soporte_ana`), debido a que la vista utiliza `pg_read_file()` (restringida por defecto a superusuarios) y a que la bitácora puede contener secretos y detalles sensibles de la operación.
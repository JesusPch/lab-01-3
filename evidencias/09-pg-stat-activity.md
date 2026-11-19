## Respuestas a las preguntas

### 1. ¿Qué columna permite relacionar una sesión con sus líneas de bitácora?
La columna **`pid`** (Identificador del proceso del servidor). En la vista `pg_stat_activity` identifica el proceso backend asignado a cada conexión activa, y en la bitácora del servidor aparece entre corchetes (`[%p]`, por ejemplo `[153897]`) gracias al marcador `%p` configurado en `log_line_prefix`, lo que permite agrupar y correlacionar todos los eventos de una misma sesión.

### 2. Después de que termina el reporte, ¿qué fuente conserva evidencia de que existió?
**La bitácora del servidor (`dba.bitacora`)**. La vista `pg_stat_activity` funciona únicamente como una fotografía en tiempo real de los procesos activos en ese momento; en cuanto termina `SELECT pg_sleep(90)` y la sesión de `soporte_ana` (`reporte-mensual`) se desconecta, su fila desaparece de `pg_stat_activity`. En cambio, la bitácora conserva el registro histórico permanente de su conexión, autorización y desconexión (incluyendo la duración de la sesión) bajo el mismo `PID`.

### 3. ¿Por qué `client_addr` aparece vacío en la sesión del administrador?
Cuando el administrador abre su sesión de forma local mediante un **socket de dominio Unix** (por ejemplo, usando `psql` directamente en la terminal del servidor bajo una regla `local` de `pg_hba.conf`), la conexión no viaja por red TCP/IP, por lo que no existe una dirección IP del cliente y PostgreSQL muestra `client_addr` vacío (`NULL`, registrándolo como `client=[local]` en la bitácora).

> **Observación en la captura de pgAdmin 4:** En esta ejecución realizada desde **pgAdmin 4**, la columna `client_addr` de las sesiones de `postgres` muestra `127.0.0.1` porque la herramienta cliente se conecta al servidor mediante red local TCP/IP (*loopback*) en lugar de un socket Unix.
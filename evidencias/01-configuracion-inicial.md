## Respuestas a las preguntas

### 1. Con esta configuración, ¿se registra quién se conecta?
**No.** Los parámetros `log_connections` (sin valor activo, en `default`) y `log_disconnections` (`off`, en `default`) están deshabilitados, por lo que el servidor no deja rastro de los inicios, cierres o intentos fallidos de sesión.

### 2. ¿Se registran las sentencias UPDATE?
**No.** El parámetro `log_statement` tiene el valor `none` (`default`), lo que impide registrar cualquier sentencia SQL ejecutada con éxito (incluidas operaciones `UPDATE`, `INSERT`, `DELETE` o `DDL`). Únicamente se registraría una sentencia si fallara con severidad `error` o superior debido a `log_min_error_statement = error`.

### 3. ¿La línea de bitácora incluye el usuario o la dirección IP del cliente?
**Incluye el usuario, pero no la dirección IP del cliente.** El parámetro `log_line_prefix` está configurado desde el archivo de configuración (`configuration file`) con el valor `%m [%p] %q%u@%d `:
* El marcador `%u` registra el **usuario** de la sesión (y `%d` la base de datos).
* Al faltar el marcador `%h`, **no se registra la dirección IP ni el host del cliente** (tampoco el nombre de la aplicación `%a`).

### 4. ¿En qué zona horaria se registran los eventos? ¿Por qué importa al reconstruir una cronología?
Los eventos se registran en la zona horaria **`America/Mazatlan`** (`source = configuration file`). Conocer y estandarizar la zona horaria es fundamental para correlacionar las marcas de tiempo (`%m`) de PostgreSQL con bitácoras de otros sistemas (sistema operativo, aplicaciones web, firewalls o reportes de usuarios) sin desfases horarios que alteren la secuencia real de un incidente.

### 5. Con `logging_collector = off`, ¿quién decide dónde termina la bitácora: PostgreSQL o el mecanismo con que se desplegó el servidor?
**El mecanismo con que se desplegó el servidor** (el sistema operativo, `systemd` o el motor de contenedores). Con `logging_collector = off`, PostgreSQL envía los mensajes únicamente a la salida estándar de error (`log_destination = stderr`), delegando al entorno de ejecución el destino final donde se almacenan o muestran dichos registros.
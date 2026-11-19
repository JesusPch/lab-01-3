## Respuestas a las preguntas

### 1. ¿Por qué el proceso que registra el cambio es el principal y no tu sesión?
* Al ejecutar `ALTER SYSTEM`, la sesión únicamente escribe los nuevos parámetros en el archivo `postgresql.auto.conf` dentro del directorio de datos, sin aplicarlos todavía en memoria.
* Posteriormente, `SELECT pg_reload_conf()` envía una señal asíncrona al **proceso principal del servidor** (por ejemplo, PID 1) para que vuelva a leer los archivos de configuración y propague los cambios a todo el motor.
* Es ese proceso principal quien detecta la diferencia entre la configuración anterior y la nueva al recargar, registrando las líneas `LOG: parameter "..." changed to "..."` bajo su propio PID (sin usuario, base de datos ni IP de cliente asociados).

### 2. ¿Qué pasaría si alguien ejecutara `ALTER SYSTEM SET log_statement = 'none'`? ¿Quedaría rastro?
* **Sí quedaría rastro en la bitácora**, en dos momentos distintos según el nivel previo:
  * **Al ejecutar la sentencia:** Si `log_statement` estaba configurado previamente en `'ddl'` o `'mod'`, PostgreSQL registra la propia instrucción antes de aplicarla (`LOG: statement: ALTER SYSTEM SET log_statement = 'none'`), dejando constancia de qué usuario y desde qué cliente se solicitó el cambio.
  * **Al recargar o reiniciar el servidor:** Al ejecutar `SELECT pg_reload_conf()` (o reiniciar el servicio), el proceso principal escribe `LOG: parameter "log_statement" changed to "none"`, evidenciando que se desactivó el registro de sentencias.
* **Efecto posterior:** Una vez aplicada la recarga, dejarán de registrarse las sentencias SQL ejecutadas con éxito (`DDL`, `INSERT`, `UPDATE`, `DELETE`, `SELECT`), aunque seguirán registrándose las conexiones/desconexiones (si permanecen en `on`) y las sentencias que generen errores (debido a `log_min_error_statement = error`).

### 3. ¿Por qué no se recomienda editar `postgresql.auto.conf` a mano?
* **Validación de sintaxis y valores:** `ALTER SYSTEM` verifica que el parámetro y su valor sean válidos antes de escribirlos; editar el archivo manualmente puede introducir errores de sintaxis que impidan recargar la configuración o arrancar el servidor.
* **Sobrescritura automática:** Este archivo es administrado por el motor de PostgreSQL, por lo que cualquier ejecución futura de `ALTER SYSTEM` reescribe su contenido y puede alterar o perder cambios hechos manualmente.
* **Independencia del despliegue:** `ALTER SYSTEM` funciona igual en cualquier entorno (instalación nativa, máquina virtual o contenedor) sin necesidad de localizar la ruta física del directorio de datos ni requerir permisos de edición en el sistema operativo.



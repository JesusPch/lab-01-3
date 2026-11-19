## Respuestas a las preguntas

### 1. La bitácora registra el usuario `app_ventas` en el intento fallido. ¿Eso prueba que la aplicación de ventas intentó entrar? ¿Qué prueba realmente?
* **No prueba que haya sido la aplicación legítima de ventas.** Cualquier persona, herramienta o script que conozca o adivine el nombre del rol (`app_ventas`) puede intentar abrir una conexión declarando ese usuario.
* **Lo que realmente prueba** es que *un cliente* ubicado en la dirección IP registrada (`client=127.0.0.1`) intentó conectarse a la base de datos `comercial` solicitando autenticarse como el rol `app_ventas`, coincidió con la regla `scram-sha-256` de `pg_hba.conf` (línea 119) y fue rechazado al proporcionar una contraseña incorrecta.

### 2. ¿Qué información adicional registra PostgreSQL cuando el rol no existe? ¿Por qué aparece en la bitácora y no en el mensaje que recibe el cliente?
* **Información adicional en la bitácora:** PostgreSQL añade una línea de detalle (`DETAIL`) inmediatamente después del error indicando el motivo exacto del rechazo:
  `DETAIL: Role "usuario_inexistente" does not exist.`
* **Por qué no se envía al cliente:** Es una medida de seguridad para evitar la **enumeración de usuarios**. Al responderle al cliente con el mismo mensaje genérico (`FATAL: password authentication failed`) tanto si el usuario existe como si no, se impide que un atacante descubra qué nombres de roles son válidos en el servidor. En cambio, en la bitácora interna sí se registra el detalle para que el administrador pueda distinguir entre un error de contraseña de un usuario legítimo y un sondeo de usuarios inexistentes.

### 3. ¿Por qué `app=[unknown]` en el intento fallido, pero `app=app-ventas-web` en la desconexión?
* Durante el proceso de negociación de una conexión en PostgreSQL, primero se valida la autenticación (`pg_hba.conf` y contraseña) y solo **después** de que la sesión es autorizada (`connection authorized`) el servidor inicializa el estado interno de la sesión y asigna el valor recibido en `application_name`.
* Como el intento fallido se aborta con `FATAL` durante la fase de autenticación, el parámetro `application_name` aún no se ha establecido en el proceso del servidor, por lo que el marcador `%a` muestra `[unknown]`. En la conexión exitosa, una vez autorizada la sesión, el nombre queda registrado y aparece en eventos posteriores como la desconexión (`app=app-ventas-web`).

### 4. ¿Qué patrón de varias líneas te haría sospechar de un ataque de fuerza bruta? Escribe la consulta que contaría los intentos fallidos por usuario.
* **Patrón sospechoso:** Múltiples registros consecutivos o muy frecuentes de `FATAL: password authentication failed` en un intervalo corto (segundos o pocos minutos) provenientes de una misma dirección IP (`client=...`) —o de varias IP—, ya sea probando distintas contraseñas repetidamente contra un mismo rol válido o probando distintos nombres de usuario acompañados de líneas `DETAIL: Role "..." does not exist`.
* **Consulta SQL sobre `dba.bitacora`:**

```sql
SELECT substring(linea FROM 'FATAL: password authentication failed for user "([^"]+)"') AS usuario,
       count(*) AS intentos_fallidos
FROM dba.bitacora
WHERE linea LIKE '%FATAL: password authentication failed%'
GROUP BY usuario
ORDER BY intentos_fallidos DESC;
# Sistema de Seguridad, Monitoreo y Auditoría en PostgreSQL

## 1. Descripción General del Proyecto

Este proyecto implementa una arquitectura de **defensa en profundidad** sobre la base de datos `comercial` en PostgreSQL. Su objetivo es complementar los mecanismos preventivos de control de acceso (gestión de roles, privilegios y secretos) con controles detectivos y forenses mediante **auditoría a nivel de sesión, sentencia y dato**.

### Objetivos Principales
* **Trazabilidad y Rendición de Cuentas:** Registrar conexiones, desconexiones, cambios de configuración y modificaciones críticas de información.
* **Integridad y Recuperación ante Incidentes:** Conservar el estado histórico completo de los registros antes y después de cada modificación para permitir reversiones exactas.
* **Protección de Información Sensible (PII):** Asegurar el resguardo de datos personales (como el RFC) y credenciales tanto en las tablas del negocio como en los archivos de bitácora.

---

## 2. Arquitectura de Roles, Privilegios y Gestión de Secretos

El modelo de seguridad separa estrictamente las responsabilidades administrativas, operativas y de consulta bajo el principio de mínimo privilegio.

### 2.1. Matriz de Roles

| Rol | Tipo | Privilegios sobre `public.clientes` | Acceso a `dba` y `auditoria` | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| **`postgres`** | Superusuario / DBA | Control total (`ALL`) | Control total y lectura de bitácoras | Administración del motor, configuración y auditoría forense. |
| **`app_ventas`** | Aplicación | `SELECT`, `INSERT`, `UPDATE` | **Denegado** (`REVOKE ALL`) | Operación transaccional de la aplicación de ventas (`app-ventas-web`). |
| **`soporte_ana`** | Usuario operativo | Solo lectura (`SELECT`) | **Denegado** (`REVOKE ALL`) | Consultas de soporte y generación de reportes (`reporte-mensual`). |

### 2.2. Políticas de Gestión de Secretos
* **Autenticación:** Configurada mediante `scram-sha-256` en `pg_hba.conf`.
* **Prevención de Exposición en Bitácoras:** Queda prohibido asignar contraseñas mediante literales en sentencias SQL (ej. `CREATE ROLE ... PASSWORD '...'`), ya que el texto claro queda persistido en los archivos de bitácora incluso si el rol se elimina posteriormente.
* **Mecanismos Autorizados:** Uso exclusivo del metacomando `\password` en `psql` (que calcula el hash `SCRAM-SHA-256` en el cliente), archivos `.pgpass` con permisos restringidos o gestores de secretos externos.
* **Sanitización:** Cualquier exportación o compartición de bitácoras requiere una revisión previa para enmascarar credenciales o datos sensibles con la etiqueta `<REDACTED>`.

---

## 3. Auditoría del Servidor (Nivel de Sesión y Sentencia)

La configuración de bitácoras del motor se gestiona exclusivamente mediante `ALTER SYSTEM` y se aplica con `SELECT pg_reload_conf()` (evitando la edición manual de `postgresql.auto.conf` para garantizar validación sintáctica y persistencia).

### 3.1. Parámetros Críticos de Configuración

| Parámetro | Valor Recomendado | Aplicación | Función Técnica |
| :--- | :--- | :--- | :--- |
| **`logging_collector`** | `on` | **Reinicio** | Activa el proceso en segundo plano que captura `stderr` y lo escribe en archivos rotativos en `log_directory`. |
| **`log_connections`** | `on` | Recarga | Registra cada intento de inicio de sesión y su autorización exitosa. |
| **`log_disconnections`** | `on` | Recarga | Registra el cierre de cada sesión junto con su duración total. |
| **`log_line_prefix`** | `'%m [%p] %q%u@%d app=%a client=%h '` | Recarga | Estandariza cada línea con marca de tiempo (`%m`), PID (`%p`), usuario (`%u`), base de datos (`%d`), aplicación (`%a`) e IP del cliente (`%h`). |
| **`log_statement`** | `'ddl'` o `'mod'` | Recarga | `'ddl'` audita cambios de esquema y permisos (`GRANT`/`REVOKE`); `'mod'` añade escrituras (`INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`). |
| **`log_min_error_statement`** | `'error'` | Recarga | Registra cualquier sentencia SQL que falle con severidad `ERROR` o superior. |
| **`timezone`** | `'America/Mazatlan'` | Recarga | Sincroniza las marcas de tiempo para correlación forense con otros sistemas. |

> **Nota de Rendimiento:** Se evita el uso de `log_statement = 'all'` en producción debido al alto impacto en operaciones de entrada/salida (I/O), crecimiento acelerado de almacenamiento, ruido operativo y exposición masiva de consultas `SELECT` con filtros confidenciales.

---

## 4. Esquema `dba`: Consulta SQL de Bitácoras

Para analizar la bitácora del servidor sin depender de acceso al sistema operativo o al contenedor, se implementa una vista SQL controlada dentro del esquema privado `dba`.

### 4.1. Diseño y Control de Acceso
* **Implementación:** La vista `dba.bitacora` utiliza la función `pg_read_file()` combinada con `WITH ORDINALITY` para numerar y consultar líneas de registro mediante filtros SQL (`ILIKE`, expresiones regulares `~`).
* **Seguridad:**
  * Privilegios revocados para `PUBLIC` (`REVOKE ALL ON SCHEMA dba FROM PUBLIC`).
  * Acceso exclusivo para `postgres` o roles de auditoría autorizados, mitigando el riesgo de lectura arbitraria de archivos del sistema operativo a través de `pg_read_file()`.

---

## 5. Esquema `auditoria`: Auditoría a Nivel de Dato

Dado que `log_statement = 'mod'` solo registra la sentencia ejecutada pero no el estado previo de los datos, se implementa una auditoría granular mediante disparadores (`TRIGGER`) sobre las tablas críticas.

### 5.1. Tabla `auditoria.cambios_clientes`
Almacena el historial inmutable de cambios realizados sobre `public.clientes`:
* **`id_evento`**: Identificador secuencial del evento de auditoría.
* **`id_cliente`**: Referencia al registro afectado.
* **`momento` (`TIMESTAMPTZ`)**: Marca de tiempo absoluta almacenada en UTC para evitar ambigüedades por cambios de horario o migraciones.
* **`usuario_efectivo` (`current_user`)**: Rol bajo cuyos privilegios se ejecuta el disparador (`postgres`).
* **`usuario_sesion` (`session_user`)**: Rol autenticado que originó la transacción (ej. `app_ventas`).
* **`valores_antes` (`JSONB`)**: Snapshot completo de la fila anterior (`to_jsonb(OLD)`).
* **`valores_despues` (`JSONB`)**: Snapshot completo de la fila resultante (`to_jsonb(NEW)`).

### 5.2. Mecanismo `SECURITY DEFINER`
La función disparadora se define con la cláusula **`SECURITY DEFINER`** y propiedad de `postgres`. Esto permite que roles operativos como `app_ventas` puedan ejecutar operaciones `UPDATE` o `DELETE` sobre `clientes` —disparando la inserción automática en `auditoria.cambios_clientes`— sin otorgarles permisos directos de lectura, escritura o borrado sobre el esquema `auditoria`.

### 5.3. Clasificación de Datos
Al contener copias completas de registros con Información de Identificación Personal (PII) como RFC, correo y teléfono, `auditoria.cambios_clientes` hereda la clasificación de **Información Confidencial / Restringida**, prohibiendo cualquier operación `UPDATE` o `DELETE` sobre ella por parte de usuarios operativos.

---

## 6. Procedimientos Operativos y Forenses

### 6.1. Correlación de Sesiones Activas e Históricas
* **En tiempo real:** Se consulta `pg_stat_activity` para observar procesos activos (`pid`, `usename`, `application_name`, `client_addr`). Nota: las conexiones vía socket Unix muestran `client_addr` vacío (`[local]`), mientras que clientes TCP/IP locales (como pgAdmin 4) muestran `127.0.0.1`.
* **Post-mortem:** Una vez cerrada la sesión, su registro desaparece de `pg_stat_activity`, pero puede reconstruirse íntegramente en `dba.bitacora` filtrando por el identificador de proceso entre corchetes (`[pid]`).

### 6.2. Detección de Intentos de Fuerza Bruta
PostgreSQL protege contra la enumeración de usuarios enviando un error genérico al cliente (`FATAL: password authentication failed`), mientras registra en la bitácora interna si el rol existe o no (`DETAIL: Role "..." does not exist`) con `app=[unknown]` (ya que el nombre de aplicación se asigna tras la autenticación).

Para auditar intentos fallidos agrupados por usuario desde SQL:

```sql
SELECT substring(linea FROM 'FATAL: password authentication failed for user "([^"]+)"') AS usuario,
       count(*) AS intentos_fallidos
FROM dba.bitacora
WHERE linea LIKE '%FATAL: password authentication failed%'
GROUP BY usuario
ORDER BY intentos_fallidos DESC;
```

### 6.3. Reversión de Cambios (Rollback Forense)
Ante una modificación indebida o accidental sobre `public.clientes`, se consulta el campo `valores_antes` en `auditoria.cambios_clientes` para obtener el valor íntegro previo al incidente y restaurarlo mediante una sentencia controlada:

```sql
-- Ejemplo de restauración basada en el registro de auditoría (id_evento = 1)
UPDATE clientes
SET rfc = 'GAMA780912XYZ'
WHERE id = 3;
```
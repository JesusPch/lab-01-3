## Respuestas a las preguntas

### 1. ¿Puedes demostrar quién modificó el RFC?
**No.** Al consultar `dba.bitacora` no aparece ningún registro (`0 rows`) de la conexión ni de la sentencia `UPDATE`, debido a que `log_connections` estaba desactivado (`off`) y `log_statement` estaba en `none`. Aunque se sabe qué roles tienen permisos sobre la tabla (`postgres` y `app_ventas`), sin registros históricos en la bitácora no existe evidencia técnica para demostrar quién ejecutó realmente el cambio.

### 2. ¿Puedes demostrar que el cambio no lo hizo `soporte_ana`?
**No de forma concluyente mediante evidencia histórica.** Si bien en la configuración actual de privilegios `soporte_ana` únicamente tiene permiso de lectura (`SELECT`) sobre `clientes` —lo que le impediría ejecutar un `UPDATE` directamente—, el control de acceso solo refleja lo que está permitido en el presente, no lo que ocurrió en el pasado. Al no haber bitácora de conexiones ni de sentencias `DDL` (`GRANT` / `REVOKE`), es imposible demostrar con evidencia que no se le otorgaron permisos temporalmente para realizar la modificación y se le revocaron después.

### 3. Los privilegios de la Unidad II, ¿impidieron el cambio? ¿Debían impedirlo?
**No lo impidieron, y tampoco debían impedirlo.** El rol `app_ventas` requiere el privilegio `UPDATE` sobre la tabla `clientes` para cumplir con la operación normal del negocio. El control de acceso (Unidad II) actúa de forma preventiva antes de la operación para bloquear accesos no autorizados, pero no puede evitar errores operativos ni usos indebidos cometidos por un rol que sí tiene permisos legítimos; para eso es indispensable la auditoría (Unidad III).

### 4. ¿Qué tendría que haber estado configurado antes del incidente?
Dado que la auditoría no es retroactiva y lo que no se registra en su momento no puede reconstruirse, antes del incidente debieron estar activos los siguientes mecanismos:
* **Colector de bitácora:** `logging_collector = on` (con el servicio previamente reiniciado) para almacenar los eventos en archivos controlados por PostgreSQL.
* **Registro de sesiones:** `log_connections = on` y `log_disconnections = on` para dejar rastro de quién se conectó y desconectó.
* **Prefijo de línea completo (`log_line_prefix`):** Configurado con marcadores de fecha/hora (`%m`), PID (`%p`), usuario (`%u`), base de datos (`%d`), aplicación (`%a`) y dirección IP del cliente (`%h`).
* **Registro de modificaciones SQL:** `log_statement = 'mod'` (o `'all'`) para que quedara escrita la sentencia `UPDATE` ejecutada.
* **Auditoría a nivel de dato (Parte B):** Una tabla de auditoría con un disparador (`TRIGGER`) sobre `clientes` para conservar no solo la sentencia, sino también el valor anterior del RFC antes de ser sobrescrito.
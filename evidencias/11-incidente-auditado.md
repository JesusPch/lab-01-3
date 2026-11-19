## Respuestas a las preguntas - Actividad 12

### 1. Compara tu hipótesis de la Actividad 11 con este resultado.
* **Confirmación de la hipótesis:** El resultado comprueba exactamente lo planteado en la Actividad 11. Cuando `app_ventas` intentó consultar directamente la tabla de auditoría (`SELECT * FROM auditoria.cambios_clientes`), PostgreSQL rechazó la operación con `ERROR: permission denied for schema auditoria`, demostrando que dicho rol carece por completo de privilegios sobre el esquema y la tabla de auditoría.
* **Funcionamiento de `SECURITY DEFINER`:** A pesar de no tener permisos sobre `auditoria`, el `UPDATE` ejecutado por `app_ventas` se completó (`UPDATE 1`) y generó el registro en `auditoria.cambios_clientes` porque la función disparadora fue creada con `SECURITY DEFINER`. Esto se confirma en las columnas del registro resultante: `usuario_efectivo` muestra `postgres` (el propietario cuyos privilegios permitieron insertar en la auditoría), mientras que `usuario_sesion` (`session_user`) conserva `app_ventas` como responsable real de la modificación. Si la función no hubiera sido `SECURITY DEFINER`, el disparador habría fallado con el mismo error de permisos y habría revertido toda la transacción del `UPDATE`.

### 2. Escribe la sentencia `UPDATE` que restauraría el valor anterior.
De acuerdo con la consulta sobre `auditoria.cambios_clientes` (`id_evento = 1`, `id_cliente = 3`), el valor registrado en `valores_antes` para el campo `rfc` era `'GAMA780912XYZ'`. La sentencia para revertir este cambio es:

```sql
UPDATE clientes
SET rfc = 'GAMA780912XYZ'
WHERE id = 3;
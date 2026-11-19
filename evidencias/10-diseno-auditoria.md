## Respuestas a las preguntas

### 1. ¿Por qué `momento` usa `TIMESTAMPTZ` y no `TIMESTAMP`?
* `TIMESTAMPTZ` (`TIMESTAMP WITH TIME ZONE`) almacena el instante exacto de forma absoluta (internamente en UTC) y lo convierte automáticamente al huso horario de la sesión o del servidor al consultarlo.
* En cambio, `TIMESTAMP` (`WITHOUT TIME ZONE`) guarda únicamente la fecha y la hora sin referencia de zona horaria. Usar `TIMESTAMPTZ` evita desfases o ambigüedades si el servidor cambia de configuración horaria, se migra a otra región o si se necesita correlacionar la auditoría con bitácoras de otros sistemas o servidores que operan en distintas zonas horarias.

### 2. ¿Por qué se guarda el registro completo en `JSONB` y no solo la columna que cambió?
* **Tolerancia a cambios de esquema (evolución de estructura):** Al convertir la fila completa mediante `to_jsonb(OLD)` y `to_jsonb(NEW)`, la tabla de auditoría conserva el estado íntegro del registro sin depender de una estructura fija de columnas. Si en el futuro se agregan, renombran o eliminan columnas en `clientes` (como al añadir `segmento`), ni el disparador ni los registros históricos se rompen.
* **Contexto completo en altas y bajas:** En operaciones `INSERT` o `DELETE` no cambia una sola columna, sino el registro entero; guardar toda la fila en `JSONB` permite reconstruir exactamente cómo era un cliente antes de ser eliminado o con qué datos fue creado.
* **Comparación dinámica:** El formato binario `JSONB` permite comparar clave por clave (`jsonb_each` e `IS DISTINCT FROM`) para identificar cualquier campo alterado sin tener que reescribir la función del disparador ante cambios en la tabla.

### 3. La tabla de auditoría también contendrá RFC. ¿Qué implica eso para su clasificación y su control de acceso?
* **Clasificación de la información:** Al almacenar copias completas de los registros antes y después de cada cambio, `auditoria.cambios_clientes` contiene Datos Personales / Información de Identificación Personal (PII) como el RFC, nombre, correo y teléfono. Por ello, hereda el mismo nivel de confidencialidad que la tabla `clientes` y debe clasificarse como **información confidencial / restringida**.
* **Control de acceso y ciclo de vida:**
  * **Acceso estrictamente restringido:** El acceso al esquema `auditoria` debe permanecer revocado para `PUBLIC` y denegado a usuarios operativos o aplicaciones (`app_ventas`, `soporte_ana`), limitando su consulta únicamente al DBA o a roles autorizados de auditoría.
  * **Protección contra alteración y retención:** Ningún usuario operativo debe poder modificar o eliminar registros de auditoría para evitar la destrucción de evidencia; además, su depuración debe regirse por políticas formales que equilibren la conservación de pruebas con la retención de datos personales.
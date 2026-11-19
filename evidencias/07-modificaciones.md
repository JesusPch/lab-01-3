## Respuestas a las preguntas

### 1. ¿Qué nivel habría registrado la lectura del RFC? ¿Qué costo tendría en un servidor con miles de consultas por minuto?
* **Nivel requerido:** `log_statement = 'all'`. A diferencia de `'mod'` (que solo registra sentencias `DDL` y operaciones de escritura `INSERT`, `UPDATE`, `DELETE` y `TRUNCATE`), el nivel `'all'` registra absolutamente todas las sentencias SQL ejecutadas, incluidas las consultas de lectura `SELECT`.
* **Costo en un servidor con alta carga (miles de consultas por minuto):**
  * **Volumen y almacenamiento:** Generaría un crecimiento acelerado en el tamaño de los archivos de bitácora, disparando el costo de almacenamiento en disco y provocando rotaciones constantes que pueden sobrescribir o desplazar evidencia importante si no se respalda a tiempo.
  * **Impacto en el desempeño:** Escribir miles de líneas por minuto en disco incrementa la carga de entrada/salida (I/O) del servidor, lo que puede degradar el tiempo de respuesta de la base de datos.
  * **Dificultad de análisis:** La evidencia relevante de seguridad quedaría oculta entre millones de consultas rutinarias, complicando su lectura e investigación.
  * **Exposición de datos sensibles:** Al registrar todas las consultas y sus parámetros literales, la bitácora se convierte en un nuevo depósito masivo de información confidencial (datos personales, filtros de búsqueda, etc.) que exige controles estrictos de acceso y depuración.

### 2. ¿Qué le falta a esta bitácora para revertir el cambio con certeza? (Lo resolverás en la Parte B.)
* **Le falta el valor anterior del dato (estado previo al cambio).** Como `log_statement = 'mod'` realiza una auditoría a **nivel de sentencia**, la bitácora únicamente guarda el texto SQL que se ejecutó (`UPDATE clientes SET telefono = '6679990000' WHERE id = 3`), mostrando el valor nuevo que se escribió pero no qué teléfono tenía registrado el cliente antes de la modificación.
* Además, si una sentencia `UPDATE` o `DELETE` afecta múltiples filas (por ejemplo, al omitir la cláusula `WHERE`), la bitácora solo registra una línea con la instrucción SQL sin detallar cada registro alterado individualmente. Para revertir un cambio con total certeza se requiere **auditoría a nivel de dato** mediante un disparador (`TRIGGER`) que capture el registro completo anterior (`OLD`) en una tabla de auditoría antes de ser sobrescrito.
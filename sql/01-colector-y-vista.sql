SELECT version();

SHOW data_directory;

SHOW config_file;

SHOW hba_file;

SELECT line_number, type, database, user_name, address, auth_method
FROM pg_hba_file_rules
WHERE database = '{all}';


CREATE ROLE app_ventas LOGIN;

CREATE ROLE soporte_ana LOGIN;

GRANT SELECT, UPDATE ON clientes TO app_ventas;

GRANT SELECT ON clientes TO soporte_ana;

SELECT name, setting, source FROM pg_settings
WHERE name IN ('log_destination', 'logging_collector', 'log_directory',
'log_filename','log_connections','log_disconnections','log_line_prefix',
'log_statement', 'log_min_error_statement', 'log_timezone') ORDER BY name;

ALTER SYSTEM SET logging_collector = on;

SELECT name, setting, pending_restart FROM pg_settings
WHERE name = 'logging_collector';

SELECT name, setting, pending_restart
FROM pg_settings
WHERE name = 'logging_collector';

SELECT name, setting, source FROM pg_settings
WHERE name = 'logging_collector';

SELECT pg_current_logfile();

SELECT linea
FROM regexp_split_to_table(pg_read_file(pg_current_logfile()),
E'\n') AS linea;

CREATE SCHEMA dba;

REVOKE ALL ON SCHEMA dba FROM PUBLIC;

CREATE VIEW dba.bitacora AS
SELECT t.n AS num, t.linea
FROM regexp_split_to_table(pg_read_file(pg_current_logfile()), E'\n')
     WITH ORDINALITY AS t(linea, n)
WHERE t.linea <> '';

SELECT num, linea FROM dba.bitacora ORDER BY num DESC LIMIT 10;

SELECT linea FROM dba.bitacora WHERE linea ILIKE '%update%';

SELECT linea FROM dba.bitacora WHERE linea ~ '(FATAL|ERROR)';
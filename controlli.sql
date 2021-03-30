SET search_path TO bancadeltempo;
SET search_path TO information_schema;


SELECT relname, relfilenode, relpages, reltuples
FROM pg_class
JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
WHERE pg_namespace.nspname = 'bancadeltempo';

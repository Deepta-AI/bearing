-- schema-snapshot.sql: one sorted line per schema object, for make
-- migrate-verify to diff before and after a Down. Schema only, never rows.
-- Covers tables and columns, indexes, constraints, enums, views, triggers and
-- row-level security policies outside the system schemas.
SELECT line FROM (
  SELECT 'column ' || table_schema || '.' || table_name || '.' || column_name || ' ' || data_type
         || ' null=' || is_nullable || ' default=' || coalesce(column_default, '') AS line
    FROM information_schema.columns
   WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
  UNION ALL
  SELECT 'index ' || schemaname || ' ' || indexdef
    FROM pg_indexes
   WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  UNION ALL
  SELECT 'constraint ' || c.conrelid::regclass::text || ' ' || c.conname || ' ' || pg_get_constraintdef(c.oid)
    FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace
   WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  UNION ALL
  SELECT 'enum ' || t.typname || ' ' || string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder)
    FROM pg_type t JOIN pg_enum e ON e.enumtypid = t.oid
   GROUP BY t.typname
  UNION ALL
  SELECT 'view ' || table_schema || '.' || table_name
    FROM information_schema.views
   WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
  UNION ALL
  SELECT 'trigger ' || event_object_table || '.' || trigger_name || ' ' || event_manipulation || ' ' || action_timing
    FROM information_schema.triggers
  UNION ALL
  SELECT 'policy ' || schemaname || '.' || tablename || '.' || policyname || ' ' || cmd || ' ' || coalesce(qual, '')
    FROM pg_policies
) objects
ORDER BY line;

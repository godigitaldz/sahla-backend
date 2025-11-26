const { Client } = require('pg');

const CONNECTION_STRING = process.env.DB_URL || 'postgresql://postgres.wtowqpejzxlsmgywkjvn:Khazani05102002@aws-1-us-east-2.pooler.supabase.com:6543/postgres';

const SQL = `
-- Ensure required extension for UUID generation
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Registry of logical attributes mapped to physical sources
CREATE TABLE IF NOT EXISTS public.info_registry (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  namespace text NOT NULL,
  entity text NOT NULL,
  attribute text NOT NULL,
  priority integer NOT NULL DEFAULT 100,
  source_type text NOT NULL CHECK (source_type IN ('table','view','function','expression','constant')),
  source_schema text NOT NULL DEFAULT 'public',
  source_ref text NOT NULL,
  source_column text,
  id_column text NOT NULL DEFAULT 'id',
  transform_sql text,
  is_active boolean NOT NULL DEFAULT true,
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,
  notes text
);

-- Partial index without non-immutable function calls
CREATE INDEX IF NOT EXISTS idx_info_registry_lookup
  ON public.info_registry(namespace, entity, attribute, priority)
  WHERE is_active AND valid_to IS NULL;

-- Emulate uniqueness with index (used in ON CONFLICT below)
CREATE UNIQUE INDEX IF NOT EXISTS uq_info_registry_key
  ON public.info_registry(namespace, entity, attribute, priority);

-- Aliases to canonical attributes
CREATE TABLE IF NOT EXISTS public.info_alias (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  namespace text NOT NULL,
  entity text NOT NULL,
  alias text NOT NULL,
  attribute text NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_info_alias
  ON public.info_alias(namespace, entity, alias);

-- Active view
CREATE OR REPLACE VIEW public.info_registry_active AS
SELECT *
FROM public.info_registry
WHERE is_active AND (valid_to IS NULL OR valid_to > now());

-- Resolve alias if present
CREATE OR REPLACE FUNCTION public._resolve_attribute(p_namespace text, p_entity text, p_attr text)
RETURNS text LANGUAGE sql STABLE AS $$
  SELECT COALESCE(
    (SELECT attribute FROM public.info_alias a
      WHERE a.namespace = p_namespace AND a.entity = p_entity AND a.alias = p_attr),
    p_attr
  );
$$;

-- Get single attribute value (first non-null by priority)
CREATE OR REPLACE FUNCTION public.get_info(
  p_namespace text,
  p_entity text,
  p_entity_id uuid,
  p_attribute text
) RETURNS text LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_attr text := public._resolve_attribute(p_namespace, p_entity, p_attribute);
  v_rec record;
  v_sql text;
  v_val text;
BEGIN
  FOR v_rec IN
    SELECT * FROM public.info_registry_active r
    WHERE r.namespace = p_namespace
      AND r.entity = p_entity
      AND r.attribute = v_attr
    ORDER BY r.priority ASC
  LOOP
    IF v_rec.source_type IN ('table','view') THEN
      -- Build a safe select using identifiers
      IF v_rec.transform_sql IS NULL OR v_rec.transform_sql = '' THEN
        v_sql := format('select %I from %I.%I where %I = $1 limit 1',
                        v_rec.source_column, v_rec.source_schema, v_rec.source_ref, v_rec.id_column);
      ELSE
        -- Allow simple transform with placeholder {col}
        v_sql := format('select (%s) from %I.%I where %I = $1 limit 1',
                        replace(v_rec.transform_sql, '{col}', format('%I', v_rec.source_column)),
                        v_rec.source_schema, v_rec.source_ref, v_rec.id_column);
      END IF;
      EXECUTE v_sql USING p_entity_id INTO v_val;
      IF v_val IS NOT NULL THEN
        RETURN v_val;
      END IF;
    ELSIF v_rec.source_type = 'constant' THEN
      RETURN v_rec.source_ref; -- literal
    ELSE
      -- function/expression not implemented in v1
      CONTINUE;
    END IF;
  END LOOP;
  RETURN NULL;
END;
$$;

-- Get all attributes for an entity as JSON
CREATE OR REPLACE FUNCTION public.get_entity_info(
  p_namespace text,
  p_entity text,
  p_entity_id uuid
) RETURNS jsonb LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_attrs text[];
  v_attr text;
  v_val text;
  v_json jsonb := '{}'::jsonb;
BEGIN
  SELECT array_agg(DISTINCT attribute ORDER BY attribute)
  INTO v_attrs
  FROM public.info_registry_active
  WHERE namespace = p_namespace AND entity = p_entity;

  IF v_attrs IS NULL THEN
    RETURN v_json;
  END IF;

  FOREACH v_attr IN ARRAY v_attrs LOOP
    v_val := public.get_info(p_namespace, p_entity, p_entity_id, v_attr);
    IF v_val IS NOT NULL THEN
      v_json := v_json || jsonb_build_object(v_attr, v_val);
    END IF;
  END LOOP;

  RETURN v_json;
END;
$$;

-- Seed minimal mappings (idempotent via ON CONFLICT)
INSERT INTO public.info_registry(namespace, entity, attribute, priority, source_type, source_schema, source_ref, source_column, id_column, notes)
VALUES
  ('lo9ma','restaurant','name',10,'table','public','restaurants','name','id','canonical name'),
  ('lo9ma','restaurant','city',10,'table','public','restaurants','city','id','city'),
  ('lo9ma','restaurant','is_open',10,'table','public','restaurants','is_open','id','open flag'),
  ('lo9ma','restaurant','rating',10,'table','public','restaurants','rating','id','rating'),
  ('lo9ma','restaurant','logo_url',10,'table','public','restaurants','logo_url','id','logo url'),
  ('lo9ma','user','name',10,'table','public','user_profiles','name','id','user name'),
  ('lo9ma','user','phone',10,'table','public','user_profiles','phone','id','user phone'),
  ('lo9ma','order','order_number',10,'table','public','orders','order_number','id','order number'),
  ('lo9ma','order','status',10,'table','public','orders','status','id','order status'),
  ('lo9ma','order','total_amount',10,'table','public','orders','total_amount','id','total amount')
ON CONFLICT (namespace, entity, attribute, priority) DO NOTHING;
`;

async function main() {
  const client = new Client({ connectionString: CONNECTION_STRING, ssl: { rejectUnauthorized: false } });
  await client.connect();
  await client.query('BEGIN');
  try {
    await client.query(SQL);
    await client.query('COMMIT');
    console.log('Applied info registry successfully.');
  } catch (e) {
    await client.query('ROLLBACK');
    console.error('Apply failed:', e.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();



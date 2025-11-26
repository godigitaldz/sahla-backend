/* Read-only schema inventory for Supabase Postgres */
const { Client } = require('pg');

// Connection string provided by user (read-only queries only)
const CONNECTION_STRING = process.env.DB_URL || 'postgresql://postgres.wtowqpejzxlsmgywkjvn:Khazani05102002@aws-1-us-east-2.pooler.supabase.com:6543/postgres';

async function run() {
  const client = new Client({
    connectionString: CONNECTION_STRING,
    ssl: { rejectUnauthorized: false },
  });
  await client.connect();

  const q = async (name, sql) => {
    const res = await client.query(sql);
    return { name, rows: res.rows };
  };

  const queries = [
    q('db_info', `
      select current_database() as db,
             current_schema() as schema,
             version();
    `),
    q('tables', `
      select table_name
      from information_schema.tables
      where table_schema = 'public' and table_type = 'BASE TABLE'
      order by table_name;
    `),
    q('views', `
      select table_name as view_name
      from information_schema.views
      where table_schema = 'public'
      order by table_name;
    `),
    q('columns', `
      select table_name, column_name, data_type, is_nullable, column_default
      from information_schema.columns
      where table_schema = 'public'
      order by table_name, ordinal_position;
    `),
    q('primary_keys', `
      select tc.table_name, kcu.column_name
      from information_schema.table_constraints tc
      join information_schema.key_column_usage kcu
        on tc.constraint_name = kcu.constraint_name and tc.table_schema = kcu.table_schema
      where tc.constraint_type = 'PRIMARY KEY' and tc.table_schema = 'public'
      order by tc.table_name, kcu.column_name;
    `),
    q('foreign_keys', `
      select tc.table_name,
             kcu.column_name,
             ccu.table_name as foreign_table_name,
             ccu.column_name as foreign_column_name
      from information_schema.table_constraints tc
      join information_schema.key_column_usage kcu
        on tc.constraint_name = kcu.constraint_name and tc.table_schema = kcu.table_schema
      join information_schema.constraint_column_usage ccu
        on ccu.constraint_name = tc.constraint_name and ccu.table_schema = tc.table_schema
      where tc.constraint_type = 'FOREIGN KEY' and tc.table_schema = 'public'
      order by tc.table_name, kcu.column_name;
    `),
    q('indexes', `
      select tablename as table_name, indexname as index_name, indexdef as definition
      from pg_indexes
      where schemaname = 'public'
      order by tablename, indexname;
    `),
    q('enums', `
      select t.typname as enum_type, e.enumlabel as enum_label
      from pg_type t
      join pg_enum e on t.oid = e.enumtypid
      join pg_catalog.pg_namespace n on n.oid = t.typnamespace
      where n.nspname = 'public'
      order by enum_type, e.enumsortorder;
    `),
  ];

  const results = {};
  for (const p of queries) {
    const { name, rows } = await p;
    results[name] = rows;
  }

  console.log(JSON.stringify(results, null, 2));
  await client.end();
}

run().catch((err) => {
  console.error('Schema inventory failed:', err);
  process.exit(1);
});



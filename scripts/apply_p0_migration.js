#!/usr/bin/env node
/**
 * Applies the P0 outage mitigation migration (indexes, distributed locks, autovacuum).
 *
 * Usage:
 *   DATABASE_URL='postgresql://...' node scripts/apply_p0_migration.js
 *   or
 *   SUPABASE_DB_URL='postgresql://...' node scripts/apply_p0_migration.js
 */
import pg from 'pg';
import { readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const connectionString = process.env.SUPABASE_DB_URL || process.env.DATABASE_URL;

if (!connectionString) {
  console.error('Missing connection string. Set SUPABASE_DB_URL or DATABASE_URL, or apply supabase/migrations/20261117210000_p0_outage_mitigation.sql directly in Supabase SQL Editor.');
  process.exit(1);
}

const migrationPath = join(__dirname, '../supabase/migrations/20261117210000_p0_outage_mitigation.sql');
const sql = readFileSync(migrationPath, 'utf8');

const client = new pg.Client({
  connectionString,
  ssl: { rejectUnauthorized: false },
});

try {
  console.log('Connecting to PostgreSQL database...');
  await client.connect();
  console.log('Applying P0 outage mitigation migration...');
  await client.query(sql);
  console.log('✅ P0 outage mitigation migration applied successfully!');
} catch (err) {
  console.error('❌ Migration failed:', err.message);
  process.exit(1);
} finally {
  await client.end();
}

#!/usr/bin/env node
/**
 * Apply public web ordering migration when DATABASE_URL or SUPABASE_DB_URL is set.
 * Usage: SUPABASE_DB_URL='postgresql://...' node scripts/apply_public_web_migration.js
 */
import pg from 'pg';
import { readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const connectionString = process.env.SUPABASE_DB_URL || process.env.DATABASE_URL;

if (!connectionString) {
  console.error('Set SUPABASE_DB_URL or DATABASE_URL to apply migration.');
  process.exit(1);
}

const sql = readFileSync(
  join(__dirname, '20260619210000_public_web_ordering.sql'),
  'utf8',
);

const client = new pg.Client({
  connectionString,
  ssl: { rejectUnauthorized: false },
});

try {
  await client.connect();
  await client.query(sql);
  console.log('Migration applied successfully.');
} catch (err) {
  console.error('Migration failed:', err.message);
  process.exit(1);
} finally {
  await client.end();
}

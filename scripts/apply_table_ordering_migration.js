#!/usr/bin/env node
/**
 * Apply table ordering migrations when SUPABASE_DB_URL or DATABASE_URL is set.
 * Usage: SUPABASE_DB_URL='postgresql://...' node scripts/apply_table_ordering_migration.js
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

const files = [
  '20260622140000_table_ordering_schema.sql',
  '20260622140100_table_ordering_rpc.sql',
  '20260622140300_restaurant_table_codes_token.sql',
  '20260622140400_table_ordering_location_presence.sql',
  '20260622140500_table_order_optional_guest_contact.sql',
  '20260622140600_restaurant_table_portal_code.sql',
  '20260622140700_restaurant_table_portal_secret.sql',
  '20260622140800_orders_fulfillment_type_table.sql',
];

const client = new pg.Client({
  connectionString,
  ssl: { rejectUnauthorized: false },
});

try {
  await client.connect();
  for (const file of files) {
    const sql = readFileSync(join(__dirname, file), 'utf8');
    console.log(`Applying ${file}...`);
    await client.query(sql);
  }
  console.log('Table ordering migrations applied successfully.');
} catch (err) {
  console.error('Migration failed:', err.message);
  process.exit(1);
} finally {
  await client.end();
}

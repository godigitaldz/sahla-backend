const fs = require('fs');

try {
  const raw = fs.readFileSync('schema_inventory.json', 'utf8');
  const d = JSON.parse(raw);
  const count = (k) => Array.isArray(d[k]) ? d[k].length : 0;
  const summary = {
    database: (d.db_info && d.db_info[0] && d.db_info[0].db) || null,
    schema: (d.db_info && d.db_info[0] && d.db_info[0].schema) || 'public',
    tables: count('tables'),
    views: count('views'),
    columns: count('columns'),
    primary_keys: count('primary_keys'),
    foreign_keys: count('foreign_keys'),
    indexes: count('indexes'),
    enums: count('enums')
  };
  console.log(JSON.stringify(summary, null, 2));
} catch (e) {
  console.error('Failed to summarize inventory:', e.message);
  process.exit(1);
}



import { readFileSync, writeFileSync } from 'fs';
import { resolve } from 'path';
import { createHash } from 'crypto';

function computeCombinedHash() {
  const files = [
    'public/download.js',
    'public/config.js',
    'public/download.css'
  ];
  const hash = createHash('sha256');
  for (const f of files) {
    hash.update(readFileSync(resolve(f)));
  }
  return hash.digest('hex').substring(0, 8);
}

const buildHash = computeCombinedHash();
console.log(`🏷️ Stamping build version: v${buildHash}`);

const htmlFiles = [
  'public/open.html',
  'public/download.html',
  'public/index.html'
];

for (const relPath of htmlFiles) {
  const absPath = resolve(relPath);
  let content = readFileSync(absPath, 'utf8');

  // Replace asset query strings
  content = content.replace(/(download\.css)(\?v=[a-f0-9]+)?/g, `$1?v=${buildHash}`);
  content = content.replace(/(config\.js)(\?v=[a-f0-9]+)?/g, `$1?v=${buildHash}`);
  content = content.replace(/(download\.js)(\?v=[a-f0-9]+)?/g, `$1?v=${buildHash}`);

  // Insert or update <meta name="build" content="...">
  if (content.includes('<meta name="build"')) {
    content = content.replace(/<meta name="build" content="[^"]*">/, `<meta name="build" content="${buildHash}">`);
  } else {
    content = content.replace('</head>', `  <meta name="build" content="${buildHash}">\n</head>`);
  }

  writeFileSync(absPath, content, 'utf8');
}

console.log('✅ Version stamping complete.');

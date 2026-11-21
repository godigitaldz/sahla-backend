import { readFileSync, writeFileSync, copyFileSync, readdirSync, statSync, mkdirSync, existsSync } from 'fs';
import { resolve, join, relative } from 'path';
import { createHash } from 'crypto';

const srcDir = resolve('public');
const destDir = resolve('web/public');

function getHash(filePath) {
  const content = readFileSync(filePath);
  return createHash('sha256').update(content).digest('hex');
}

function syncDirectory(src, dest) {
  if (!existsSync(dest)) {
    mkdirSync(dest, { recursive: true });
  }

  const entries = readdirSync(src);
  for (const entry of entries) {
    const srcPath = join(src, entry);
    const destPath = join(dest, entry);
    const stat = statSync(srcPath);

    if (stat.isDirectory()) {
      syncDirectory(srcPath, destPath);
    } else {
      copyFileSync(srcPath, destPath);
      const hSrc = getHash(srcPath);
      const hDest = getHash(destPath);
      if (hSrc !== hDest) {
        throw new Error(`Hash mismatch after copying ${entry}: ${hSrc} vs ${hDest}`);
      }
    }
  }
}

console.log('🔄 Syncing public/ -> web/public/ ...');
syncDirectory(srcDir, destDir);
console.log('✅ Synchronization and SHA-256 verification complete.');

/**
 * Build-time generator for firebase-messaging-sw.js.
 * Static SW files cannot read NEXT_PUBLIC_* at runtime.
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');
const templatePath = join(root, 'public', 'firebase-messaging-sw.template.js');
const outPath = join(root, 'public', 'firebase-messaging-sw.js');

function env(name, fallback = '') {
  return (process.env[name] ?? fallback).trim();
}

const config = {
  apiKey: env('NEXT_PUBLIC_FIREBASE_API_KEY'),
  authDomain: env('NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN'),
  projectId: env('NEXT_PUBLIC_FIREBASE_PROJECT_ID'),
  storageBucket: env('NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET'),
  messagingSenderId: env('NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID'),
  appId: env('NEXT_PUBLIC_FIREBASE_APP_ID'),
};

let template = readFileSync(templatePath, 'utf8');
template = template.replace('__FIREBASE_CONFIG__', JSON.stringify(config));
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, template, 'utf8');
console.log('[generate-firebase-messaging-sw] wrote', outPath);

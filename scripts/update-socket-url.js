#!/usr/bin/env node

/**
 * Script to update Socket.IO URL in Flutter app
 * Usage: node scripts/update-socket-url.js https://your-deployed-domain.com
 */

const fs = require('fs');
const path = require('path');

const SOCKET_URL = process.argv[2];

if (!SOCKET_URL) {
  console.error('❌ Please provide the Socket.IO server URL');
  console.log('Usage: node scripts/update-socket-url.js https://your-deployed-domain.com');
  process.exit(1);
}

// Validate URL format
try {
  new URL(SOCKET_URL);
} catch (e) {
  console.error('❌ Invalid URL format. Please provide a valid URL (e.g., https://your-app.railway.app)');
  process.exit(1);
}

const socketServicePath = path.join(__dirname, '..', 'lib', 'services', 'socket_service.dart');

try {
  let content = fs.readFileSync(socketServicePath, 'utf8');

  // Update localhost URL to production URL
  const oldPattern = /_socket = io\.io\('http:\/\/localhost:3001'/g;
  const newContent = content.replace(oldPattern, `_socket = io.io('${SOCKET_URL}'`);

  if (content === newContent) {
    console.log('⚠️  No localhost:3001 URL found to replace');
    console.log('   Make sure your SocketService is using the correct localhost URL');
  } else {
    fs.writeFileSync(socketServicePath, newContent);
    console.log(`✅ Updated Socket.IO URL to: ${SOCKET_URL}`);
    console.log('📁 File updated: lib/services/socket_service.dart');
  }

} catch (error) {
  console.error('❌ Error updating Socket.IO URL:', error.message);
  process.exit(1);
}

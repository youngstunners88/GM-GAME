#!/usr/bin/env node
// Production-faithful local server for web/: same COOP/COEP headers and MIME
// types as the Vercel config, so crossOriginIsolated (SharedArrayBuffer /
// Godot threads) behaves identically to the live site.
//
// Usage: node scripts/serve-web.mjs [port] [rootDir]

import http from 'http';
import { promises as fs } from 'fs';
import path from 'path';

const PORT = Number(process.argv[2] || 8899);
const ROOT = path.resolve(process.argv[3] || 'web');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ogg': 'audio/ogg',
};

http.createServer(async (req, res) => {
  try {
    let urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    if (urlPath.endsWith('/')) urlPath += 'index.html';
    const file = path.join(ROOT, path.normalize(urlPath));
    if (!file.startsWith(ROOT)) throw Object.assign(new Error('forbidden'), { code: 'EPERM' });
    const data = await fs.readFile(file);
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(file)] || 'application/octet-stream',
      'Cross-Origin-Embedder-Policy': 'require-corp',
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cache-Control': 'no-store',
    });
    res.end(data);
  } catch (e) {
    res.writeHead(e.code === 'ENOENT' ? 404 : 500, { 'Content-Type': 'text/plain' });
    res.end(e.code === 'ENOENT' ? 'not found' : 'error');
  }
}).listen(PORT, () => console.log(`serving ${ROOT} on http://localhost:${PORT} with COOP/COEP`));

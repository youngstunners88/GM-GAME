#!/usr/bin/env node
/**
 * or-vision.mjs — OpenRouter dispatch for VISION models (image + text).
 *
 * Usage:
 *   node scripts/or-vision.mjs <model-id> <prompt-file> <out-file> <img...>
 *
 * WHY THIS EXISTS SEPARATELY FROM or-call.mjs
 * or-call.mjs sends `messages: [{role:'user', content: "<string>"}]`. That
 * shape cannot carry an image at all — OpenRouter needs the multipart
 * `content: [{type:'text'...},{type:'image_url'...}]` array form. Sending a
 * screenshot path as text to a vision model gets you a confident description
 * of a file it never opened, which is the exact failure mode or-call.mjs's
 * @include guard was written to stop for source files.
 *
 * Images are inlined as base64 data URLs — the model host cannot reach this
 * machine's filesystem or a localhost URL.
 *
 * Env: OPENROUTER_API_KEY (required)
 */

import { readFileSync, writeFileSync, existsSync } from 'fs';
import { extname } from 'path';

const API_KEY = process.env.OPENROUTER_API_KEY;
if (!API_KEY) {
  console.error('ERROR: OPENROUTER_API_KEY not set');
  process.exit(1);
}

const [MODEL, PROMPT_FILE, OUT_FILE, ...IMAGES] = process.argv.slice(2);
if (!MODEL || !PROMPT_FILE || !OUT_FILE || IMAGES.length === 0) {
  console.error('Usage: or-vision.mjs <model> <prompt-file> <out-file> <img...>');
  process.exit(1);
}
if (!existsSync(PROMPT_FILE)) {
  console.error(`ERROR: prompt file not found: ${PROMPT_FILE}`);
  process.exit(1);
}

// Missing images abort BEFORE spending money, same rule as or-call's @include.
const missing = IMAGES.filter((p) => !existsSync(p));
if (missing.length) {
  console.error('ERROR: image paths do not exist — refusing to dispatch:');
  for (const p of missing) console.error(`  ${p}`);
  process.exit(2);
}

const MIME = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp' };

const content = [{ type: 'text', text: readFileSync(PROMPT_FILE, 'utf-8') }];
let bytes = 0;
for (const p of IMAGES) {
  const buf = readFileSync(p);
  bytes += buf.length;
  const mime = MIME[extname(p).toLowerCase()] || 'image/png';
  content.push({
    type: 'image_url',
    image_url: { url: `data:${mime};base64,${buf.toString('base64')}` },
  });
}
console.error(`Dispatching ${MODEL}: ${IMAGES.length} images, ${(bytes / 1e6).toFixed(1)} MB`);

const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
  method: 'POST',
  headers: { Authorization: `Bearer ${API_KEY}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ model: MODEL, messages: [{ role: 'user', content }] }),
});

if (!res.ok) {
  console.error(`ERROR: HTTP ${res.status}\n${await res.text()}`);
  process.exit(3);
}
const json = await res.json();
const text = json.choices?.[0]?.message?.content ?? '';
if (!text) {
  console.error('ERROR: empty response\n' + JSON.stringify(json).slice(0, 2000));
  process.exit(4);
}
writeFileSync(OUT_FILE, text);
console.error(`OK -> ${OUT_FILE} (${text.length} chars)`);

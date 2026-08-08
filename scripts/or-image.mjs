#!/usr/bin/env node
/**
 * or-image.mjs — OpenRouter IMAGE GENERATION for GM-GAME art.
 *
 * Usage: node scripts/or-image.mjs <model-id> <prompt-file> <out.png>
 *
 * NOTE ON THE MODEL ID. The founder asked for `openai/gpt-image-2`. That id
 * does not exist in OpenRouter's catalogue — the OpenAI image models it
 * actually serves are `openai/gpt-5.4-image-2`, `openai/gpt-5-image` and
 * `openai/gpt-5-image-mini`. `gpt-5.4-image-2` is the one carrying the
 * "-image-2" line, so that is the substitution. Pass the id explicitly; this
 * script never guesses one.
 *
 * Image models return the bitmap on the message as `images[]`, NOT as text,
 * so the reply is decoded from a data: URL rather than parsed as content.
 *
 * Env: OPENROUTER_API_KEY
 */
import { readFileSync, writeFileSync, existsSync } from 'fs';

const API_KEY = process.env.OPENROUTER_API_KEY;
if (!API_KEY) { console.error('ERROR: OPENROUTER_API_KEY not set'); process.exit(1); }

const [MODEL, PROMPT_FILE, OUT] = process.argv.slice(2);
if (!MODEL || !PROMPT_FILE || !OUT) {
  console.error('Usage: or-image.mjs <model-id> <prompt-file> <out.png>');
  process.exit(1);
}
if (!existsSync(PROMPT_FILE)) { console.error(`ERROR: no prompt file ${PROMPT_FILE}`); process.exit(1); }

const prompt = readFileSync(PROMPT_FILE, 'utf-8');
const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
  method: 'POST',
  headers: { Authorization: `Bearer ${API_KEY}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({
    model: MODEL,
    messages: [{ role: 'user', content: prompt }],
    modalities: ['image', 'text'],
  }),
});
if (!res.ok) { console.error(`ERROR: HTTP ${res.status}\n${(await res.text()).slice(0, 1200)}`); process.exit(3); }

const json = await res.json();
const msg = json.choices?.[0]?.message ?? {};
const url = msg.images?.[0]?.image_url?.url ?? msg.images?.[0]?.url;
if (!url) {
  console.error('ERROR: no image in reply\n' + JSON.stringify(json).slice(0, 1500));
  process.exit(4);
}
const b64 = url.startsWith('data:') ? url.split(',')[1] : null;
if (!b64) { console.error('ERROR: image came back as a remote URL, not data:\n' + url.slice(0, 200)); process.exit(5); }
writeFileSync(OUT, Buffer.from(b64, 'base64'));
console.error(`OK -> ${OUT}`);

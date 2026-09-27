#!/usr/bin/env node
// ref-image.mjs — reference-guided image generation through OpenRouter:
// Nano Banana Pro (google/gemini-3-pro-image) or ChatGPT image (openai/gpt-5.4-image-2).
// The founder's preferred image stack (2026-09-27): it takes the KEY ART as input, so
// character stills match it, where Flux (text-only) only approximates.
//   node scripts/ref-image.mjs <model> <prompt.txt> <reference.jpg|-> <out.png>
// Prints remaining OpenRouter credit first and the call's cost after. ~$0.14 (NBP) /
// ~$0.24 (GPT image) per image on 2026-09-27. Key: OPENROUTER_API_KEY, never printed.
import { readFileSync, writeFileSync } from 'fs';
const u = await import('undici'); const agent = new u.ProxyAgent(process.env.HTTPS_PROXY);
const f = (url, init = {}) => u.fetch(url, { ...init, dispatcher: agent });
const [model, promptFile, ref, out] = process.argv.slice(2);
const cr = await (await f('https://openrouter.ai/api/v1/credits', { headers: { Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}` } })).json();
console.log('credits left $' + (cr.data.total_credits - cr.data.total_usage).toFixed(2));
const content = [{ type: 'text', text: readFileSync(promptFile, 'utf8') }];
if (ref && ref !== '-') content.unshift({ type: 'image_url', image_url: { url: 'data:image/jpeg;base64,' + readFileSync(ref).toString('base64') } });
const r = await f('https://openrouter.ai/api/v1/chat/completions', { method: 'POST',
  headers: { Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ model, modalities: ['image', 'text'], messages: [{ role: 'user', content }] }) });
const j = await r.json();
if (!r.ok) { console.log('HTTP', r.status, JSON.stringify(j).slice(0, 300)); process.exit(1); }
const img = j.choices?.[0]?.message?.images?.[0]?.image_url?.url;
if (!img) { console.log('no image', JSON.stringify(j).slice(0, 300)); process.exit(1); }
writeFileSync(out, Buffer.from(img.split(',')[1], 'base64'));
console.log('OK', out, 'cost', j.usage?.cost ?? '?');

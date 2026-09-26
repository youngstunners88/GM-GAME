#!/usr/bin/env node
/**
 * varco-text2sound.mjs — Episode 2 stems from NCSOFT VARCO text2sound (skill: gm-game-varco-ep2).
 *
 *   node scripts/varco-text2sound.mjs --section runner [--only id,id] [--samples 3] [--dry-run]
 *   node scripts/varco-text2sound.mjs --promote <stem_id>=<take>   e.g. ep2_runner_duck_01=v1_s2
 *   node scripts/varco-text2sound.mjs --list
 *
 * Contract (from the skill, not guessed):
 *   POST https://openapi.ai.nc.com/sound/varco/v1/api/text2sound
 *   header OPENAPI_KEY: <key>   body { prompt (<=400 bytes), num_sample }
 *   -> 10 s, 44.1 kHz 16-bit WAV samples, base64 inside the JSON.
 *
 * Takes:    artifacts/episode2-gold-mine/audio/takes/<stem_id>/v<N>_s<K>.wav
 * Promoted: src/episode2/assets/audio/<stem_id>.wav   (only via --promote, after a listen)
 *
 * The key is read from VARCO_API_KEY (or OPENAPI_KEY). Its value is never printed or logged.
 * The response's audio field name is not documented to us, so every base64 string that
 * decodes to a RIFF/WAVE header is taken as a sample; the first raw response (audio
 * stripped) is saved as takes/_first_response.json as evidence.
 */
import { readFileSync, writeFileSync, appendFileSync, existsSync, mkdirSync, readdirSync, copyFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..');
const AUDIO = join(REPO, 'artifacts/episode2-gold-mine/audio');
const PROMPTS = join(AUDIO, 'prompts');
const TAKES = join(AUDIO, 'takes');
const LOG = join(AUDIO, 'LOG.md');
const GAME = join(REPO, 'src/episode2/assets/audio');
const ENDPOINT = 'https://openapi.ai.nc.com/sound/varco/v1/api/text2sound';

let fetchFn = globalThis.fetch;
const proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
if (proxy) {
  try {
    const u = await import('undici');
    const agent = new u.ProxyAgent(proxy);
    fetchFn = (url, init = {}) => u.fetch(url, { ...init, dispatcher: agent });
  } catch (e) { console.error('WARN: HTTPS_PROXY set but undici missing: ' + e.message); }
}

const argv = process.argv.slice(2);
const opt = (n, d) => { const i = argv.indexOf(n); return i >= 0 ? argv[i + 1] : d; };
const DRY = argv.includes('--dry-run');
const log = (line) => { mkdirSync(AUDIO, { recursive: true }); appendFileSync(LOG, `- ${new Date().toISOString()} ${line}\n`); };

function stems(section) {
  const f = join(PROMPTS, `${section}.json`);
  if (!existsSync(f)) { console.error(`no prompt catalog: ${f}`); process.exit(2); }
  const j = JSON.parse(readFileSync(f, 'utf8'));
  return j.stems.map(s => ({ ...s, section, catalogVersion: j.version }));
}

if (argv.includes('--list')) {
  for (const f of readdirSync(PROMPTS).filter(f => f.endsWith('.json'))) {
    const sec = f.replace('.json', '');
    for (const s of stems(sec)) {
      const promoted = existsSync(join(GAME, `${s.id}.wav`)) ? 'PROMOTED' : 'hole';
      console.log(`${sec.padEnd(10)} ${s.id.padEnd(34)} ${s.loop ? 'loop' : 'once'} ${promoted}`);
    }
  }
  process.exit(0);
}

const promote = opt('--promote', '');
if (promote) {
  const [id, take] = promote.split('=');
  const src = join(TAKES, id, `${take}.wav`);
  if (!existsSync(src)) { console.error(`no take: ${src}`); process.exit(2); }
  mkdirSync(GAME, { recursive: true });
  copyFileSync(src, join(GAME, `${id}.wav`));
  log(`PROMOTE ${id} <- takes/${id}/${take}.wav`);
  console.log(`promoted ${id} <- ${take}`);
  process.exit(0);
}

const section = opt('--section', '');
if (!section) { console.error('usage: --section <runner|revolver|...> | --promote id=take | --list'); process.exit(2); }
const only = new Set(opt('--only', '').split(',').filter(Boolean));
const todo = stems(section).filter(s => !only.size || only.has(s.id));
const samples = parseInt(opt('--samples', '3'), 10);

for (const s of todo) {
  const bytes = Buffer.byteLength(s.prompt);
  if (bytes > 400) { console.error(`${s.id}: prompt is ${bytes} bytes (>400) — re-version the catalog`); process.exit(2); }
}
console.log(`${todo.length} stem(s) x ${samples} samples from ${section}.json -> takes/`);
if (DRY) { todo.forEach(s => console.log(`  ${s.id} (${Buffer.byteLength(s.prompt)} B)`)); process.exit(0); }

const KEY = process.env.VARCO_API_KEY || process.env.OPENAPI_KEY || '';
if (!KEY) { console.error('STOP: VARCO_API_KEY is not set (OPENAPI_KEY also absent). Add it in the environment settings.'); process.exit(3); }

/** Every base64 string in the JSON that decodes to a WAV. */
function findWavs(node, out = []) {
  if (typeof node === 'string' && node.length > 1000) {
    const b = Buffer.from(node.replace(/^data:[^,]*,/, ''), 'base64');
    if (b.subarray(0, 4).toString() === 'RIFF' && b.subarray(8, 12).toString() === 'WAVE') out.push(b);
  } else if (Array.isArray(node)) node.forEach(n => findWavs(n, out));
  else if (node && typeof node === 'object') Object.values(node).forEach(n => findWavs(n, out));
  return out;
}
const strip = (node) => typeof node === 'string' ? (node.length > 200 ? `<${node.length} chars>` : node)
  : Array.isArray(node) ? node.map(strip)
  : node && typeof node === 'object' ? Object.fromEntries(Object.entries(node).map(([k, v]) => [k, strip(v)])) : node;

let failed = 0;
for (const s of todo) {
  const dir = join(TAKES, s.id);
  mkdirSync(dir, { recursive: true });
  const v = 1 + readdirSync(dir).filter(f => /^v\d+_s\d+\.wav$/.test(f))
    .reduce((m, f) => Math.max(m, parseInt(f.slice(1), 10)), 0);
  let r, text = '';
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      r = await fetchFn(ENDPOINT, {
        method: 'POST',
        headers: { OPENAPI_KEY: KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt: s.prompt, num_sample: samples }),
      });
      text = await r.text();
      if (r.status !== 429) break;
    } catch (e) { text = String(e.cause?.code || e.message); }
    await new Promise(res => setTimeout(res, attempt * 10000));
  }
  if (!r || !r.ok) {
    failed++;
    const msg = `FAIL ${s.id} HTTP ${r ? r.status : 'network'}: ${text.slice(0, 200).replace(/\n/g, ' ')}`;
    console.log(msg); log(msg);
    continue;
  }
  let j; try { j = JSON.parse(text); } catch { j = null; }
  if (!existsSync(join(TAKES, '_first_response.json')) && j) writeFileSync(join(TAKES, '_first_response.json'), JSON.stringify(strip(j), null, 2));
  const wavs = j ? findWavs(j) : [];
  if (!wavs.length) { failed++; const m = `FAIL ${s.id}: 200 but no WAV found in response (see takes/_first_response.json)`; console.log(m); log(m); continue; }
  wavs.forEach((b, k) => writeFileSync(join(dir, `v${v}_s${k + 1}.wav`), b));
  const m = `OK ${s.id} catalog ${s.section}@v${s.catalogVersion} -> takes/${s.id}/v${v}_s1..${wavs.length}.wav`;
  console.log(m); log(m);
}
process.exit(failed ? 1 : 0);

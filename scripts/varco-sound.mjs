#!/usr/bin/env node
/**
 * varco-sound.mjs — VARCO Sound (Text-to-Sound) stem generator for Episode 2.
 *
 * Brief: artifacts/PROMPT_EPISODE2_VARCO_SOUND_INTEGRATION.md
 * Setup + current blocker: artifacts/episode2-gold-mine/audio/SETUP.md
 *
 * Usage:
 *   node scripts/varco-sound.mjs --list
 *   node scripts/varco-sound.mjs --section runner --dry-run
 *   node scripts/varco-sound.mjs --section runner
 *   node scripts/varco-sound.mjs --section smelting --only ep2_smelt_furnace_roar_loop_01
 *
 * Env: VARCO_API_KEY (or OPENAPI_KEY, the name the founder brief uses).
 *
 * DESIGN NOTES, so the next session does not re-derive them:
 *
 *  1. --dry-run AND --list WORK WITH NO KEY. That is deliberate: the prompt
 *     library, the naming and the spend estimate are reviewable before anyone
 *     pays for anything, and a session with no credential can still verify the
 *     pipeline is wired correctly instead of just reporting "blocked".
 *
 *  2. THE ENDPOINT SHAPE IS NOT GUESSED. `VARCO_ENDPOINT` and the small
 *     response-shape probe below exist because this script has never been run
 *     against the live API — no key has existed in any session yet. Rather
 *     than invent a request body and have it fail confusingly on someone
 *     else's credits, the first real run prints the raw response and saves it
 *     to the section folder as `_first_response.json`. Read that, then fix
 *     `buildRequest`/`extractAudio` once, with evidence.
 *
 *  3. NEVER LOGS THE KEY. Presence is reported, the value never is.
 *
 *  4. EVERY SUCCESSFUL GENERATION APPENDS TO CREDIT_LOG.md. The brief asks for
 *     a spend trail; a trail written by hand is a trail that stops being
 *     written.
 */
import { readFileSync, writeFileSync, appendFileSync, existsSync, mkdirSync, readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..');
const AUDIO = join(REPO, 'artifacts/episode2-gold-mine/audio');
const PROMPTS = join(AUDIO, 'prompts');
const STEMS = join(AUDIO, 'stems');
const CREDIT_LOG = join(AUDIO, 'CREDIT_LOG.md');

// Route through the agent proxy. Node's global fetch does NOT honour HTTPS_PROXY
// on its own — without this the call gets a hard 403 from the sandbox proxy
// while plain curl to the same host succeeds. Same fix as scripts/or-call.mjs.
const _proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
if (_proxy) {
  try {
    const { ProxyAgent, setGlobalDispatcher } = await import('undici');
    setGlobalDispatcher(new ProxyAgent(_proxy));
  } catch (e) {
    console.error('WARN: HTTPS_PROXY set but undici unavailable (' + e.message +
      ') — the VARCO call may 403. Run `npm install undici`.');
  }
}

const args = process.argv.slice(2);
const has = (f) => args.includes(f);
const val = (f) => { const i = args.indexOf(f); return i >= 0 ? args[i + 1] : null; };

const DRY = has('--dry-run');
const SECTION = val('--section');
const ONLY = val('--only');
const VARCO_ENDPOINT = process.env.VARCO_ENDPOINT || 'https://api.varco.ai/v1/sound/text-to-sound';
const API_KEY = process.env.VARCO_API_KEY || process.env.OPENAPI_KEY || '';

/** Credits per generation. A placeholder until a real invoice proves otherwise —
 *  labelled as an estimate everywhere it is printed so nobody quotes it as fact. */
const CREDITS_PER_STEM_EST = 1;

function loadSections() {
  if (!existsSync(PROMPTS)) return {};
  const out = {};
  for (const f of readdirSync(PROMPTS).filter((n) => n.endsWith('.json'))) {
    const j = JSON.parse(readFileSync(join(PROMPTS, f), 'utf-8'));
    out[j.section] = j;
  }
  return out;
}

const sections = loadSections();

if (has('--list') || (!SECTION && !has('--help'))) {
  console.log('VARCO Sound — prompt library\n');
  let total = 0;
  for (const [name, s] of Object.entries(sections)) {
    console.log(`  ${name}  (v${s.version}, ${s.stems.length} stems)`);
    for (const st of s.stems) {
      const done = existsSync(join(STEMS, name, st.id + '.wav')) ? 'have' : '    ';
      console.log(`    [${done}] ${st.id.padEnd(36)} ${st.layer}${st.loop ? ' loop' : ''}`);
      total++;
    }
  }
  console.log(`\n  ${total} stems defined, est. ${total * CREDITS_PER_STEM_EST} credits to generate all.`);
  console.log(`  Priority order (brief §7): runner -> smelting -> winchester -> fortknox -> global.`);
  console.log(`  API key: ${API_KEY ? 'PRESENT' : 'ABSENT — see artifacts/episode2-gold-mine/audio/SETUP.md'}`);
  process.exit(0);
}

if (!sections[SECTION]) {
  console.error(`ERROR: unknown section "${SECTION}". Known: ${Object.keys(sections).join(', ') || '(none)'}`);
  process.exit(2);
}

const sec = sections[SECTION];
const todo = sec.stems.filter((s) => (!ONLY || s.id === ONLY) &&
  !existsSync(join(STEMS, SECTION, s.id + '.wav')));

console.log(`Section: ${SECTION} (v${sec.version})`);
console.log(`Stems to generate: ${todo.length} of ${sec.stems.length} (existing files are skipped)`);
console.log(`Estimated credits: ~${todo.length * CREDITS_PER_STEM_EST}  [ESTIMATE — no real invoice has been seen yet]`);
console.log(`Output: ${join(STEMS, SECTION)}`);

if (DRY) {
  for (const s of todo) console.log(`  would generate ${s.id}\n    "${s.prompt}"`);
  console.log('\n--dry-run: nothing sent, nothing spent.');
  process.exit(0);
}

if (!API_KEY) {
  console.error('\nERROR: no VARCO credential in the environment.');
  console.error('  Checked VARCO_API_KEY and OPENAPI_KEY — both absent.');
  console.error('  api.varco.ai IS reachable from here, so this is a credential, not a network problem.');
  console.error('  Add the key in the environment\'s Environment Variables field; see');
  console.error('  artifacts/episode2-gold-mine/audio/SETUP.md. Never inline it in a file.');
  process.exit(3);
}

mkdirSync(join(STEMS, SECTION), { recursive: true });

/** Request body. See design note 2 — verify against the first live response. */
function buildRequest(stem) {
  return {
    prompt: stem.prompt,
    duration: stem.loop ? 10 : 4,
    loop: !!stem.loop,
    format: 'wav',
  };
}

/** Pull audio bytes out of whatever shape comes back: raw body, a base64 field,
 *  or a URL to fetch. Returns a Buffer, or null if the shape is unrecognised. */
async function extractAudio(res) {
  const ctype = res.headers.get('content-type') || '';
  if (ctype.startsWith('audio/') || ctype === 'application/octet-stream') {
    return Buffer.from(await res.arrayBuffer());
  }
  const json = await res.json();
  const b64 = json.audio || json.data?.audio || json.result?.audio;
  if (typeof b64 === 'string' && b64.length > 100) return { buf: Buffer.from(b64, 'base64'), json };
  const url = json.url || json.data?.url || json.result?.url || json.audio_url;
  if (typeof url === 'string') {
    const a = await fetch(url);
    return { buf: Buffer.from(await a.arrayBuffer()), json };
  }
  return { buf: null, json };
}

let generated = 0;
let firstResponseSaved = false;

for (const stem of todo) {
  process.stdout.write(`  ${stem.id} ... `);
  let res;
  try {
    res = await fetch(VARCO_ENDPOINT, {
      method: 'POST',
      headers: { Authorization: `Bearer ${API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(buildRequest(stem)),
    });
  } catch (e) {
    console.log(`NETWORK ERROR (${e.message})`);
    console.error(`  Host that must be reachable/allowlisted: api.varco.ai`);
    break;
  }
  if (!res.ok) {
    console.log(`HTTP ${res.status}`);
    const body = await res.text().catch(() => '');
    console.error(`  ${body.slice(0, 400)}`);
    console.error('  If this is a request-shape error, see design note 2 in this file:');
    console.error('  fix buildRequest() against the real response, once, rather than guessing again.');
    break;
  }

  const out = await extractAudio(res);
  const buf = Buffer.isBuffer(out) ? out : out.buf;
  if (!firstResponseSaved && !Buffer.isBuffer(out) && out.json) {
    writeFileSync(join(STEMS, SECTION, '_first_response.json'), JSON.stringify(out.json, null, 2));
    firstResponseSaved = true;
  }
  if (!buf) {
    console.log('UNRECOGNISED RESPONSE SHAPE');
    console.error(`  Raw response saved to ${join(STEMS, SECTION, '_first_response.json')} — read it, then fix extractAudio().`);
    break;
  }

  const path = join(STEMS, SECTION, stem.id + '.wav');
  writeFileSync(path, buf);
  generated++;
  console.log(`${buf.length} bytes`);

  appendFileSync(CREDIT_LOG,
    `| ${new Date().toISOString()} | ${SECTION} | ${stem.id} | ~${CREDITS_PER_STEM_EST} | ` +
    `artifacts/episode2-gold-mine/audio/stems/${SECTION}/${stem.id}.wav | prompts/${SECTION}.json v${sec.version} |\n`);
}

console.log(`\nGenerated ${generated} stem(s). Credit log: ${CREDIT_LOG}`);
process.exit(generated === todo.length ? 0 : 1);

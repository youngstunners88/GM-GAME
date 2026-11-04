/**
 * crouton.mjs — the Crouton lane for GM-GAME: stealth/crouton-alpha on OpenRouter, free extra hands.
 *
 * Mirrors scripts/or-call.mjs (the @include / abort-before-spending discipline) and the Quiet Money lane (faceless/crouton.py).
 * Crouton Alpha is an anonymous provider's free preview: 1M context, text/image/audio/video in, tools and JSON out. The provider
 * MAY KEEP PROMPTS. So this lane is for bounded side work and measured second readings, never for the critical path, and it
 * refuses to send anything private. Its output is a lead, not a fact: Claude re-derives every claim against the real files
 * (MODEL ROLE SPLIT in CLAUDE.md) and nothing it says is a "FIXED" or "live" claim.
 *
 * Guards (tests/crouton_lane_test.mjs pins each one):
 *  1. FREE ONLY. The model id must be in KNOWN_FREE_IDS (or end in ':free'), the live /models catalogue must still list it at
 *     $0 in and out (checked once per UTC day, fail closed), and one call that reports usage.cost > 0 trips .farm/crouton.tripped,
 *     which refuses every later call until a person deletes the file.
 *  2. STANDARD CALL TEMPLATE. reasoning.effort is set by `kind` (classify=minimal, review=low, draft=low, digest=medium) and
 *     max_tokens is never below 4000. The model reasons at max effort by default; a 400-token budget returned content:null with
 *     finish_reason:length. An empty answer cut off by length is retried once with double the budget.
 *  3. PRIVACY. A prompt shaped like a secret, holding a live key value, or holding a 0x wallet address is refused, and so is any
 *     @include of .env*, *.key, *.pem, config.json (wallet/contract ids), lil-blunt-icp/, GM Game/ (the vault) or .farm/.
 *  4. EVERY CALL IS LOGGED to .farm/crouton-log.jsonl (gitignored) so promotion rests on measured rates.
 *
 * Importable (bench, tests) and thin-CLI'd by scripts/crouton-call.mjs.
 */
import { readFileSync, writeFileSync, existsSync, mkdirSync, appendFileSync } from 'node:fs';
import { resolve, relative, basename, extname, dirname } from 'node:path';

// Same proxy discipline as or-call.mjs: Node's fetch ignores HTTPS_PROXY unless told to. Best effort; on Node >= 22.21 you can
// instead run with NODE_USE_ENV_PROXY=1 (and NODE_EXTRA_CA_CERTS pointing at the proxy CA bundle) without undici.
const _proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
if (_proxy) {
  try { const { ProxyAgent, setGlobalDispatcher } = await import('undici'); setGlobalDispatcher(new ProxyAgent(_proxy)); }
  catch { /* no undici: NODE_USE_ENV_PROXY=1 is the fallback, otherwise fetch fails loudly and the caller sees it */ }
}

export const DEFAULT_MODEL = 'stealth/crouton-alpha';
export const KNOWN_FREE_IDS = new Set([DEFAULT_MODEL]);
export const EFFORT = { classify: 'minimal', review: 'low', draft: 'low', digest: 'medium' };
export const MIN_MAX_TOKENS = 4000;
export const MAX_MAX_TOKENS = 32000;
export const DAILY_CALLS = parseInt(process.env.CROUTON_DAILY_CALLS || '', 10) || 200;
export const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
const IMAGE_MIME = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp' };
const SECRET_SHAPES = [/sk-[A-Za-z0-9_-]{16,}/, /Bearer\s+[A-Za-z0-9._-]{16,}/, /-----BEGIN [A-Z ]*PRIVATE KEY/, /AKIA[0-9A-Z]{16}/,
  /gh[pousr]_[A-Za-z0-9]{20,}/, /xox[abprs]-[A-Za-z0-9-]{10,}/, /AIza[0-9A-Za-z_-]{30,}/];
const WALLET = /0x[a-fA-F0-9]{40}/;
const PRIVATE_PREFIXES = ['lil-blunt-icp/', 'GM Game/', '.farm/'];
const PRIVATE_NAMES = [/^\.env/, /\.key$/, /\.pem$/, /^config\.json$/];

export class CroutonError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

export const today = (now = new Date()) => now.toISOString().slice(0, 10);

export function modelOk(id) {
  if (!KNOWN_FREE_IDS.has(id) && !String(id).endsWith(':free')) {
    throw new CroutonError('not-free', `model "${id}" is not a known free id: this lane only ever uses free models`);
  }
  return id;
}

/** Throws if the text could leak a secret or a wallet address to a provider that may keep prompts. */
export function guardText(text, env = process.env) {
  for (const re of SECRET_SHAPES) if (re.test(text)) throw new CroutonError('secret', 'refused: the prompt holds something shaped like a secret (the provider may keep prompts)');
  if (WALLET.test(text)) throw new CroutonError('wallet', 'refused: the prompt holds a 0x address (wallet/contract ids live in config.json and are not sent out)');
  for (const [name, val] of Object.entries(env)) {
    if (val && val.length >= 12 && /KEY|TOKEN|SECRET|PASSWORD/.test(name) && text.includes(val)) throw new CroutonError('secret', `refused: the prompt holds the value of $${name}`);
  }
}

export function privatePath(relPath) {
  const p = relPath.replaceAll('\\', '/');
  return PRIVATE_PREFIXES.some((x) => p.startsWith(x)) || PRIVATE_NAMES.some((re) => re.test(basename(p)));
}

/** `@include <path>` lines become labelled file contents. Private or missing paths abort before anything is sent. */
export function expandIncludes(text, root = process.cwd()) {
  const out = []; const missing = []; const blocked = []; let included = 0;
  for (const line of text.split('\n')) {
    const m = line.match(/^@include\s+(\S+)\s*$/);
    if (!m) { out.push(line); continue; }
    const rel = relative(root, resolve(root, m[1]));
    if (privatePath(rel)) { blocked.push(m[1]); continue; }
    const abs = resolve(root, m[1]);
    if (!existsSync(abs)) { missing.push(m[1]); continue; }
    const body = readFileSync(abs, 'utf-8');
    out.push(`--- FILE: ${m[1]} (${body.split('\n').length} lines) ---`, '```' + (m[1].endsWith('.gd') ? 'gdscript' : ''), body.replace(/\s+$/, ''), '```');
    included++;
  }
  if (blocked.length) throw new CroutonError('private', `refused: private path(s) not sent to a provider that may keep prompts: ${blocked.join(', ')}`);
  if (missing.length) throw new CroutonError('missing', `@include paths do not exist, refusing to ask about files the model cannot see: ${missing.join(', ')}`);
  return { text: out.join('\n'), included };
}

export function imagePart(path, root = process.cwd()) {
  const abs = resolve(root, path);
  const ext = extname(abs).toLowerCase();
  if (privatePath(relative(root, abs)) || !IMAGE_MIME[ext] || !existsSync(abs)) throw new CroutonError('image', `image ${path} is private, missing, or not png/jpg/webp`);
  const buf = readFileSync(abs);
  if (buf.length > MAX_IMAGE_BYTES) throw new CroutonError('image', `image ${path} is over 8 MB; downscale it first`);
  return { type: 'image_url', image_url: { url: `data:${IMAGE_MIME[ext]};base64,${buf.toString('base64')}` } };
}

const farm = (root) => resolve(root, '.farm');
const logPath = (root) => resolve(farm(root), 'crouton-log.jsonl');
export const breakerPath = (root) => resolve(farm(root), 'crouton.tripped');

function append(root, row) {
  mkdirSync(farm(root), { recursive: true });
  appendFileSync(logPath(root), JSON.stringify({ t: new Date().toISOString(), model: DEFAULT_MODEL, ...row }) + '\n');
}

export function callsToday(root, now = new Date()) {
  if (!existsSync(logPath(root))) return 0;
  return readFileSync(logPath(root), 'utf-8').split('\n').filter((l) => l.trim()).map((l) => { try { return JSON.parse(l); } catch { return {}; } })
    .filter((r) => r.counted && String(r.t || '').startsWith(today(now))).length;
}

/** The live catalogue must still say $0 in and out. Cached per UTC day; unreachable or non-zero both refuse (fail closed). */
export async function verifyFree(model, d) {
  const cache = resolve(farm(d.root), 'crouton-price.json');
  try { const c = JSON.parse(readFileSync(cache, 'utf-8')); if (c.day === today(d.now()) && c.model === model && c.free === true) return; } catch { /* no cache */ }
  let entry;
  try {
    const res = await d.fetch('https://openrouter.ai/api/v1/models', { signal: AbortSignal.timeout(30000) });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    entry = ((await res.json()).data || []).find((m) => m.id === model);
  } catch (e) { throw new CroutonError('catalogue', `could not check the catalogue price (${e.message}); refusing rather than risk a billed call`); }
  if (!entry) throw new CroutonError('catalogue', `${model} is not in the OpenRouter catalogue (stealth previews expire)`);
  const p = entry.pricing || {};
  if (!(Number(p.prompt) === 0 && Number(p.completion) === 0)) throw new CroutonError('not-free', `${model} is no longer free in the catalogue (prompt ${p.prompt}, completion ${p.completion}); refused`);
  mkdirSync(farm(d.root), { recursive: true });
  writeFileSync(cache, JSON.stringify({ day: today(d.now()), model, free: true }));
}

export function extractJson(text) {
  const t = text.trim();
  for (const cand of [t, t.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, ''), t.slice(t.indexOf('{'), t.lastIndexOf('}') + 1)]) {
    try { return JSON.parse(cand); } catch { /* next */ }
  }
  throw new CroutonError('bad-json', 'the answer was not JSON');
}

/**
 * One request. Returns { text | json, meta }. Throws CroutonError on every refusal or failure (the caller carries on without Crouton).
 * deps (tests): { fetch, root, env, now, sleep, backoffMs }.
 */
export async function ask(opts, deps = {}) {
  const d = { fetch: globalThis.fetch, root: process.cwd(), env: process.env, now: () => new Date(), sleep: (ms) => new Promise((r) => setTimeout(r, ms)), backoffMs: 8000, ...deps };
  const { prompt, kind = 'review', task = 'adhoc', system, json = false, maxTokens, images = [], model = DEFAULT_MODEL, temperature = 0.2 } = opts;
  if (!EFFORT[kind]) throw new CroutonError('kind', `kind "${kind}" must be one of ${Object.keys(EFFORT).join(', ')}`);
  modelOk(model);
  const key = d.env.OPENROUTER_API_KEY;
  if (!key) throw new CroutonError('no-key', 'OPENROUTER_API_KEY not set');
  if (existsSync(breakerPath(d.root))) throw new CroutonError('tripped', `crouton is tripped (${readFileSync(breakerPath(d.root), 'utf-8').trim()}); read why, then delete .farm/crouton.tripped`);
  if (callsToday(d.root, d.now()) >= DAILY_CALLS) throw new CroutonError('allowance', `daily call allowance (${DAILY_CALLS}) used`);
  guardText(prompt + (system || ''), d.env);
  await verifyFree(model, d);
  const content = images.length ? [{ type: 'text', text: prompt }, ...images.map((i) => imagePart(i, d.root))] : prompt;
  const body = {
    model, temperature, usage: { include: true },
    messages: [...(system ? [{ role: 'system', content: system }] : []), { role: 'user', content }],
    max_tokens: Math.max(MIN_MAX_TOKENS, Math.min(maxTokens || MIN_MAX_TOKENS, MAX_MAX_TOKENS)),
    reasoning: { effort: EFFORT[kind] },
    ...(json ? { response_format: { type: 'json_object' } } : {}),
  };
  const t0 = Date.now(); let err = ''; let grown = false; let meta = {};
  const RETRIES = 3;
  for (let attempt = 1; attempt <= RETRIES; attempt++) {
    let res;
    try {
      res = await d.fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST', signal: AbortSignal.timeout(240000),
        headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json', 'HTTP-Referer': 'https://github.com/youngstunners88/GM-GAME', 'X-Title': 'GM-GAME Crouton lane' },
        body: JSON.stringify(body),
      });
    } catch (e) { err = e.name || 'network'; await d.sleep(d.backoffMs); continue; }
    if (res.status === 429 || res.status >= 500) { err = String(res.status); await d.sleep(d.backoffMs * attempt); continue; }
    if (res.status !== 200) { err = String(res.status); break; }
    const data = await res.json();
    const usage = data.usage || {};
    append(d.root, { counted: true, task, kind, event: 'response' });
    if (Number(usage.cost || 0) > 0) {
      mkdirSync(farm(d.root), { recursive: true });
      writeFileSync(breakerPath(d.root), `${new Date().toISOString()} a call reported usage.cost ${usage.cost}\n`);
      append(d.root, { task, kind, ok: false, error: 'billed' });
      throw new CroutonError('billed', 'a call was billed; the breaker is tripped and every later call is refused');
    }
    const choice = (data.choices || [])[0] || {};
    const text = (choice.message || {}).content || '';
    meta = { finish: choice.finish_reason, reasoning_tokens: usage.completion_tokens_details?.reasoning_tokens ?? 0, served: data.model, provider: data.provider, tokens: usage.total_tokens ?? 0 };
    if (!text.trim()) {
      err = meta.finish === 'length' ? 'empty-length' : 'empty';
      if (meta.finish === 'length' && !grown && body.max_tokens < MAX_MAX_TOKENS) { grown = true; body.max_tokens = Math.min(body.max_tokens * 2, MAX_MAX_TOKENS); }
      continue;
    }
    let out = text.trim();
    if (json) { try { out = extractJson(text); } catch { err = 'bad-json'; continue; } }
    append(d.root, { task, kind, effort: EFFORT[kind], max_tokens: body.max_tokens, grown, ok: true, attempts: attempt, ms: Date.now() - t0, ...meta });
    return json ? { json: out, meta: { ...meta, grown } } : { text: out, meta: { ...meta, grown } };
  }
  append(d.root, { task, kind, effort: EFFORT[kind], max_tokens: body.max_tokens, grown, ok: false, error: err, attempts: RETRIES, ms: Date.now() - t0, ...meta });
  throw new CroutonError(err || 'failed', `crouton: ${err || 'failed'}`);
}

/** Measured success per task from .farm/crouton-log.jsonl: the evidence for or against ever giving it more. */
export function status(root = process.cwd()) {
  const rows = existsSync(logPath(root)) ? readFileSync(logPath(root), 'utf-8').split('\n').filter((l) => l.trim()).map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean) : [];
  const by = {};
  for (const r of rows.filter((x) => x.event !== 'response')) {
    const t = (by[r.task] ||= { calls: 0, ok: 0, grown: 0, ms: 0, errors: {} });
    t.calls++; t.ok += r.ok ? 1 : 0; t.grown += r.grown ? 1 : 0; t.ms += r.ms || 0;
    if (!r.ok) t.errors[r.error || '?'] = (t.errors[r.error || '?'] || 0) + 1;
  }
  for (const t of Object.values(by)) { t.avg_ms = t.calls ? Math.round(t.ms / t.calls) : 0; delete t.ms; }
  const done = rows.filter((x) => x.event !== 'response');
  return { calls: done.length, ok_rate: done.length ? +(done.filter((r) => r.ok).length / done.length).toFixed(3) : null, used_today: callsToday(root), daily_calls: DAILY_CALLS,
    tripped: existsSync(breakerPath(root)) ? readFileSync(breakerPath(root), 'utf-8').trim() : null, by_task: by,
    promotion: 'none: Crouton stays off the critical path until a task has 50+ measured calls at 95% success AND a passing `node scripts/crouton-bench.mjs`, and the founder says so' };
}

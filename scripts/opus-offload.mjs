#!/usr/bin/env node
/**
 * opus-offload.mjs — hand a coding task to Claude Opus 5.5 on OpenRouter, apply
 * its files, run the repo's own verification, and feed failures back until it
 * passes or the round limit is hit.
 *
 * WHY: the interactive Claude session has a rate limit; OpenRouter is metered
 * per token instead. The expensive part of a coding task is the model reading
 * files and writing code. This script does both OUTSIDE the session: the
 * session spends a few hundred tokens writing a task brief and reading a short
 * report, instead of tens of thousands reading and writing files itself.
 *
 * Usage:
 *   node scripts/opus-offload.mjs <task.md> [--verify "<shell cmd>"] [--rounds 3]
 *        [--allow <path-or-dir>]... [--model anthropic/claude-opus-5.5] [--dry-run]
 *
 * The task file is plain markdown. Lines of the form `@include <repo path>` are
 * replaced by that file's contents (a missing path aborts BEFORE any spend).
 *
 * The model must answer with whole files only:
 *     === FILE: relative/path ===
 *     <entire file contents>
 *     === END FILE ===
 * Whole files, not diffs: LLM-authored diffs fail to apply far more often than
 * whole files, and a failed apply is a paid round wasted.
 *
 * Safety — model output is data, never code we execute:
 *   - Files are only written inside the repo, and only under --allow paths (by
 *     default: the @include'd files and their directories).
 *   - .git/, .github/, .env*, and secrets are never writable, whatever --allow says.
 *   - The ONLY command ever run is the --verify string YOU pass. Nothing the
 *     model says is executed.
 *   - Nothing is committed. Changes are left on disk for the session to review.
 *
 * Every call is logged (tokens, $ cost) to .farm/offload-log.jsonl (gitignored).
 * Env: OPENROUTER_API_KEY.
 */
import { readFileSync, writeFileSync, existsSync, mkdirSync, appendFileSync } from 'fs';
import { dirname, resolve, relative, sep } from 'path';
import { execSync } from 'child_process';

// Behind HTTPS_PROXY use undici's OWN fetch with its ProxyAgent. Mixing Node's
// built-in fetch with the npm undici dispatcher (what or-call.mjs does) returns
// response bodies still gzip-compressed, so every .json() throws — found by
// testing this script before its first paid call.
let fetch = globalThis.fetch;
const _proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
if (_proxy) {
  try {
    const u = await import('undici');
    const agent = new u.ProxyAgent(_proxy);
    fetch = (url, init = {}) => u.fetch(url, { ...init, dispatcher: agent });
  } catch (e) {
    console.error('WARN: HTTPS_PROXY set but undici missing (' + e.message + '). Run `npm install undici`.');
  }
}

const ROOT = resolve(dirname(new URL(import.meta.url).pathname), '..');
const KEY = process.env.OPENROUTER_API_KEY;
const argv = process.argv.slice(2);
const opt = (name, dflt) => { const i = argv.indexOf(name); return i >= 0 ? argv[i + 1] : dflt; };
const opts = (name) => argv.flatMap((a, i) => (a === name ? [argv[i + 1]] : []));
const TASK = argv[0];
const MODEL = opt('--model', 'anthropic/claude-opus-5.5');
const VERIFY = opt('--verify', '');
const ROUNDS = parseInt(opt('--rounds', '3'), 10);
const DRY = argv.includes('--dry-run');
const MAX_OUT = parseInt(opt('--max-tokens', '64000'), 10);

if (!TASK || !existsSync(TASK)) { console.error('usage: opus-offload.mjs <task.md> [...]'); process.exit(2); }
if (!KEY && !DRY) { console.error('ERROR: OPENROUTER_API_KEY not set'); process.exit(2); }

// ---- expand @include -------------------------------------------------------
const included = [];
const brief = readFileSync(TASK, 'utf8').replace(/^@include\s+(\S+)\s*$/gm, (_, p) => {
  const abs = resolve(ROOT, p);
  if (!existsSync(abs)) { console.error(`ABORT (no spend): @include missing: ${p}`); process.exit(2); }
  included.push(p);
  return `\n=== FILE: ${p} ===\n${readFileSync(abs, 'utf8')}\n=== END FILE ===\n`;
});

// ---- write allowlist -------------------------------------------------------
const allow = opts('--allow').length ? opts('--allow') : [...new Set(included.map(p => dirname(p)))];
const DENY = [/^\.git(\/|$)/, /^\.github(\/|$)/, /(^|\/)\.env/, /secret/i, /\.pem$|\.key$/];
function writable(rel) {
  const abs = resolve(ROOT, rel);
  const r = relative(ROOT, abs);
  if (r.startsWith('..') || r.startsWith(sep) || r === '') return false;
  if (DENY.some(re => re.test(r))) return false;
  return allow.some(a => r === a || r.startsWith(a.replace(/\/$/, '') + '/'));
}

const SYSTEM = `You are a senior Godot 4.3 / GDScript engineer working on a shipping web game.
Rules:
- Answer ONLY with whole files in this exact format, one block per file you change or create:
=== FILE: relative/path/from/repo/root ===
<the ENTIRE file, not a fragment>
=== END FILE ===
- No prose outside the blocks except an optional final line starting "NOTES:".
- GDScript 4.3: never use ":=" when the right side is a Variant (dictionary/array element, untyped call) — declare the type explicitly. Tabs for indentation, never mix spaces.
- Keep every existing public function signature unless the task says otherwise; tests call them.
- Do not invent files, paths or APIs that the task and included files don't show.`;

// ---- API -------------------------------------------------------------------
let pricing = null;
async function price() {
  if (pricing) return pricing;
  try {
    const r = await fetch('https://openrouter.ai/api/v1/models', { headers: { Authorization: `Bearer ${KEY}` } });
    const m = (await r.json()).data.find(x => x.id === MODEL);
    pricing = { in: +m.pricing.prompt, out: +m.pricing.completion };
  } catch { pricing = { in: 0, out: 0 }; }
  return pricing;
}
async function call(messages) {
  const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: MODEL, messages, max_tokens: MAX_OUT, temperature: 0.2 }),
  });
  if (!r.ok) throw new Error(`OpenRouter HTTP ${r.status}: ${(await r.text()).slice(0, 300)}`);
  const j = await r.json();
  const p = await price();
  const u = j.usage || {};
  const cost = (u.prompt_tokens || 0) * p.in + (u.completion_tokens || 0) * p.out;
  mkdirSync(resolve(ROOT, '.farm'), { recursive: true });
  appendFileSync(resolve(ROOT, '.farm/offload-log.jsonl'), JSON.stringify({
    t: new Date().toISOString(), model: MODEL, task: TASK, in: u.prompt_tokens, out: u.completion_tokens, usd: +cost.toFixed(4),
  }) + '\n');
  return { text: j.choices?.[0]?.message?.content || '', cost, u, finish: j.choices?.[0]?.finish_reason };
}

function applyFiles(text) {
  const re = /=== FILE: (.+?) ===\n([\s\S]*?)\n=== END FILE ===/g;
  const written = [], refused = [];
  let m;
  while ((m = re.exec(text))) {
    const rel = m[1].trim();
    if (!writable(rel)) { refused.push(rel); continue; }
    const abs = resolve(ROOT, rel);
    mkdirSync(dirname(abs), { recursive: true });
    writeFileSync(abs, m[2].endsWith('\n') ? m[2] : m[2] + '\n');
    written.push(rel);
  }
  return { written, refused };
}

function verify() {
  if (!VERIFY) return { ok: true, out: '(no --verify given)' };
  try {
    const out = execSync(VERIFY, { cwd: ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 900000, maxBuffer: 64 << 20 });
    return { ok: true, out };
  } catch (e) {
    return { ok: false, out: `${e.stdout || ''}\n${e.stderr || ''}` };
  }
}
// Keep only the lines a model needs: failures and script errors, then the tail.
const trim = (s) => {
  const lines = s.split('\n');
  const key = lines.filter(l => /FAIL|SCRIPT ERROR|Parse Error|ERROR: .*\.gd|error:/i.test(l) && !/Parameter "m" is null/.test(l));
  return [...new Set(key)].slice(0, 60).join('\n') + '\n--- tail ---\n' + lines.slice(-40).join('\n');
};

// ---- run -------------------------------------------------------------------
const messages = [{ role: 'system', content: SYSTEM }, { role: 'user', content: brief }];
const est = Math.ceil((SYSTEM.length + brief.length) / 3.6);
const p0 = KEY ? await price() : { in: 0, out: 0 };
console.log(`task ${TASK} | model ${MODEL} | ~${est} input tokens (~$${(est * p0.in).toFixed(2)} in per round)`);
console.log(`writable: ${allow.join(', ') || '(none)'}`);
if (DRY) process.exit(0);

let total = 0;
for (let round = 1; round <= ROUNDS; round++) {
  const res = await call(messages);
  total += res.cost;
  const { written, refused } = applyFiles(res.text);
  const notes = (res.text.match(/^NOTES:.*$/m) || [''])[0];
  console.log(`round ${round}: wrote [${written.join(', ')}]${refused.length ? ` REFUSED [${refused.join(', ')}]` : ''} | ${res.u.completion_tokens} out tok | $${res.cost.toFixed(3)}${res.finish === 'length' ? ' | TRUNCATED (raise --max-tokens)' : ''}`);
  if (notes) console.log('  ' + notes.slice(0, 300));
  if (!written.length) { console.log('model returned no applicable files — stopping'); break; }
  const v = verify();
  console.log(`  verify: ${v.ok ? 'PASS' : 'FAIL'}`);
  if (v.ok) { console.log(`DONE in ${round} round(s), $${total.toFixed(3)} total. Review with: git diff`); process.exit(0); }
  messages.push({ role: 'assistant', content: res.text });
  messages.push({ role: 'user', content: `Verification failed. Relevant output:\n\n${trim(v.out)}\n\nReturn corrected WHOLE files in the same format.` });
}
console.log(`STOPPED after ${ROUNDS} round(s), $${total.toFixed(3)} total — verification not passing. Changes are on disk; review with git diff.`);
process.exit(1);

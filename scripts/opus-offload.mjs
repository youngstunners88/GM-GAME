#!/usr/bin/env node
/**
 * opus-offload.mjs — hand a coding task to a model on OpenRouter (Claude Opus 5.5 by default, Kimi K3.1 through
 * scripts/kimi-offload.sh), apply its changes, run the repo's own verification, and feed failures back until it
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
 *        [--allow <path-or-dir>]... [--model anthropic/claude-opus-5.5] [--max-tokens 64000]
 *        [--idle-sec 300] [--allow-whole] [--dry-run]
 *
 * The task file is plain markdown. Lines of the form `@include <repo path>` are
 * replaced by that file's contents (a missing path aborts BEFORE any spend).
 *
 * The model answers with change blocks:
 *   - a NEW file as a whole file:            === FILE: path === ... === END FILE ===
 *   - an EXISTING file as exact edits:       === EDIT: path === <<<<<<< SEARCH ... ======= ... >>>>>>> REPLACE === END EDIT ===
 * Whole-file rewrites of existing files are refused (unless --allow-whole): on 2026-10-27 Kimi K3.1's whole-file answers
 * silently changed lines nobody asked for (a sun-shaft gradient, forest tree heights, a voiced dialogue line, a broken
 * clampf). An edit can only touch the lines it quotes, and each SEARCH must match the current file exactly once, so the
 * review is the hunks the task asked for and nothing else.
 *
 * Transport: the request is STREAMED (bytes keep flowing while the model thinks, so a proxy or NAT does not drop an idle
 * connection), a stream silent for --idle-sec is aborted, and a dropped connection - at connect or mid-body - is retried
 * twice. A dropped stream may already have been billed by the provider; it is logged as `dropped`.
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
const ALLOW_WHOLE = argv.includes('--allow-whole');
const MAX_OUT = parseInt(opt('--max-tokens', '64000'), 10);
const IDLE_MS = parseInt(opt('--idle-sec', '300'), 10) * 1000;

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
// Files that existed before this run are edited, never rewritten; files the model creates in this run may be resent whole.
const preexisting = (rel) => !createdThisRun.has(rel) && existsSync(resolve(ROOT, rel));
const createdThisRun = new Set();

const SYSTEM = `You are a senior Godot 4.3 / GDScript engineer working on a shipping web game.
Answer ONLY with change blocks, in exactly these formats:
- To CREATE a file that does not exist yet, give the whole file:
=== FILE: relative/path/from/repo/root ===
<the ENTIRE new file>
=== END FILE ===
- To CHANGE a file that already exists, give exact SEARCH/REPLACE edits - NEVER the whole file:
=== EDIT: relative/path/from/repo/root ===
<<<<<<< SEARCH
<whole lines copied EXACTLY from the current file (same tabs, spaces and text), enough lines to be unique>
=======
<the lines that replace them>
>>>>>>> REPLACE
=== END EDIT ===
  One EDIT block may hold several SEARCH/REPLACE pairs; they apply in order, each to the file as the previous pair left it.
  Each SEARCH must match the current file exactly once. Keep SEARCH short: the lines you change plus 1-3 lines of context.
Rules:
- Change ONLY what the task asks for. Never reformat, reorder, rename, re-word strings, comments or dialogue, or "tidy" any
  line outside the task. Dialogue text is matched against recorded voice lines: one changed word silences a line. A reviewer
  reads every hunk and rejects unrelated ones.
- No prose outside the blocks except an optional final line starting "NOTES:".
- GDScript 4.3: never use ":=" when the right side is a Variant (dictionary/array element, untyped call) — declare the type
  explicitly. Keep each file's own indentation (tabs in most files; some files use spaces - copy what the file uses).
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
class HttpError extends Error {}
const logCall = (rec) => {
  mkdirSync(resolve(ROOT, '.farm'), { recursive: true });
  appendFileSync(resolve(ROOT, '.farm/offload-log.jsonl'), JSON.stringify({ t: new Date().toISOString(), model: MODEL, task: TASK, ...rec }) + '\n');
};

// One streamed completion. Transport failures (connect, mid-body, idle) retry twice; HTTP and provider errors do not - a 4xx
// is a bug to fix, not a reason to pay again.
async function call(messages) {
  for (let attempt = 1; ; attempt++) {
    const ac = new AbortController();
    let idle = null;
    const arm = () => { clearTimeout(idle); idle = setTimeout(() => ac.abort(new Error(`no bytes for ${IDLE_MS / 1000}s`)), IDLE_MS); };
    let text = '';
    try {
      arm();
      const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: { Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: MODEL, messages, max_tokens: MAX_OUT, temperature: 0.2, stream: true, usage: { include: true } }),
        signal: ac.signal,
      });
      if (!r.ok) throw new HttpError(`OpenRouter HTTP ${r.status}: ${(await r.text()).slice(0, 300)}`);
      let usage = null, finish = null, buf = '';
      const dec = new TextDecoder();
      for await (const chunk of r.body) {
        arm();
        buf += dec.decode(chunk, { stream: true });
        let nl;
        while ((nl = buf.indexOf('\n')) >= 0) {
          const line = buf.slice(0, nl).trim();
          buf = buf.slice(nl + 1);
          if (!line.startsWith('data:')) continue;          // ": OPENROUTER PROCESSING" keep-alive comments
          const data = line.slice(5).trim();
          if (data === '[DONE]') continue;
          let j;
          try { j = JSON.parse(data); } catch { continue; }
          if (j.error) throw new HttpError(`OpenRouter stream error: ${JSON.stringify(j.error).slice(0, 300)}`);
          const ch = j.choices?.[0];
          if (ch?.delta?.content) text += ch.delta.content;
          if (ch?.finish_reason) finish = ch.finish_reason;
          if (j.usage) usage = j.usage;
        }
      }
      clearTimeout(idle);
      const p = await price();
      const u = usage || {};
      const cost = typeof u.cost === 'number' ? u.cost : (u.prompt_tokens || 0) * p.in + (u.completion_tokens || 0) * p.out;
      logCall({ in: u.prompt_tokens, out: u.completion_tokens, usd: +cost.toFixed(4) });
      return { text, cost, u, finish };
    } catch (e) {
      clearTimeout(idle);
      if (e instanceof HttpError) throw e;
      logCall({ dropped: true, chars: text.length, why: String(e.cause?.code || e.message).slice(0, 120) });
      if (attempt >= 3) throw e;
      console.log(`  network error (${e.cause?.code || e.message}) after ${text.length} chars; retry ${attempt}/2 in ${attempt * 15}s`);
      await new Promise(res => setTimeout(res, attempt * 15000));
    }
  }
}

// ---- apply -----------------------------------------------------------------
// Find `search` in `src` as whole lines, exactly once. Falls back to ignoring trailing whitespace per line.
function locate(src, search) {
  const hits = [];
  for (let i = src.indexOf(search); i >= 0; i = src.indexOf(search, i + 1)) {
    const end = i + search.length;
    if ((i === 0 || src[i - 1] === '\n') && (end === src.length || src[end] === '\n')) hits.push([i, end]);
  }
  if (hits.length === 1) return { at: hits[0] };
  if (hits.length > 1) return { err: `matches ${hits.length} places; add context lines to make it unique` };
  const lines = src.split('\n');
  const want = search.split('\n').map(l => l.trimEnd());
  const starts = [];
  for (let i = 0; i + want.length <= lines.length; i++) {
    if (want.every((w, k) => lines[i + k].trimEnd() === w)) starts.push(i);
  }
  if (starts.length !== 1) return { err: starts.length ? `matches ${starts.length} places; add context lines` : 'not found in the current file (copy the lines exactly)' };
  const off = (n) => lines.slice(0, n).reduce((s, l) => s + l.length + 1, 0);
  const a = off(starts[0]);
  return { at: [a, a + lines.slice(starts[0], starts[0] + want.length).join('\n').length] };
}

function applyBlocks(text) {
  const written = [], refused = [], failed = [];
  const fileRe = /=== FILE: (.+?) ===\n([\s\S]*?)\n=== END FILE ===/g;
  for (let m; (m = fileRe.exec(text));) {
    const rel = relative(ROOT, resolve(ROOT, m[1].trim()));
    if (!writable(rel)) { refused.push(`${rel} (not writable)`); continue; }
    if (preexisting(rel) && !ALLOW_WHOLE) { refused.push(`${rel} (whole file for an existing file: send EDIT blocks)`); continue; }
    const abs = resolve(ROOT, rel);
    if (!existsSync(abs)) createdThisRun.add(rel);
    mkdirSync(dirname(abs), { recursive: true });
    writeFileSync(abs, m[2].endsWith('\n') ? m[2] : m[2] + '\n');
    written.push(rel);
  }
  const editRe = /=== EDIT: (.+?) ===\n([\s\S]*?)\n=== END EDIT ===/g;
  for (let m; (m = editRe.exec(text));) {
    const rel = relative(ROOT, resolve(ROOT, m[1].trim()));
    if (!writable(rel)) { refused.push(`${rel} (not writable)`); continue; }
    const abs = resolve(ROOT, rel);
    if (!existsSync(abs)) { failed.push({ rel, why: 'EDIT for a file that does not exist (create it with a FILE block)' }); continue; }
    let src = readFileSync(abs, 'utf8');
    const pairRe = /<<<<<<< SEARCH\n([\s\S]*?)\n=======\n([\s\S]*?)>>>>>>> REPLACE/g;
    let n = 0, bad = null;
    for (let p; (p = pairRe.exec(m[2]));) {
      n++;
      const search = p[1], repl = p[2].replace(/\n$/, '');
      if (!search.trim()) { bad = `pair ${n}: empty SEARCH`; break; }
      const loc = locate(src, search);
      if (loc.err) { bad = `pair ${n}: SEARCH ${loc.err}\n${search.split('\n').slice(0, 6).join('\n')}`; break; }
      src = src.slice(0, loc.at[0]) + repl + src.slice(loc.at[1]);
    }
    if (!n) bad = 'no SEARCH/REPLACE pairs in the block';
    if (bad) { failed.push({ rel, why: bad }); continue; }       // all pairs of a block or none: a half-applied file is worse
    writeFileSync(abs, src);
    written.push(`${rel} (${n} edit${n > 1 ? 's' : ''})`);
  }
  return { written, refused, failed };
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
  const { written, refused, failed } = applyBlocks(res.text);
  const notes = (res.text.match(/^NOTES:.*$/m) || [''])[0];
  console.log(`round ${round}: wrote [${written.join(', ')}]${refused.length ? ` REFUSED [${refused.join('; ')}]` : ''}${failed.length ? ` FAILED [${failed.map(f => f.rel).join(', ')}]` : ''} | ${res.u.completion_tokens} out tok | $${res.cost.toFixed(3)}${res.finish === 'length' ? ' | TRUNCATED (raise --max-tokens)' : ''}`);
  if (notes) console.log('  ' + notes.slice(0, 600));
  messages.push({ role: 'assistant', content: res.text });
  if (refused.length || failed.length) {
    // Fix the change set before paying for a verify: say exactly what did not apply, with the current text of those files.
    const cur = [...new Set(failed.map(f => f.rel))].map(rel => `=== FILE: ${rel} (CURRENT, after your applied edits) ===\n${readFileSync(resolve(ROOT, rel), 'utf8')}\n=== END FILE ===`).join('\n');
    messages.push({ role: 'user', content: `Some of your changes were NOT applied (everything else was).\n${refused.map(r => `- refused: ${r}`).join('\n')}\n${failed.map(f => `- ${f.rel}: ${f.why}`).join('\n')}\n\nResend ONLY the changes that did not apply, as EDIT blocks against the current files below (FILE blocks only for new files).\n${cur}` });
    console.log('  change set incomplete - asking for the missing edits before verifying');
    continue;
  }
  if (!written.length) { console.log('model returned no applicable changes — stopping'); break; }
  const v = verify();
  console.log(`  verify: ${v.ok ? 'PASS' : 'FAIL'}`);
  if (v.ok) { console.log(`DONE in ${round} round(s), $${total.toFixed(3)} total. Review with: git diff`); process.exit(0); }
  messages.push({ role: 'user', content: `Verification failed. Relevant output:\n\n${trim(v.out)}\n\nReturn corrections as EDIT blocks against the files as they are now (your earlier edits are applied).` });
}
console.log(`STOPPED after ${ROUNDS} round(s), $${total.toFixed(3)} total — verification not passing. Changes are on disk; review with git diff.`);
process.exit(1);

#!/usr/bin/env node
/**
 * crouton-call.mjs — dispatch one prompt file to the free Crouton Alpha lane (see scripts/lib/crouton.mjs for the guards).
 *
 *   node scripts/crouton-call.mjs <prompt-file> [output-file] [--kind classify|review|draft|digest] [--json]
 *        [--max-tokens N] [--image <path>]... [--task name] [--dry-run]
 *   node scripts/crouton-call.mjs --status
 *
 * The prompt file may use `@include <path>` lines (inlined; private or missing paths abort before anything is sent).
 * Output is UNVALIDATED model output: Claude verifies every claim against the real files before it informs a commit or STATUS entry.
 * Env: OPENROUTER_API_KEY (required). In this sandbox run with NODE_USE_ENV_PROXY=1 NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt.
 */
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { ask, expandIncludes, guardText, verifyFree, status, CroutonError, DEFAULT_MODEL, EFFORT, MIN_MAX_TOKENS } from './lib/crouton.mjs';

const args = process.argv.slice(2);
const flag = (n) => args.includes(n);
const val = (n, dflt) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : dflt; };
const images = args.flatMap((a, i) => (a === '--image' ? [args[i + 1]] : []));
const skip = new Set(['--kind', '--max-tokens', '--task', '--image']);
const positional = args.filter((a, i) => !a.startsWith('--') && !skip.has(args[i - 1]));
const [PROMPT_FILE, OUTPUT_FILE] = positional;

if (flag('--status')) { console.log(JSON.stringify(status(), null, 1)); process.exit(0); }
if (!PROMPT_FILE) { console.error('Usage: node scripts/crouton-call.mjs <prompt-file> [output-file] [--kind K] [--json] [--max-tokens N] [--image P]... [--task T] [--dry-run] | --status'); process.exit(1); }
if (!existsSync(PROMPT_FILE)) { console.error(`ERROR: prompt file not found: ${PROMPT_FILE}`); process.exit(1); }

const kind = val('--kind', 'review');
const task = val('--task', 'cli');
try {
  const { text: prompt, included } = expandIncludes(readFileSync(PROMPT_FILE, 'utf-8'));
  if (flag('--dry-run')) {
    guardText(prompt);
    await verifyFree(DEFAULT_MODEL, { fetch: globalThis.fetch, root: process.cwd(), now: () => new Date() });
    console.log(`=== DRY RUN === model ${DEFAULT_MODEL} (free, verified) | kind ${kind} -> reasoning ${EFFORT[kind]} | files inlined ${included} | images ${images.length}`);
    console.log(`est. input ~${Math.ceil(prompt.length / 4)} tokens | max_tokens >= ${MIN_MAX_TOKENS} | cost $0 | nothing sent`);
    process.exit(0);
  }
  const r = await ask({ prompt, kind, task, json: flag('--json'), images, maxTokens: parseInt(val('--max-tokens', ''), 10) || undefined });
  const body = r.json !== undefined ? JSON.stringify(r.json, null, 1) : r.text;
  console.log(`=== CROUTON DONE === finish ${r.meta.finish} | reasoning tokens ${r.meta.reasoning_tokens} | tokens ${r.meta.tokens}${r.meta.grown ? ' | budget doubled once' : ''} | cost $0`);
  if (OUTPUT_FILE) {
    writeFileSync(OUTPUT_FILE, `<!-- crouton-alpha (free stealth preview) | kind ${kind} | prompt ${PROMPT_FILE} | files inlined ${included}\n     NOTE: unvalidated model output; the provider may keep prompts. Claude must verify every claim against the real files. -->\n\n${body}\n`);
    console.log(`Saved to: ${OUTPUT_FILE}`);
  } else console.log('\n' + body);
} catch (e) {
  if (e instanceof CroutonError) { console.error(`crouton: ${e.message}`); process.exit(e.code === 'tripped' || e.code === 'billed' ? 7 : 2); }
  throw e;
}

#!/usr/bin/env node
/**
 * or-call.mjs — OpenRouter dispatch wrapper for GM-GAME multi-model work.
 *
 * Usage:
 *   node scripts/or-call.mjs <model-id> <prompt-file> [output-file] [--dry-run]
 *
 * Examples:
 *   node scripts/or-call.mjs moonshotai/kimi-k3 prompts/kimi-icp-audit.md out.md --dry-run
 *   node scripts/or-call.mjs x-ai/grok-4.5 prompts/grok-identity-strategy.md out.md
 *
 * WHY THIS IS NOT THE VERSION FROM THE KIT DOC — three things had to change
 * before a dispatch could produce anything useful:
 *
 *  1. @include EXPANSION. The original sent prompt text only. The co-worker
 *     models have no access to this repository, so a prompt saying "review
 *     lil-blunt-icp/src/price_feed.mo" got a model that could not see the file:
 *     it either answers FILE NOT FOUND for everything (paid, useless) or
 *     invents the contents (paid, worse than useless). Prompts now write
 *     `@include <path>` and the real file is inlined before sending.
 *
 *  2. MISSING FILES ABORT. If an @include path does not exist we exit non-zero
 *     WITHOUT calling the API. A prompt citing a stale path is a bug to fix,
 *     not a question to pay a model to be confused by. Five of the six paths in
 *     the shipped prompt pack were wrong.
 *
 *  3. LIVE PRICING + --dry-run. The kit hardcoded Grok at ~$0.001/1M. The real
 *     rate is $1.25-2.00/1M — a ~1000x under-estimate on someone else's card.
 *     Rates are now fetched from /models at call time, and --dry-run prints the
 *     estimated cost without spending anything.
 *
 * Env: OPENROUTER_API_KEY (required)
 */

import { readFileSync, writeFileSync, existsSync } from 'fs';
import { dirname, resolve } from 'path';

// Route through the agent proxy when one is present. This sandbox's egress goes
// via HTTPS_PROXY, but Node's global fetch (undici) does NOT honor that env var
// on its own — unlike curl — so without this the wrapper gets a hard 403 from
// the proxy while a plain `curl` to the same host succeeds (exactly the S10/S11
// symptom). Best-effort + guarded: no proxy env, or no undici installed, leaves
// behaviour unchanged (CI, or local dev with no proxy).
const _proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
if (_proxy) {
  try {
    const { ProxyAgent, setGlobalDispatcher } = await import('undici');
    setGlobalDispatcher(new ProxyAgent(_proxy));
  } catch (e) {
    console.error('WARN: HTTPS_PROXY is set but undici ProxyAgent is unavailable (' +
      e.message + ') — OpenRouter fetch may 403. Run `npm install undici`.');
  }
}

const API_KEY = process.env.OPENROUTER_API_KEY;
if (!API_KEY) {
  console.error('ERROR: OPENROUTER_API_KEY not set');
  process.exit(1);
}

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const positional = args.filter((a) => !a.startsWith('--'));
const [MODEL, PROMPT_FILE, OUTPUT_FILE] = positional;

if (!MODEL || !PROMPT_FILE) {
  console.error('Usage: node or-call.mjs <model-id> <prompt-file> [output-file] [--dry-run]');
  process.exit(1);
}
if (!existsSync(PROMPT_FILE)) {
  console.error(`ERROR: prompt file not found: ${PROMPT_FILE}`);
  process.exit(1);
}

/**
 * Expand `@include <path>` lines into fenced file contents.
 * Paths are resolved relative to the repo root (cwd), which is how every other
 * script in this project refers to files.
 */
function expandIncludes(text, promptPath) {
  const missing = [];
  const out = [];
  let included = 0;
  for (const line of text.split('\n')) {
    const m = line.match(/^@include\s+(\S+)\s*$/);
    if (!m) { out.push(line); continue; }
    const rel = m[1];
    const abs = resolve(process.cwd(), rel);
    if (!existsSync(abs)) { missing.push(rel); continue; }
    const body = readFileSync(abs, 'utf-8');
    const fence = rel.endsWith('.mo') ? 'motoko'
      : rel.endsWith('.gd') ? 'gdscript'
      : rel.endsWith('.mjs') ? 'javascript'
      : rel.endsWith('.json') ? 'json' : '';
    out.push(`--- FILE: ${rel} (${body.split('\n').length} lines) ---`);
    out.push('```' + fence);
    out.push(body.replace(/\s+$/, ''));
    out.push('```');
    included++;
  }
  return { text: out.join('\n'), missing, included, promptPath };
}

const raw = readFileSync(PROMPT_FILE, 'utf-8');
const { text: prompt, missing, included } = expandIncludes(raw, PROMPT_FILE);

if (missing.length) {
  console.error('ERROR: @include paths do not exist — refusing to dispatch:');
  for (const p of missing) console.error(`  ${p}`);
  console.error('\nFix the prompt file. Paying a model to reason about files it');
  console.error('cannot see produces confident nonsense, not a review.');
  process.exit(2);
}

// ---- live pricing ---------------------------------------------------------

/**
 * Returns {input, output, context} | {error} — never a bare null.
 *
 * The distinction matters: an earlier version swallowed every exception and
 * reported "model not found", so one transient fetch blip sent me hunting for a
 * model ID that was correct all along. A wrong diagnosis costs more time than
 * the failure it describes.
 */
async function getRates(model, attempt = 1) {
  let json;
  try {
    const res = await fetch('https://openrouter.ai/api/v1/models', {
      headers: { Authorization: `Bearer ${API_KEY}` },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    json = await res.json();
  } catch (e) {
    if (attempt === 1) {
      await new Promise((r) => setTimeout(r, 2000));
      return getRates(model, 2);
    }
    return { error: `could not reach the model list (${e.message})` };
  }
  const hit = (json.data || []).find((m) => m.id === model);
  if (!hit) return { error: `model "${model}" is not in OpenRouter's catalogue` };
  return {
    input: parseFloat(hit.pricing.prompt) * 1e6,
    output: parseFloat(hit.pricing.completion) * 1e6,
    context: hit.context_length,
  };
}

// Rough but honest: ~4 chars/token for English + code.
const estInputTokens = Math.ceil(prompt.length / 4);

const rates = await getRates(MODEL);
if (rates.error) {
  console.error(`ERROR: ${rates.error}`);
  console.error('Model IDs change. List them with:');
  console.error('  curl -s https://openrouter.ai/api/v1/models -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq -r ".data[].id"');
  process.exit(3);
}

// Reasoning models burn this budget on hidden thinking before emitting a single
// visible character, so 8000 (the kit's value) returned an empty answer from
// kimi-k3 while still billing for the thinking. Overridable per call.
const MAX_OUTPUT = parseInt(process.env.OR_MAX_TOKENS || '', 10) || 24000;
const worstCase = (estInputTokens * rates.input + MAX_OUTPUT * rates.output) / 1e6;

console.log('=== DISPATCH PLAN ===');
console.log(`Model:          ${MODEL}`);
console.log(`Prompt file:    ${PROMPT_FILE}`);
console.log(`Files inlined:  ${included}`);
console.log(`Est. input:     ~${estInputTokens} tokens (context limit ${rates.context})`);
console.log(`Rates:          $${rates.input}/1M in, $${rates.output}/1M out`);
console.log(`Worst-case cost: $${worstCase.toFixed(4)} (at max_tokens=${MAX_OUTPUT})`);

if (estInputTokens > rates.context * 0.9) {
  console.error('\nERROR: prompt is close to or over the model context limit.');
  process.exit(4);
}

if (DRY_RUN) {
  console.log('\n--dry-run: nothing sent, nothing spent.');
  process.exit(0);
}

// ---- dispatch with retry --------------------------------------------------

const body = {
  model: MODEL,
  messages: [
    {
      role: 'system',
      content:
        'You are a specialized co-worker on a game development team. Be concise and '
        + 'specific. Never invent API methods, file paths, or functions that do not '
        + 'appear in the files provided to you. If something you need was not provided, '
        + 'say exactly what is missing rather than guessing.',
    },
    { role: 'user', content: prompt },
  ],
  temperature: MODEL.includes('kimi') ? 0.2 : 0.5,
  max_tokens: MAX_OUTPUT,
};

async function dispatch(attempt = 1) {
  const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://github.com/youngstunners88/GM-GAME',
      'X-Title': 'GM-GAME Multi-Model Orchestrator',
    },
    body: JSON.stringify(body),
  });

  // Per the skill's retry rule: one retry on 429/5xx, then give up and let the
  // caller fall back to Claude-only rather than burning budget on a loop.
  if ((res.status === 429 || res.status >= 500) && attempt === 1) {
    console.error(`HTTP ${res.status} — retrying once in 10s...`);
    await new Promise((r) => setTimeout(r, 10000));
    return dispatch(2);
  }

  const json = await res.json();
  if (json.error) {
    console.error(`API ERROR: ${json.error.message}`);
    process.exit(5);
  }

  const choice = json.choices?.[0] ?? {};
  const msg = choice.message ?? {};
  let content = msg.content ?? '';

  // Reasoning models (kimi-k3 among them) spend the output budget on hidden
  // thinking tokens first. If max_tokens runs out mid-thought you get a
  // perfectly successful HTTP 200 with an EMPTY content string — which reads
  // as "the model had nothing to say" when it actually means "you did not pay
  // for enough tokens to reach the answer". Report the real cause.
  if (!content.trim()) {
    const reasoning = msg.reasoning ?? msg.reasoning_content ?? '';
    console.error('ERROR: empty content.');
    console.error(`  finish_reason: ${choice.finish_reason ?? 'unknown'}`);
    console.error(`  completion_tokens: ${json.usage?.completion_tokens ?? 0}`);
    console.error(`  reasoning chars: ${reasoning.length}`);
    if (choice.finish_reason === 'length') {
      console.error('  -> The output budget was exhausted before any visible answer.');
      console.error(`     Raise MAX_OUTPUT (currently ${MAX_OUTPUT}) and retry.`);
    }
    process.exit(6);
  }

  const u = json.usage || {};
  const cost = ((u.prompt_tokens || 0) * rates.input + (u.completion_tokens || 0) * rates.output) / 1e6;

  console.log('\n=== DISPATCH COMPLETE ===');
  console.log(`Input tokens:  ${u.prompt_tokens || 0}`);
  console.log(`Output tokens: ${u.completion_tokens || 0}`);
  console.log(`Actual cost:   $${cost.toFixed(4)}`);

  if (OUTPUT_FILE) {
    const header = [
      `<!-- dispatched: ${MODEL}`,
      `     prompt: ${PROMPT_FILE}`,
      `     files inlined: ${included}`,
      `     tokens: ${u.prompt_tokens || 0} in / ${u.completion_tokens || 0} out`,
      `     cost: $${cost.toFixed(4)}`,
      `     NOTE: unvalidated model output. Claude must verify every claim`,
      `     against the real files before any of it informs code. -->`,
      '',
    ].join('\n');
    writeFileSync(OUTPUT_FILE, header + content);
    console.log(`Saved to: ${OUTPUT_FILE}`);
  } else {
    console.log('\n=== RESPONSE ===\n');
    console.log(content);
  }
}

await dispatch();

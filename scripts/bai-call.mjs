#!/usr/bin/env node
/**
 * bai-call.mjs — B.AI dispatch wrapper (Anthropic Messages API compatible).
 *
 * B.AI (https://api.b.ai) is an Anthropic-compatible aggregator the founder
 * provisioned as EXTRA, Claude-compatible capacity for multi-model work when
 * the primary Claude subscription is rate-limited. This is the "extra hands"
 * lane from PROMPT_SESSION6.
 *
 * WHY A SCRIPT AND NOT AN ANTHROPIC_BASE_URL OVERRIDE IN settings.local.json:
 * pointing THIS running Claude Code process's ANTHROPIC_BASE_URL at b.ai would
 * hijack the orchestrator's own model routing mid-session (and for every future
 * session that loads the same settings file). B.AI is meant to be an ADDITIONAL
 * lane, not a replacement for the main process — so it is dispatched from a
 * standalone script exactly like OpenRouter (scripts/or-call.mjs), leaving the
 * primary process untouched.
 *
 * Usage:
 *   node scripts/bai-call.mjs <model-id> <prompt-file> [output-file] [--dry-run]
 *
 * Env: B_AI_API_KEY (required). The key is read from the environment and never
 * printed, logged, or written to any file — only its presence is asserted.
 *
 * @include <path> expansion works the same as or-call.mjs: co-worker models
 * cannot see this repo, so referenced files are inlined before sending.
 *
 * Available (non-premium) models on this account include `kimi-k2.5`. Premium
 * models (glm-*, gpt-*, claude-*) return access_denied until a deposit is made.
 */

import { readFileSync, writeFileSync, existsSync } from 'fs';
import { resolve } from 'path';

const API_KEY = process.env.B_AI_API_KEY;
if (!API_KEY) {
  console.error('ERROR: B_AI_API_KEY not set — cannot dispatch to B.AI.');
  process.exit(2);
}
const BASE_URL = process.env.B_AI_BASE_URL || 'https://api.b.ai';

const [, , modelId, promptFile, outputFile] = process.argv;
const dryRun = process.argv.includes('--dry-run');
if (!modelId || !promptFile) {
  console.error('Usage: node scripts/bai-call.mjs <model-id> <prompt-file> [output-file] [--dry-run]');
  process.exit(2);
}
if (!existsSync(promptFile)) {
  console.error(`ERROR: prompt file not found: ${promptFile}`);
  process.exit(2);
}

// --- @include expansion: inline referenced repo files (models can't see them) ---
let prompt = readFileSync(promptFile, 'utf8');
prompt = prompt.replace(/^@include\s+(.+)$/gm, (_m, p) => {
  const path = resolve(p.trim());
  if (!existsSync(path)) {
    console.error(`ERROR: @include path does not exist: ${p.trim()}`);
    process.exit(2);
  }
  const body = readFileSync(path, 'utf8');
  return `\n----- BEGIN ${p.trim()} -----\n${body}\n----- END ${p.trim()} -----\n`;
});

const maxTokens = parseInt(process.env.BAI_MAX_TOKENS || '8000', 10);

if (dryRun) {
  console.log(`[dry-run] model=${modelId} base=${BASE_URL} prompt_chars=${prompt.length} max_tokens=${maxTokens}`);
  process.exit(0);
}

const body = {
  model: modelId,
  max_tokens: maxTokens,
  messages: [{ role: 'user', content: prompt }],
};

const res = await fetch(`${BASE_URL}/v1/messages`, {
  method: 'POST',
  headers: {
    'x-api-key': API_KEY,
    'anthropic-version': '2023-06-01',
    'content-type': 'application/json',
  },
  body: JSON.stringify(body),
});

const json = await res.json();
if (!res.ok || json.error) {
  console.error(`B.AI error (${res.status}): ${JSON.stringify(json.error || json)}`);
  process.exit(1);
}
const text = (json.content || []).map((c) => c.text || '').join('').trim();
if (!text) {
  console.error(`B.AI returned no text. stop_reason=${json.stop_reason} usage=${JSON.stringify(json.usage)}`);
  process.exit(1);
}
if (outputFile) {
  writeFileSync(outputFile, text);
  console.error(`wrote ${text.length} chars -> ${outputFile} (model=${modelId}, stop=${json.stop_reason})`);
} else {
  console.log(text);
}

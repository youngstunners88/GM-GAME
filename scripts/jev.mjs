#!/usr/bin/env node
/**
 * Jev 1.14: direct TypeSafe by user choice; explicit OpenRouter compatibility.
 * Text uses JSON, images use documented multipart file-byte assets and an
 * experimental header. Never base64 prose, chat completions or provider fallback.
 * Credentials stay with their provider. See the routed skill for input budgets,
 * pending context limits, live transport/image controls and response receipts.
 *
 * node scripts/jev.mjs --request request.json --dry-run
 * node scripts/jev.mjs --request request.json --send
 * Flags: --experimental-images (OpenRouter probe), --long-context (header, 262k server limit).
 * Legacy metric CLI: --from-gate gate.json (0 ship/1 block/2 uncertain/3 error).
 */

import { prepareRequest, validateResponse, DEFAULT_MODEL, PROVIDERS } from './jev-request.mjs';
import { setGlobalProxyFromEnv } from 'node:http';
import { readFile } from 'node:fs/promises';
// Node 24 honours the configured proxy and NO_PROXY without weakening TLS.
if (process.env.HTTPS_PROXY || process.env.https_proxy) setGlobalProxyFromEnv();

const PROVIDER = process.env.JEV_PROVIDER || (process.env.JEV_MODEL?.startsWith('microsoft/') ? 'openrouter' : 'typesafe');
const MODEL = process.env.JEV_MODEL || PROVIDERS[PROVIDER]?.model || DEFAULT_MODEL;
const TIMEOUT_MS = Number(process.env.JEV_TIMEOUT_MS || 45000);

/**
 * Borrowed from better-call-jev: a probability is NOT a decision until you say
 * what band means what. >=high is a yes, <=low is a no, and the gap between is
 * UNCERTAIN — which must be surfaced, never silently rounded to "ship".
 */
const THRESHOLDS = Object.freeze({
  high: Number(process.env.JEV_THRESHOLD_HIGH || 0.8),
  low: Number(process.env.JEV_THRESHOLD_LOW || 0.2),
});

export function decide(probability, t = THRESHOLDS) {
  if (probability >= t.high) return 'yes';
  if (probability <= t.low) return 'no';
  return 'uncertain';
}

export async function evaluate({ state, questions, provider = PROVIDER, model, assets = {} }, options = {}) {
  if (!Object.hasOwn(PROVIDERS,provider)) throw new Error("Unknown decision provider.");
  model ??= provider === PROVIDER ? MODEL : PROVIDERS[provider].model;
  const endpoint=PROVIDERS[provider].endpoint;
  const key = provider === 'typesafe' ? process.env.TYPESAFE || process.env.TYPESAFE_API_KEY : process.env.OPENROUTER_API_KEY || process.env.OPENROUTER_API;
  if (!key) throw new Error(`Missing configured ${provider} credential.`);
  if (process.env.JEV_ENDPOINT && process.env.JEV_ENDPOINT !== endpoint) throw new Error('Endpoint must match the explicitly selected provider.');
  const request = options.prepared ?? await prepareRequest({state,questions,provider,model,assets}, options);
  const res = await fetch(endpoint, {
    method:'POST', headers:{...request.headers,Authorization:`Bearer ${key}`},
    body:request.body, signal:AbortSignal.timeout(TIMEOUT_MS), redirect:'error',
  });
  if (!res.ok) {
    // Show the provider's own error text (never headers/keys): 'Model X does not exist' was invisible and cost a debugging round.
    let detail = '';
    try { const t = await res.text(); detail = (JSON.parse(t)?.error?.message ?? t).toString().slice(0, 300); } catch { /* body unreadable */ }
    throw new Error(`Jev HTTP ${res.status}${detail ? `: ${detail}` : ''}. No automatic retry or provider fallback.`);
  }
  const data=validateResponse(await res.json(),questions);
  // jev-preview / jev-1.14 resolve to 1.14.0, so compare the class, not the literal id.
  if (Object.keys(assets).length && !/1\.14|preview/.test(data.model)) throw new Error("Image response model is not 1.14-class; capability unverified.");
  for (const a of Object.values(data.answers)) {
    if (a.type==='noul') {a.type='boolean';a.probability=a.noul;}
  }
  return data;
}

/** Build a Jev `state` from seam-smudge-gate.py --json output. */
function stateFromGate(rows) {
  const fails = rows.filter((r) => r.verdict === 'FAIL');
  const worst = (k) => rows.reduce((m, r) => Math.max(m, r[k] ?? 0), 0);
  return [
    `Automated image-metric report over ${rows.length} live game frames.`,
    `Frames failing the deterministic gate: ${fails.length}.`,
    `Worst void_frac (fraction of a column that is raw near-black void showing`,
    `through the backdrop; >=0.50 means a black bar is visible): ${worst('void_frac_max').toFixed(2)}.`,
    `Worst seam_frac (fraction of frame height showing a hard vertical`,
    `discontinuity in one column; >=0.55 means a dividing line): ${worst('seam_frac_max').toFixed(2)}.`,
    `Worst green_blob_px (off-palette green pixels; the intentional player cube`,
    `is ~450px, so >=600 means extra green smudges): ${worst('green_blob_px')}.`,
    fails.length ? `Failing frames: ${fails.map((f) => `${f.file}(${f.fails.join('; ')})`).join(' | ')}` : 'No frame failed.',
  ].join(' ');
}

const QUESTIONS = {
  has_dividing_line: {
    type: 'boolean',
    instructions: 'Based only on these metrics, does the build still show a hard dividing line or a black void bar in any frame? A void_frac at or above 0.50, or a seam_frac at or above 0.55, means yes.',
  },
  has_green_smudge: {
    type: 'boolean',
    instructions: 'Based only on these metrics, does the build still show off-palette green smudges? green_blob_px at or above 600 means yes, because the intentional player cube alone accounts for about 450.',
  },
  verdict: {
    type: 'choice',
    instructions: 'Should this build ship to the founder, who has repeatedly rejected builds still showing dividing lines or green smudges?',
    criteria: {
      ship: 'Every frame passed: no void bar, no dividing line, no extra green.',
      block: 'Any frame still shows a dividing line, a void bar, or off-palette green.',
    },
  },
};

async function main() {
  const argv = process.argv.slice(2);
  const get = (f) => { const i = argv.indexOf(f); return i >= 0 ? argv[i + 1] : null; };
  const filename=get('--request');
  if (filename) {
    const request=JSON.parse(await readFile(filename,'utf8'));
    request.provider ??= get('--provider') || PROVIDER;
    request.model ??= request.provider === PROVIDER ? MODEL : PROVIDERS[request.provider]?.model;
    const options={experimentalImages:argv.includes('--experimental-images'),longContext:argv.includes('--long-context')};
    const prepared=await prepareRequest(request,options);
    console.log(JSON.stringify({preflight:prepared.summary},null,2));
    if (argv.includes('--dry-run') || !argv.includes('--send')) return;
    const response=await evaluate(request,{...options,prepared});
    console.log(JSON.stringify({requestDigest:prepared.summary.digest,response},null,2));
    return;
  }
  let state = get('--state');
  let questions = {};

  const gate = get('--from-gate');
  if (gate) {
    const rows = JSON.parse(await (await import('node:fs/promises')).readFile(gate, 'utf8'));
    state = stateFromGate(rows);
    questions = QUESTIONS;
  } else {
    for (let i = 0; i < argv.length; i++) {
      if (argv[i] === '--bool') {
        const [name, ...rest] = argv[i + 1].split('=');
        questions[name] = { type: 'boolean', instructions: rest.join('=') };
      } else if (argv[i] === '--choice') {
        const [name, spec] = argv[i + 1].split('=');
        const criteria = {};
        for (const part of spec.split('|')) {
          const [k, ...d] = part.split(':');
          criteria[k] = d.join(':') || k;
        }
        questions[name] = { type: 'choice', instructions: `Choose for ${name}.`, criteria };
      }
    }
  }
  if (!state || !Object.keys(questions).length) {
    console.error('Usage: node scripts/jev.mjs --from-gate <gate.json>');
    console.error('   or: node scripts/jev.mjs --state "..." --bool "name=instructions" [--choice "name=a:desc|b:desc"]');
    process.exit(3);
  }

  const out = await evaluate({ state, questions });
  console.log(`model: ${out.model}   cost: $${(out.usage?.cost ?? 0).toFixed(6)}`);
  let block = false, uncertain = false;
  for (const [name, a] of Object.entries(out.answers || {})) {
    if (a.type === 'boolean') {
      const d = decide(a.probability);
      console.log(`  ${name}: probability=${a.probability.toFixed(3)} -> ${d}`);
      if (name.startsWith('has_') && d !== 'no') { if (d === 'yes') block = true; else uncertain = true; }
    } else if (a.type === 'choice') {
      console.log(`  ${name}: ${a.choice} (confidence ${a.confidence?.toFixed?.(2) ?? '?'}) ${JSON.stringify(a.probabilities)}`);
      if (a.choice !== 'ship') block = true;
    } else {
      console.log(`  ${name}: ${JSON.stringify(a)}`);
    }
  }
  const verdict = block ? 'BLOCK' : uncertain ? 'UNCERTAIN' : 'SHIP';
  console.log(`\nJEV VERDICT: ${verdict}`);
  process.exit(block ? 1 : uncertain ? 2 : 0);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((e) => { console.error(String(e.message || e)); process.exit(3); });
}

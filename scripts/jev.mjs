#!/usr/bin/env node
/**
 * JEV DECISION CLIENT — ship/block verdicts on NUMBERS.
 *
 * Why this exists rather than the upstream plugin
 * ------------------------------------------------
 * jukkatupamaki/better-call-jev is a good piece of work and this file borrows
 * its best idea outright (see THRESHOLDS below). It is not vendored because its
 * only implemented transport is the Vercel AI Gateway
 * (https://ai-gateway.vercel.sh/v1/evaluate) behind a NEW `JEV_API_KEY` from a
 * Vercel account. Jev is already reachable here on the OPENROUTER_API_KEY this
 * project already has, so adopting it would add a second credential and a
 * second bill for the same model. Transport differs; the question contract is
 * kept identical so code written against one reads the same as the other.
 *
 * Schema mapping (verified live 2026-09-20)
 * -----------------------------------------
 *   upstream/Vercel            OpenRouter /api/alpha/decisions
 *   type 'boolean' -> probability     type 'noul' -> noul
 *   type 'choice'  + criteria         same
 *   type 'score'   + criteria[]       same
 * So a `boolean` question here is sent as `noul` and the 0-1 answer is read
 * back from `.noul`. Everything else is passed through untouched.
 *
 * HARD RULE FOR THIS PROJECT — JEV CANNOT SEE IMAGES.
 * Control-tested: an image WITH a black bar scored 0.22, an identical image
 * WITHOUT one scored 0.19, and the token count tracked the base64 string
 * length, not the picture. Handing Jev a screenshot and quoting the number back
 * is fake verification, which is the exact failure this project keeps being
 * burned by. Feed it the METRICS from scripts/seam-smudge-gate.py.
 *
 * Usage
 *   node scripts/jev.mjs --from-gate <gate.json>
 *   node scripts/jev.mjs --state "<text>" --bool "name=instructions" \
 *                        --choice "verdict=ship:desc|block:desc"
 * Exit code: 0 ship, 1 block, 2 uncertain, 3 transport/usage error.
 */

const ENDPOINT = process.env.JEV_ENDPOINT || 'https://openrouter.ai/api/alpha/decisions';
const MODEL = process.env.JEV_MODEL || '~typesafe/jev-latest';
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

export async function evaluate({ state, questions }) {
  const key = process.env.OPENROUTER_API_KEY;
  if (!key) throw new Error('Missing OPENROUTER_API_KEY in the environment.');
  if (typeof state !== 'string' && !Array.isArray(state) && typeof state !== 'object') {
    throw new Error('state must be a string, record or array.');
  }
  // Map the portable `boolean` type onto this transport's `noul`.
  const wire = {};
  for (const [name, q] of Object.entries(questions)) {
    wire[name] = q.type === 'boolean' ? { ...q, type: 'noul' } : q;
  }
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), TIMEOUT_MS);
  let res;
  try {
    res = await fetch(ENDPOINT, {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: MODEL, state, questions: wire }),
      signal: ac.signal,
    });
  } finally {
    clearTimeout(timer);
  }
  const text = await res.text();
  if (!res.ok) {
    // A 400 here is a SCHEMA error that names the missing field. It is NOT
    // "model does not exist" — that mistake cost this project a whole session.
    throw new Error(`Jev HTTP ${res.status}: ${text.slice(0, 900)}`);
  }
  const data = JSON.parse(text);
  // Normalise `noul` back to `probability` so callers see the portable shape.
  for (const a of Object.values(data.answers || {})) {
    if (a && a.type === 'noul') { a.type = 'boolean'; a.probability = a.noul; }
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

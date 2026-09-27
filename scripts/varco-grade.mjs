#!/usr/bin/env node
/**
 * varco-grade.mjs — the "listen" step between VARCO takes and promotion
 * (skill: gm-game-varco-ep2). Gemini hears every take of a stem against its
 * catalog prompt and picks the best one; with --promote the pick is copied into
 * src/episode2/assets/audio/<stem_id>.wav via varco-text2sound.mjs.
 *
 *   node scripts/varco-grade.mjs --section runner [--only id,id] [--promote] [--model gemini-3.5-flash]
 *
 * Why a model listens: this repo's sessions cannot hear audio, and promoting by
 * file size or RMS picks the loudest take, not the right one (a clipped gunshot
 * is loud). The grade, reasons and scores are written next to the takes
 * (takes/<id>/grade.json) so a human can overrule any pick later.
 *
 * Key: GEMINI_API_KEY from the environment, never printed.
 */
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { execFileSync } from 'child_process';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..');
const AUDIO = join(REPO, 'artifacts/episode2-gold-mine/audio');
const argv = process.argv.slice(2);
const opt = (n, d) => { const i = argv.indexOf(n); return i >= 0 ? argv[i + 1] : d; };
const MODEL = opt('--model', 'gemini-3.5-flash');
const KEY = process.env.GEMINI_API_KEY || '';
if (!KEY) { console.error('STOP: GEMINI_API_KEY is not set'); process.exit(3); }

let fetchFn = globalThis.fetch;
const proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
if (proxy) {
  const u = await import('undici');
  const agent = new u.ProxyAgent(proxy);
  fetchFn = (url, init = {}) => u.fetch(url, { ...init, dispatcher: agent });
}

const section = opt('--section', '');
if (!section) { console.error('usage: --section <runner|revolver> [--only ids] [--promote]'); process.exit(2); }
const cat = JSON.parse(readFileSync(join(AUDIO, 'prompts', `${section}.json`), 'utf8'));
const only = new Set(opt('--only', '').split(',').filter(Boolean));

for (const s of cat.stems.filter(x => !only.size || only.has(x.id))) {
  const dir = join(AUDIO, 'takes', s.id);
  if (!existsSync(dir)) { console.log(`SKIP ${s.id}: no takes`); continue; }
  const takes = readdirSync(dir).filter(f => /^v\d+_s\d+\.wav$/.test(f));
  const v = Math.max(...takes.map(f => parseInt(f.slice(1), 10)));
  const latest = takes.filter(f => f.startsWith(`v${v}_`)).sort();
  const parts = [{ text:
    `You are the sound supervisor for a 3D mine-cart runner game (dark gold mine, fast carts, bear archers, boulders). ` +
    `Stem "${s.id}" (layer: ${s.layer}, ${s.loop ? 'must LOOP seamlessly as a bed' : 'one-shot'}). Brief: "${s.prompt}". ` +
    `Listen to the ${latest.length} takes in order. Score each 1-10 for: matches the brief, clean (no clipping/artifacts/voice-like garbage), ` +
    `usable in game (${s.loop ? 'even texture, no big one-off event that would repeat obviously' : 'clear transient, not buried in noise'}). ` +
    `Answer ONLY JSON: {"best": <1-based index>, "scores": [..], "notes": ["one short line per take"]}` }];
  latest.forEach((f, i) => {
    parts.push({ text: `Take ${i + 1}:` });
    parts.push({ inline_data: { mime_type: 'audio/wav', data: readFileSync(join(dir, f)).toString('base64') } });
  });
  let j = null, raw = '';
  for (let attempt = 1; attempt <= 4 && !j; attempt++) {
    try {
      const r = await fetchFn(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${KEY}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents: [{ role: 'user', parts }], generationConfig: { responseMimeType: 'application/json', temperature: 0.2 } }),
      });
      raw = await r.text();
      if (r.status === 429) { console.log(`  ${s.id} 429 rate-limited; waiting ${attempt * 40}s`); await new Promise(res => setTimeout(res, attempt * 40000)); continue; }
      if (!r.ok) { console.log(`  ${s.id} HTTP ${r.status}: ${raw.slice(0, 160)}`); continue; }
      const txt = JSON.parse(raw).candidates?.[0]?.content?.parts?.map(p => p.text || '').join('') || '';
      j = JSON.parse(txt.replace(/^```json\s*|```$/g, ''));
    } catch (e) { console.log(`  ${s.id} attempt ${attempt}: ${String(e.message).slice(0, 120)}`); }
  }
  if (!j || !(j.best >= 1 && j.best <= latest.length)) { console.log(`FAIL ${s.id}: no usable grade`); continue; }
  const pick = latest[j.best - 1].replace('.wav', '');
  writeFileSync(join(dir, 'grade.json'), JSON.stringify({ model: MODEL, version: v, pick, ...j }, null, 2) + '\n');
  console.log(`GRADE ${s.id} -> ${pick} scores=${JSON.stringify(j.scores)} | ${(j.notes || [])[j.best - 1] || ''}`.slice(0, 220));
  if (argv.includes('--promote')) {
    execFileSync('node', [join(REPO, 'scripts/varco-text2sound.mjs'), '--promote', `${s.id}=${pick}`], { stdio: 'inherit' });
  }
}

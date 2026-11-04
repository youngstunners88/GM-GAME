// Pins the Crouton lane: free only, private, measured, template-enforced. Run: node --test tests/crouton_lane_test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, existsSync, readFileSync, mkdirSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ask, guardText, expandIncludes, modelOk, privatePath, imagePart, extractJson, status, breakerPath, EFFORT, MIN_MAX_TOKENS } from '../scripts/lib/crouton.mjs';
import { scoreGd, scoreBlotch } from '../scripts/crouton-bench.mjs';

const FAKE_KEY = 'sk' + '-' + 'a1b2c3d4'.repeat(4);   // built at run time so no secret-shaped literal is committed
const FAKE_WALLET = '0x' + 'a'.repeat(40);
const CATALOGUE = (prompt = '0', completion = '0') => ({ ok: true, status: 200, json: async () => ({ data: [{ id: 'stealth/crouton-alpha', pricing: { prompt, completion } }] }) });
const reply = (text, { finish = 'stop', cost = 0, reasoning = 0, status = 200 } = {}) => ({ ok: status === 200, status,
  json: async () => ({ model: 'stealth/crouton-alpha', provider: 'Stealth', choices: [{ message: { content: text }, finish_reason: finish }], usage: { total_tokens: 9, cost, completion_tokens_details: { reasoning_tokens: reasoning } } }) });

function rig(replies, catalogue = CATALOGUE()) {
  const root = mkdtempSync(join(tmpdir(), 'crouton-'));
  const sent = []; const q = [...replies];
  const fetch = async (url, init) => {
    if (url.endsWith('/models')) { if (catalogue instanceof Error) throw catalogue; return catalogue; }
    sent.push(JSON.parse(init.body)); return q.shift();
  };
  return { root, sent, deps: { fetch, root, env: { OPENROUTER_API_KEY: 'k-test-not-real' }, sleep: async () => {}, backoffMs: 0 } };
}

test('only known-free ids are accepted', () => {
  assert.equal(modelOk('stealth/crouton-alpha'), 'stealth/crouton-alpha');
  assert.equal(modelOk('x/y:free'), 'x/y:free');
  assert.throws(() => modelOk('openai/gpt-6-astra'), /not a known free id/);
});

test('the standard template: effort by kind, max_tokens never under 4000', async () => {
  const { sent, deps } = rig([reply('a'), reply('b'), reply('c'), reply('d')]);
  for (const [kind, effort] of [['classify', 'minimal'], ['review', 'low'], ['draft', 'low'], ['digest', 'medium']]) {
    await ask({ prompt: 'p', kind, maxTokens: 100 }, deps);
    assert.deepEqual(sent.at(-1).reasoning, { effort }); assert.equal(sent.at(-1).max_tokens, 4000); assert.equal(EFFORT[kind], effort);
  }
  await assert.rejects(ask({ prompt: 'p', kind: 'chat' }, deps), /kind/);
  assert.equal(MIN_MAX_TOKENS, 4000);
});

test('an empty answer cut off by length is retried once with double the budget, and logged', async () => {
  const { root, sent, deps } = rig([reply('', { finish: 'length', reasoning: 4000 }), reply('the answer')]);
  const r = await ask({ prompt: 'p', task: 'grow' }, deps);
  assert.equal(r.text, 'the answer'); assert.deepEqual(sent.map((s) => s.max_tokens), [4000, 8000]); assert.equal(r.meta.grown, true);
  assert.equal(status(root).by_task.grow.grown, 1);
});

test('json mode, bad json retried, 429 retried', async () => {
  const { deps } = rig([reply('', { status: 429 }), reply('not json'), reply('{"ok":true}')]);
  const r = await ask({ prompt: 'p', json: true }, deps);
  assert.deepEqual(r.json, { ok: true });
  assert.deepEqual(extractJson('```json\n{"a":1}\n```'), { a: 1 });
});

test('one billed call trips the breaker and stops every later call', async () => {
  const { root, deps } = rig([reply('x', { cost: 0.002 })]);
  await assert.rejects(ask({ prompt: 'p' }, deps), /billed/);
  assert.ok(existsSync(breakerPath(root)));
  await assert.rejects(ask({ prompt: 'p' }, deps), /tripped/);
  assert.ok(status(root).tripped);
});

test('a non-zero catalogue price or an unreachable catalogue refuses before any call', async () => {
  let r = rig([reply('x')], CATALOGUE('0.0000001', '0'));
  await assert.rejects(ask({ prompt: 'p' }, r.deps), /no longer free/); assert.equal(r.sent.length, 0);
  r = rig([reply('x')], new Error('down'));
  await assert.rejects(ask({ prompt: 'p' }, r.deps), /catalogue/); assert.equal(r.sent.length, 0);
});

test('secrets, live key values and wallet addresses never leave', async () => {
  assert.throws(() => guardText('my key ' + FAKE_KEY), /secret/);
  assert.throws(() => guardText('send to ' + FAKE_WALLET), /wallet/);
  assert.throws(() => guardText('value-that-is-long-enough-1234', { SOME_API_KEY: 'value-that-is-long-enough-1234' }), /SOME_API_KEY/);
  const { sent, deps } = rig([reply('x')]);
  await assert.rejects(ask({ prompt: 'token ' + FAKE_KEY }, deps), /secret/); assert.equal(sent.length, 0);
});

test('private and missing @include paths abort before anything is sent', () => {
  const root = mkdtempSync(join(tmpdir(), 'crouton-inc-'));
  writeFileSync(join(root, 'ok.gd'), 'extends Node\n'); writeFileSync(join(root, 'config.json'), '{}'); mkdirSync(join(root, 'lil-blunt-icp'));
  writeFileSync(join(root, 'lil-blunt-icp/main.mo'), 'x');
  assert.match(expandIncludes('@include ok.gd', root).text, /--- FILE: ok.gd/);
  assert.throws(() => expandIncludes('@include config.json', root), /private/);
  assert.throws(() => expandIncludes('@include lil-blunt-icp/main.mo', root), /private/);
  assert.throws(() => expandIncludes('@include .env', root), /private/);
  assert.throws(() => expandIncludes('@include nope.gd', root), /do not exist/);
  assert.ok(privatePath('GM Game/Work Log/x.md') && privatePath('a/b/deploy.key') && !privatePath('src/ui/hud.gd'));
  assert.throws(() => imagePart('config.json', root), /image/);
});

test('the lane is a side channel: no other script and no CI step uses it, and it is documented as not critical-path', () => {
  const lane = readFileSync(new URL('../scripts/lib/crouton.mjs', import.meta.url), 'utf-8');
  assert.match(lane, /PRIVACY/); assert.match(lane, /never for the critical path/);
  const importers = readdirSync(new URL('../scripts/', import.meta.url)).filter((f) => /\.(mjs|sh|py)$/.test(f) && !/^crouton/.test(f))
    .filter((f) => /crouton/i.test(readFileSync(new URL(`../scripts/${f}`, import.meta.url), 'utf-8')));
  assert.deepEqual(importers, [], `only crouton-call.mjs and crouton-bench.mjs may use the lane: ${importers}`);
  const ci = readFileSync(new URL('../.github/workflows/export-game.yml', import.meta.url), 'utf-8');
  assert.ok(!/crouton/i.test(ci), 'CI must not depend on a stealth preview model');
});

test('gd scoring: caught within +-2 lines, clean controls wrongly flagged, invented lines, and no opinion when small', () => {
  const mk = (i, bug, findings) => ({ file: `f${i}.gd`, bug_line: bug, nlines: 10, findings });
  const rows = [];
  for (let i = 0; i < 12; i++) { rows.push(mk(i, 5, [{ line: 6, severity: 'high' }])); rows.push(mk(i + 100, null, [])); }
  let s = scoreGd(rows);
  assert.equal(s.caught, 12); assert.equal(s.false_alarms, 0); assert.match(s.verdict, /^eligible/);
  rows[0] = mk(0, 5, [{ line: 9, severity: 'high' }, { line: 99, severity: 'low' }]);           // wrong line -> missed; line 99 does not exist
  rows[1] = mk(100, null, [{ line: 3, severity: 'med' }]);                                       // clean control flagged
  s = scoreGd(rows);
  assert.equal(s.missed, 1); assert.equal(s.false_alarms, 1); assert.equal(s.invalid_line_findings, 1);
  assert.match(scoreGd(rows.slice(0, 6)).verdict, /no opinion/);
  assert.match(scoreGd(rows.map((r) => ({ ...r, findings: null }))).verdict, /no opinion/);        // a failed call is not a look
  assert.match(scoreGd(rows.map((r) => ({ ...r, findings: [{ line: 1, severity: 'high' }, { line: r.bug_line || 1, severity: 'high' }] }))).verdict, /not eligible/);
});

test('blotch scoring reproduces the founder oracle or has no opinion; the negative control must be called clean', () => {
  const oracle = JSON.parse(readFileSync(new URL('../scripts/blotch-oracle.json', import.meta.url), 'utf-8')).scenes;
  const perfect = Object.keys(oracle).map((scene) => ({ scene, votes: oracle[scene].blotched ? [true, true, true] : [false, false, false] }));
  let s = scoreBlotch(perfect, oracle);
  assert.equal(s.agree, 6); assert.match(s.verdict, /^calibrated/); assert.equal(s.control_scene_clean, true);
  const sawEverythingDirty = perfect.map((r) => ({ ...r, votes: [true, true, true] }));
  s = scoreBlotch(sawEverythingDirty, oracle);
  assert.equal(s.agree, 5); assert.equal(s.control_scene_clean, false); assert.match(s.verdict, /^uncalibrated/);
  assert.match(scoreBlotch(perfect.map((r) => ({ ...r, votes: [null, null, null] })), oracle).verdict, /^uncalibrated/);
});

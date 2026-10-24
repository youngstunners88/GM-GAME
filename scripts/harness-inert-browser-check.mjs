#!/usr/bin/env node
// harness-inert-browser-check.mjs - prove, in a REAL browser, that a web build is INERT to the test-harness URL hooks.
//
// The two hooks (src/debug/harness_hooks.gd) exist only in a build tagged gm_harness (GM_HARNESS=1 scripts/ep2-local-export.sh):
//   ?ep2gate=skip  would open Episode 2 without the access code      ?bosskill=N  would kill the stage-3 boss from the URL
// The shipped build (the CI artifact in web/game, and the itch page) must ignore both. This script loads a build with both
// parameters and FAILS if either one did anything:
//   1  ?ep2=1&ep2gate=skip  -> the access-code prompt still appears, and no runner leg ever starts
//   2  ?boss=3&bosskill=2   -> no "[HARNESS]" console line, the stage never leaves PLAYING for LEVEL_COMPLETE
//   3  window.__gm.harness  -> false (the overlay reports OS.has_feature("gm_harness"))
// Run it on the CI artifact before deploy (advisory step) or on any local export:
//   node scripts/serve-web.mjs 8897 web &            # or web_verify
//   node scripts/harness-inert-browser-check.mjs http://localhost:8897/game/index.html
// Against a GM_HARNESS=1 build it FAILS on purpose (pass --expect-live to invert: then it checks the hooks DO work).
// Exit 0 = inert (or live, with --expect-live). No secrets, no network beyond the URL you pass.

import { launch, newProfilePage, collectConsole } from './lib/pw.mjs';

const url = process.argv.find((a, i) => i >= 2 && /^https?:/.test(a)) || 'http://localhost:8899/game/index.html';
const expectLive = process.argv.includes('--expect-live');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let bad = 0;
const check = (name, ok, detail = '') => {
  console.log(`  [${ok ? 'PASS' : 'FAIL'}] ${name}${ok ? '' : `  ${detail}`}`);
  if (!ok) bad++;
};

const browser = await launch();
async function load(query, { waitFor, waitMs, settleMs }) {
  const { context, page } = await newProfilePage(browser, 'phone', { dpr: 1, size: [640, 300] });
  const con = collectConsole(page, { prefixes: ['[EP2]', '[HARNESS]', '[DBG]', '[SceneRouter]'] });
  await page.goto(url + query, { waitUntil: 'domcontentloaded', timeout: 120000 });
  await page.waitForSelector('canvas', { timeout: 60000 });
  const t0 = Date.now();
  while (Date.now() - t0 < waitMs) {
    const hit = await page.evaluate((src) => window.__logT.some((e) => new RegExp(src).test(e[1])), waitFor.source);
    if (hit) break;
    await sleep(300);
  }
  await sleep(settleMs);
  const data = await page.evaluate(() => ({ logs: window.__logT.map((e) => e[1]), states: window.__logT.filter((e) => /^\[DBG\] state/.test(e[1])).map((e) => e[1]), gm: window.__gm }));
  await context.close();
  return { ...data, errors: con.errors };
}

console.log(`harness-inert-browser-check ${url}  (${expectLive ? 'expecting a LIVE gm_harness build' : 'expecting an INERT shipped build'})`);

// 1. the access-code gate
const a = await load('?ep2=1&ep2gate=skip&ep2probe=1&debug=beacon', { waitFor: /^\[EP2\] (code prompt|leg start)/, waitMs: 240000, settleMs: 12000 });
const prompt = a.logs.some((l) => /^\[EP2\] code prompt/.test(l));
const leg = a.logs.some((l) => /^\[EP2\] leg start/.test(l));
if (expectLive) {
  check('ep2gate=skip opened Episode 2 (a runner leg started, no code prompt)', leg && !prompt, `prompt=${prompt} leg=${leg}`);
} else {
  check('ep2gate=skip is IGNORED: the access-code prompt appears', prompt, 'no "[EP2] code prompt" line: the gate did not show');
  check('ep2gate=skip is IGNORED: no runner leg starts', !leg, 'a runner leg started without the code');
}
check('no [HARNESS] line printed' + (expectLive ? ' (live: expected at least one)' : ''), expectLive ? a.logs.some((l) => /^\[HARNESS\]/.test(l)) : !a.logs.some((l) => /^\[HARNESS\]/.test(l)));
check(`beacon.harness is ${expectLive}`, !!a.gm && a.gm.harness === expectLive, `beacon=${JSON.stringify(a.gm && a.gm.harness)}`);

// 2. the boss kill
const b = await load('?boss=3&bosskill=2&debug=beacon', { waitFor: /^\[HARNESS\] bosskill: stage-3/, waitMs: 90000, settleMs: expectLive ? 4000 : 14000 });
const armed = b.logs.some((l) => /^\[HARNESS\] bosskill armed/.test(l));
const killed = b.logs.some((l) => /^\[HARNESS\] bosskill: stage-3/.test(l));
if (expectLive) {
  check('bosskill=2 armed and killed the boss', armed && killed, `armed=${armed} killed=${killed}`);
} else {
  check('bosskill=2 is IGNORED: nothing armed, nothing killed, no [HARNESS] line', !armed && !killed && !b.logs.some((l) => /^\[HARNESS\]/.test(l)));
  check('bosskill=2 is IGNORED: the stage never reached LEVEL_COMPLETE', !b.states.some((l) => /->LEVEL_COMPLETE/.test(l)), b.states.join(' | '));
}
await browser.close();
console.log(bad ? `HARNESS_INERT_BROWSER: ${bad} FAILURE(S)` : 'HARNESS_INERT_BROWSER: ALL PASS');
process.exit(bad ? 1 : 0);

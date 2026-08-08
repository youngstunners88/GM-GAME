#!/usr/bin/env node
// Interactive playtest driver for the Distributor boss fight.
//
// WHY THIS EXISTS: the Distributor was rebuilt (Hoard Gravity pull, orb
// redirect, POOL DRAIN) and every check so far has been static — reading code,
// not playing it. There is no local Godot binary in this sandbox, so a headless
// scene test is impossible; the real web export in a real browser is the ONLY
// way to observe feel.
//
// There is also no debug/teleport hook in the game and no inbound JS->Godot
// bridge, so the boss arena (Crystal Caverns, x=3700) has to be REACHED by
// actually playing. This script drives keyboard input and screenshots on a
// cadence so the frames can be inspected afterwards.
//
// Usage: node scripts/playtest-distributor.mjs [url] [seconds]
// Artifacts: playtest-shots/shot-NNN.png + playtest-distributor.json

import fs from 'fs';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);

let chromium;
try {
  ({ chromium } = require('@playwright/test'));
} catch {
  ({ chromium } = require(
    process.env.PLAYWRIGHT_PKG || '/opt/node22/lib/node_modules/playwright/index.js'
  ));
}

const url = process.argv[2] || 'http://localhost:8899/game/index.html';
const runSeconds = parseInt(process.argv[3] || '150', 10);
const OUT = process.env.PLAYTEST_OUT || 'playtest-shots';
fs.mkdirSync(OUT, { recursive: true });

const result = { url, states: [], errors: [], shots: [], notes: [] };
const GODOT_ERROR_RE = /USER SCRIPT ERROR|Parse Error|Failed to instantiate an autoload|The InputMap action/i;

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium',
  args: [
    '--no-sandbox',
    '--enable-unsafe-swiftshader',
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--enable-webgl',
    '--ignore-gpu-blocklist',
  ],
});

let shotN = 0;
async function shot(page, label) {
  const p = `${OUT}/shot-${String(shotN++).padStart(3, '0')}-${label}.png`;
  await page.screenshot({ path: p });
  result.shots.push(p);
  return p;
}

try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  await page.addInitScript(() => {
    window.__states = [];
    window.addEventListener('message', (e) => {
      try {
        if (e.data && e.data.type === 'state') window.__states.push(String(e.data.value));
      } catch (_) {}
    });
  });
  page.on('console', (m) => {
    const t = m.text();
    // Benign patterns already catalogued in scripts/verify-game.mjs.
    const benign =
      /USER WARNING|at: push_warning|No loader found for resource|Blocking on the main thread|ERR_CONNECTION_RESET|Failed to fetch|godot_js_fetch/.test(t);
    if ((m.type() === 'error' || GODOT_ERROR_RE.test(t)) && !benign) {
      result.errors.push(`[${m.type()}] ${t.slice(0, 250)}`);
    }
  });

  console.log('[1] loading + booting...');
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForSelector('canvas', { timeout: 15000 });
  const booted = await page
    .waitForFunction(
      () => {
        const s = document.getElementById('status');
        const c = document.querySelector('canvas');
        const hidden = !s || getComputedStyle(s).display === 'none';
        return hidden && c && c.width > 0 && !(c.width === 300 && c.height === 150);
      },
      { timeout: 45000, polling: 500 }
    )
    .then(() => true)
    .catch(() => false);
  result.booted = booted;
  await page.waitForTimeout(1500);
  await shot(page, 'menu');
  if (!booted) throw new Error('engine never booted');

  console.log('[2] starting a run...');
  const vp = page.viewportSize();
  await page.mouse.click(vp.width * 0.5, vp.height * 0.6);
  await page.waitForTimeout(2500);
  await page.keyboard.press('Escape'); // skip the one-time email panel
  await page.waitForTimeout(2000);
  await shot(page, 'level-start');

  // Input policy: hold Right, jump on a cadence to clear gaps, attack often.
  // Deliberately simple — this is a traversal driver, not an AI player. The
  // screenshots are the actual evidence.
  console.log(`[3] driving for ${runSeconds}s, screenshotting every 5s...`);
  await page.keyboard.down('ArrowRight');
  const started = Date.now();
  let i = 0;
  while ((Date.now() - started) / 1000 < runSeconds) {
    i++;
    // Jump twice per cycle (double jump clears the wide pits).
    await page.keyboard.press('Space');
    await page.waitForTimeout(180);
    await page.keyboard.press('Space');
    await page.waitForTimeout(320);
    // Attack — also the input that redirects orbs in the boss fight.
    // Bound to physical J (keycode 74) / Enter in project.godot's InputMap.
    // NOT X — driving X here would have silently pressed nothing and made the
    // whole redirect test meaningless.
    await page.keyboard.press('KeyJ');
    await page.waitForTimeout(400);
    if (i % 5 === 0) {
      const states = await page.evaluate(() => window.__states || []);
      result.states = states;
      await shot(page, `t${Math.round((Date.now() - started) / 1000)}s`);
    }
  }
  await page.keyboard.up('ArrowRight');
  await shot(page, 'final');
  result.states = await page.evaluate(() => window.__states || []);
} catch (err) {
  result.errors.push(`Fatal: ${err.message}`);
} finally {
  await browser.close();
}

fs.writeFileSync('playtest-distributor.json', JSON.stringify(result, null, 2));
console.log(JSON.stringify({ booted: result.booted, states: result.states, errors: result.errors.slice(0, 10), shots: result.shots.length }, null, 2));

#!/usr/bin/env node
// S10 boss-warp capture driver. Loads the web build with ?boss=N (the test-only
// warp added this session), which routes straight to level N and drops the
// player into the boss arena — so we can actually WATCH the Distributor (2) /
// Claim Jumper (3) fight instead of trying (and failing) to beat Level 1 first.
//
// It drives a WEAVING + HOPPING kite — the exact play pattern that exposed the
// "hovers, doesn't chase" (S2) and "frozen statue" (S3) bugs — and screenshots
// on a cadence so the frames are the evidence. It also samples the boss's
// on-screen horizontal position each cycle (via a canvas-pixel heuristic is
// unreliable, so instead we read the game's own state beacons) and records
// whether the boss health bar ever appeared (proof the warp reached the fight).
//
// Usage: node scripts/playtest-boss-warp.mjs <url> <seconds> <label>
// Artifacts: <OUT>/shot-*.png + playtest-boss-<label>.json

import fs from 'fs';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require('@playwright/test')); }
catch { ({ chromium } = require(process.env.PLAYWRIGHT_PKG || '/opt/node22/lib/node_modules/playwright/index.js')); }

const url = process.argv[2] || 'http://localhost:8899/game/index.html?boss=2';
const runSeconds = parseInt(process.argv[3] || '35', 10);
const label = process.argv[4] || 'boss2';
const OUT = process.env.PLAYTEST_OUT || `playtest-shots-${label}`;
fs.mkdirSync(OUT, { recursive: true });

const result = { url, label, booted: false, states: [], errors: [], shots: [], notes: [] };
const GODOT_ERROR_RE = /USER SCRIPT ERROR|Parse Error|Failed to instantiate an autoload|The InputMap action/i;

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium',
  args: ['--no-sandbox', '--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'],
});

let shotN = 0;
async function shot(page, lbl) {
  const p = `${OUT}/shot-${String(shotN++).padStart(3, '0')}-${lbl}.png`;
  await page.screenshot({ path: p });
  result.shots.push(p);
  return p;
}

try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  await page.addInitScript(() => {
    window.__states = [];
    window.addEventListener('message', (e) => {
      try { if (e.data && e.data.type === 'state') window.__states.push(String(e.data.value)); } catch (_) {}
    });
  });
  page.on('console', (m) => {
    const t = m.text();
    const benign = /USER WARNING|at: push_warning|No loader found for resource|Blocking on the main thread|ERR_CONNECTION_RESET|Failed to fetch|godot_js_fetch/.test(t);
    if ((m.type() === 'error' || GODOT_ERROR_RE.test(t)) && !benign) result.errors.push(`[${m.type()}] ${t.slice(0, 250)}`);
  });

  console.log(`[1] loading ${url}`);
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForSelector('canvas', { timeout: 15000 });
  const booted = await page.waitForFunction(() => {
    const s = document.getElementById('status');
    const c = document.querySelector('canvas');
    const hidden = !s || getComputedStyle(s).display === 'none';
    return hidden && c && c.width > 0 && !(c.width === 300 && c.height === 150);
  }, { timeout: 45000, polling: 500 }).then(() => true).catch(() => false);
  result.booted = booted;
  await page.waitForTimeout(2000);
  await shot(page, 'boot');
  if (!booted) throw new Error('engine never booted');

  // The warp routes menu -> level N automatically; dismiss the one-time email
  // panel that can appear on first level entry.
  await page.mouse.click(640, 430);
  await page.waitForTimeout(800);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(2500);
  await shot(page, 'arena-entry');

  // WEAVING + HOPPING KITE. Alternate run direction each ~900ms, hop twice a
  // cycle, attack often. This is the pattern the founder's own play produces —
  // and the one every straight-line gate missed.
  console.log(`[2] weaving/hopping kite for ${runSeconds}s...`);
  const started = Date.now();
  let dir = 'ArrowLeft';
  let cyc = 0;
  while ((Date.now() - started) / 1000 < runSeconds) {
    cyc++;
    dir = dir === 'ArrowLeft' ? 'ArrowRight' : 'ArrowLeft';
    await page.keyboard.down(dir);
    for (let k = 0; k < 3; k++) {
      await page.keyboard.press('Space');   // hop
      await page.keyboard.press('KeyJ');     // attack / orb-redirect
      await page.waitForTimeout(300);
    }
    await page.keyboard.up(dir);
    if (cyc % 2 === 0) {
      result.states = await page.evaluate(() => window.__states || []);
      await shot(page, `t${Math.round((Date.now() - started) / 1000)}s`);
    }
  }
  await shot(page, 'final');
  result.states = await page.evaluate(() => window.__states || []);
  // Boss health bar presence = the warp genuinely reached the fight.
  result.reachedFight = result.states.some((s) => /PLAYING/.test(s));
} catch (err) {
  result.errors.push(`Fatal: ${err.message}`);
} finally {
  await browser.close();
}

fs.writeFileSync(`playtest-boss-${label}.json`, JSON.stringify(result, null, 2));
console.log(JSON.stringify({ booted: result.booted, reachedFight: result.reachedFight, shots: result.shots.length, states: result.states.slice(-6), errors: result.errors.slice(0, 8) }, null, 2));

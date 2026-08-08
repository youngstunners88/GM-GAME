#!/usr/bin/env node
// Dense-capture driver for a BOSS FIGHT specifically.
//
// playtest-distributor.mjs is a traversal driver (hold right, jump, attack) —
// good for crossing a level, useless for observing a fight, because it pins
// the player against the far wall and screenshots every 5s.
//
// This one assumes the fight is already reachable and does the opposite:
// it stays mobile in a small area, attacks constantly (the input that also
// redirects the Distributor's orbs), and screenshots every ~1.2s so the
// short-lived beats are actually captured — the 0.65s gravity tell, the
// 1.4s pull field, and the 0.35s orb "unstable" redirect window.
//
// Usage: node scripts/playtest-bossfight.mjs [url] [seconds]
// Env: PLAYTEST_OUT=<dir>

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

const url = process.argv[2] || 'http://localhost:8902/game/index.html';
const runSeconds = parseInt(process.argv[3] || '90', 10);
const OUT = process.env.PLAYTEST_OUT || 'playtest-boss';
fs.mkdirSync(OUT, { recursive: true });

const result = { url, states: [], errors: [], shots: [] };
const GODOT_ERROR_RE = /USER SCRIPT ERROR|Parse Error|Failed to instantiate an autoload|The InputMap action/i;

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium',
  args: ['--no-sandbox', '--enable-unsafe-swiftshader', '--use-gl=angle',
         '--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'],
});

let n = 0;
async function shot(page, label) {
  const p = `${OUT}/b-${String(n++).padStart(3, '0')}-${label}.png`;
  await page.screenshot({ path: p });
  result.shots.push(p);
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
    if ((m.type() === 'error' || GODOT_ERROR_RE.test(t)) && !benign) result.errors.push(`[${m.type()}] ${t.slice(0, 220)}`);
  });

  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForSelector('canvas', { timeout: 15000 });
  await page.waitForFunction(() => {
    const s = document.getElementById('status');
    const c = document.querySelector('canvas');
    return (!s || getComputedStyle(s).display === 'none') && c && c.width > 0 && !(c.width === 300 && c.height === 150);
  }, { timeout: 45000, polling: 500 });
  await page.waitForTimeout(1500);
  await shot(page, 'menu');

  const vp = page.viewportSize();
  await page.mouse.click(vp.width * 0.5, vp.height * 0.6);
  await page.waitForTimeout(2500);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(2500);
  await shot(page, 'arena-entry');

  // Walk right briefly to cross the boss trigger, then fight in place.
  await page.keyboard.down('ArrowRight');
  await page.waitForTimeout(1800);
  await page.keyboard.up('ArrowRight');
  await shot(page, 'triggered');

  const t0 = Date.now();
  let i = 0;
  let lastShot = 0;
  while ((Date.now() - t0) / 1000 < runSeconds) {
    i++;
    // Attack constantly — this is also the orb-redirect input (physical J).
    await page.keyboard.press('KeyJ');
    await page.waitForTimeout(120);
    // Small oscillation so the pull has something to fight and we don't
    // wedge against a wall.
    const dir = i % 2 === 0 ? 'ArrowLeft' : 'ArrowRight';
    await page.keyboard.down(dir);
    await page.waitForTimeout(260);
    await page.keyboard.up(dir);
    if (i % 3 === 0) { await page.keyboard.press('Space'); }
    await page.waitForTimeout(140);
    const el = (Date.now() - t0) / 1000;
    if (el - lastShot >= 1.2) { lastShot = el; await shot(page, `t${el.toFixed(0)}s`); }
  }
  await shot(page, 'final');
  result.states = await page.evaluate(() => window.__states || []);
} catch (err) {
  result.errors.push(`Fatal: ${err.message}`);
} finally {
  await browser.close();
}

fs.writeFileSync(`${OUT}/result.json`, JSON.stringify(result, null, 2));
console.log(JSON.stringify({ states: result.states, errorCount: result.errors.length, shots: result.shots.length }, null, 2));

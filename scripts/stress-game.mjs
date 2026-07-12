#!/usr/bin/env node
// Stress/monkey test for the Godot web export. Boots the game, enters Level 1,
// then hammers it: random input mashing, pause spam, and a travel soak while
// sampling JS heap for leaks. Fails on any non-benign console error, page
// error, or engine death (canvas gone / heap runaway).
//
// Usage: node scripts/stress-game.mjs [game-url] [seconds-per-phase]
// Artifacts: stress-report.json, stress-final.png

import fs from 'fs';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require('@playwright/test'));
} catch {
  ({ chromium } = require(process.env.PLAYWRIGHT_PKG || '/opt/node22/lib/node_modules/playwright/index.js'));
}

const gameUrl = process.argv[2] || 'http://localhost:8899/game/index.html';
const PHASE_SECS = Number(process.argv[3] || 45);

const BENIGN_RE =
  /USER WARNING|at: push_warning|No loader found for resource: res:\/\/src\/assets\/(sounds|music)\/|at: _load \(core\/io\/resource_loader|Blocking on the main thread/;
const FATAL_RE =
  /USER SCRIPT ERROR|Parse Error|Failed to instantiate an autoload|The InputMap action|SharedArrayBuffer|abort\(|RuntimeError|memory access out of bounds/i;

// Keys the game actually maps (project.godot [input]) + ESC for pause menu.
const KEYS = ['ArrowLeft', 'ArrowRight', 'KeyA', 'KeyD', 'KeyW', 'Space', 'ShiftLeft', 'KeyK', 'KeyE'];

const report = {
  url: gameUrl,
  phaseSeconds: PHASE_SECS,
  phases: {},
  errors: [],
  heapSamplesMB: [],
  passed: false,
};

const rnd = (arr) => arr[Math.floor(Math.random() * arr.length)];

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium',
  args: [
    '--no-sandbox',
    '--enable-unsafe-swiftshader',
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--enable-webgl',
    '--ignore-gpu-blocklist',
    '--js-flags=--expose-gc',
  ],
});

try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', (m) => {
    const t = m.text();
    if ((m.type() === 'error' || FATAL_RE.test(t)) && !BENIGN_RE.test(t))
      report.errors.push(`[console] ${t.slice(0, 250)}`);
  });
  page.on('pageerror', (e) => report.errors.push(`[pageerror] ${String(e).slice(0, 250)}`));

  const sampleHeap = async () => {
    const mb = await page.evaluate(() =>
      performance.memory ? Math.round(performance.memory.usedJSHeapSize / 1048576) : -1
    );
    report.heapSamplesMB.push(mb);
    return mb;
  };

  const engineAlive = async () =>
    page.evaluate(() => {
      const c = document.querySelector('canvas');
      return !!c && c.width > 0 && !(c.width === 300 && c.height === 150);
    });

  // ---- Boot into Level 1 ----
  console.log('[boot] loading game...');
  await page.goto(gameUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForFunction(
    () => {
      const s = document.getElementById('status');
      return (!s || getComputedStyle(s).display === 'none') && document.querySelector('canvas');
    },
    { timeout: 45000, polling: 500 }
  );
  await page.waitForTimeout(2000);
  await page.mouse.click(1280 * 0.5, 720 * 0.553); // PLAY LEVEL 1
  await page.waitForTimeout(5000);
  await sampleHeap();
  console.log('[boot] in level, starting stress phases');

  // ---- Phase 1: monkey input mashing ----
  console.log(`[phase 1] monkey mash (${PHASE_SECS}s)...`);
  const mashEnd = Date.now() + PHASE_SECS * 1000;
  const held = new Set();
  while (Date.now() < mashEnd) {
    const key = rnd(KEYS);
    if (held.has(key)) {
      await page.keyboard.up(key);
      held.delete(key);
    } else {
      await page.keyboard.down(key);
      held.add(key);
    }
    await page.waitForTimeout(30 + Math.random() * 120);
  }
  for (const k of held) await page.keyboard.up(k);
  report.phases.monkey_mash = (await engineAlive()) ? 'PASS' : 'FAIL: engine died';
  await sampleHeap();

  // ---- Phase 2: pause/resume + rapid-toggle spam ----
  console.log('[phase 2] pause spam (40 ESC toggles)...');
  for (let i = 0; i < 40; i++) {
    await page.keyboard.press('Escape');
    await page.waitForTimeout(60 + Math.random() * 100);
  }
  // make sure we end unpaused: click roughly where Resume sits, then ESC once more if needed
  await page.keyboard.press('Escape');
  await page.waitForTimeout(500);
  report.phases.pause_spam = (await engineAlive()) ? 'PASS' : 'FAIL: engine died';
  await sampleHeap();

  // ---- Phase 3: travel soak (run right, jump periodically) ----
  console.log(`[phase 3] travel soak (${PHASE_SECS}s)...`);
  await page.keyboard.down('ArrowRight');
  const soakEnd = Date.now() + PHASE_SECS * 1000;
  while (Date.now() < soakEnd) {
    await page.keyboard.press('Space');
    await page.waitForTimeout(400 + Math.random() * 600);
    if (Math.random() < 0.15) await page.keyboard.press('KeyK'); // dash
  }
  await page.keyboard.up('ArrowRight');
  report.phases.travel_soak = (await engineAlive()) ? 'PASS' : 'FAIL: engine died';
  const heapEnd = await sampleHeap();

  // ---- Heap-leak heuristic: >2.5x growth from first in-level sample is a leak flag
  const heapStart = report.heapSamplesMB[0];
  report.phases.heap_stable =
    heapStart > 0 && heapEnd > heapStart * 2.5
      ? `FAIL: heap grew ${heapStart}MB → ${heapEnd}MB`
      : 'PASS';

  await page.screenshot({ path: 'stress-final.png' });
  report.passed =
    Object.values(report.phases).every((v) => v === 'PASS') && report.errors.length === 0;
} catch (err) {
  report.errors.push(`Fatal: ${err.message}`);
} finally {
  await browser.close();
}

fs.writeFileSync('stress-report.json', JSON.stringify(report, null, 2));
console.log('\n=== STRESS REPORT ===');
console.log(JSON.stringify(report, null, 2));
console.log(report.passed ? '\n✅ STRESS PASSED' : '\n❌ STRESS FAILED');
process.exit(report.passed ? 0 : 1);

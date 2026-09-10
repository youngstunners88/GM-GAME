#!/usr/bin/env node
// capture-ep2.mjs — real-browser screenshot capture for Episode 2 (Gold Mine).
//
// WHY A DEDICATED CAPTURE SCRIPT
// Episode 2's two worst defects — hazards that were pure data with no mesh, and
// materials so blown out the scene read as white — were both invisible to every
// headless gate and were only ever found by looking at pixels in a real browser.
// The art-direction-fidelity-check skill needs those pixels as a FILE it can
// hand to a vision model, so capturing them has to be one repeatable command,
// not a hand-driven session.
//
// It warps straight in via ?ep2=1 (the test-only query param main_menu.gd
// reads) so a capture never depends on beating three bosses first.
//
// Usage:
//   node scripts/capture-ep2.mjs <base-url> <out-dir> [--chamber]
// e.g.
//   node scripts/capture-ep2.mjs http://localhost:8899/game/index.html artifacts/ep2-shots
//
// Exit 0 = booted with no script errors and every shot written.
import fs from 'fs';
import path from 'path';
import { chromium } from 'playwright';

const URL_BASE = process.argv[2];
const OUT_DIR = process.argv[3] || 'artifacts/ep2-shots';
if (!URL_BASE) {
  console.error('Usage: capture-ep2.mjs <base-url> <out-dir>');
  process.exit(1);
}
fs.mkdirSync(OUT_DIR, { recursive: true });

const url = URL_BASE + (URL_BASE.includes('?') ? '&' : '?') + 'ep2=1';
const errors = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// This sandbox ships a pinned Chromium at PLAYWRIGHT_BROWSERS_PATH that will
// NOT match the browser build a freshly-installed playwright package expects
// (1194 on disk vs 1243 wanted, at time of writing). Downloading the matching
// build is explicitly not the fix here — point at the one that exists.
const PINNED = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const launchOpts = {
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
         '--disable-dev-shm-usage', '--no-sandbox'],
};
if (fs.existsSync(PINNED)) launchOpts.executablePath = PINNED;
const browser = await chromium.launch(launchOpts);
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

page.on('console', (m) => {
  const t = m.text();
  // Godot funnels GDScript failures through console text, not JS exceptions, so
  // a page with zero uncaught errors can still be a scene that never ran.
  // Deliberately NOT matching a bare "Failed to load resource": the local dev
  // server resets a connection on favicon/web3.js often enough that it flagged
  // two errors on a run whose GDScript was completely clean. A gate that cries
  // wolf about the harness gets ignored on the run that matters.
  if (/USER SCRIPT ERROR|Parse Error|SCRIPT ERROR|Cannot call method|SharedArrayBuffer|\.pck.*Failed|\.wasm.*Failed/i.test(t)) {
    errors.push(t);
  }
});
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));

console.log('opening', url);
await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
await page.waitForSelector('canvas', { timeout: 120000 });

// Wait for a real boot, not the splash: the canvas leaves its default size.
await page.waitForFunction(() => {
  const c = document.querySelector('canvas');
  return c && c.width > 100 && c.height > 100;
}, { timeout: 180000 });
await sleep(9000);   // engine warm-up + autoloads + scene route

const shots = [];
async function shot(name) {
  const p = path.join(OUT_DIR, name);
  await page.screenshot({ path: p });
  const bytes = fs.statSync(p).size;
  shots.push({ name, bytes });
  console.log(`  shot ${name} (${bytes} B)`);
}

await page.click('canvas', { position: { x: 640, y: 400 } }).catch(() => {});
await sleep(2500);
await shot('ep2_runner_start.png');

// Let the cart cover ground so hazards, lanterns and the zip cable are in frame.
await sleep(4000);
await shot('ep2_runner_mid.png');
await sleep(4000);
await shot('ep2_runner_late.png');

await browser.close();

fs.writeFileSync(path.join(OUT_DIR, 'capture.json'),
  JSON.stringify({ url, shots, errors, captured: new Date().toISOString() }, null, 2));

if (errors.length) {
  console.error(`\nFAIL — ${errors.length} script error(s):`);
  for (const e of errors.slice(0, 12)) console.error('  ' + e);
  process.exit(1);
}
console.log(`\nOK — ${shots.length} shots in ${OUT_DIR}, 0 script errors`);

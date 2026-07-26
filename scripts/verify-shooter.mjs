#!/usr/bin/env node
// Browser feel-check for the v1.2 "Blunt Force" shooter prototype room.
//
// verify-game.mjs proves the v1.0 campaign still boots. This one proves the
// PROTOTYPE is reachable and interactive in an actual browser: it clicks the
// menu's "BLUNT FORCE (v1.2 PROTOTYPE)" entry, then drives real input —
// strafe, mouse-aim, fire, duck behind cover — and screenshots each beat so
// the feel can be reviewed from stills.
//
// Gates: canvas attaches · engine boots · zero Godot script errors ·
//        prototype room reaches PLAYING · fires without erroring.
//
// Usage: node scripts/verify-shooter.mjs <game-url> [out-prefix]

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

const gameUrl = process.argv[2] || 'http://127.0.0.1:8099/index.html';
const prefix = process.argv[3] || 'shooter-verify';
const FATAL = /USER SCRIPT ERROR|Parse Error|Failed to instantiate an autoload|The InputMap action|SharedArrayBuffer/i;

// Godot base viewport. Matching the browser viewport to it makes canvas
// coordinates 1:1 with game coordinates, so we can click in-canvas buttons.
const W = 1280, H = 720;

const result = { url: gameUrl, tests: {}, errors: [], statesSeen: [], score: 0, screenshots: [] };

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium',
  ...(process.env.HTTPS_PROXY && !/localhost|127\.0\.0\.1|\[::1\]/.test(gameUrl)
    ? { proxy: { server: process.env.HTTPS_PROXY } }
    : {}),
  args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader',
         '--enable-unsafe-swiftshader', '--disable-dev-shm-usage'],
});
const page = await browser.newPage({ viewport: { width: W, height: H } });

page.on('console', (m) => {
  const line = `[${m.type()}] ${m.text()}`;
  if (FATAL.test(line)) result.errors.push(line);
});
page.on('pageerror', (e) => { if (FATAL.test(String(e))) result.errors.push(String(e)); });

// The engine posts {type:"state"} to the page on every StateMachine change —
// the only trustworthy signal that gameplay really started.
await page.exposeFunction('__shooterState', (s) => {
  if (!result.statesSeen.includes(s)) result.statesSeen.push(s);
});
// ComboSystem beacons {type:"score"} on every kill. A rising score is the only
// PROOF a drone actually died — the first version of this script asserted that
// firing produced no errors, which a room with an unhittable enemy passes.
await page.addInitScript(() => {
  window.__score = 0;
  window.addEventListener('message', (e) => {
    if (!e.data) return;
    if (e.data.type === 'state') window.__shooterState(e.data.value);
    if (e.data.type === 'score') window.__score = Number(e.data.value) || 0;
  });
});

const shot = async (name) => {
  const f = `${prefix}-${name}.png`;
  await page.screenshot({ path: f });
  result.screenshots.push(f);
};

try {
  console.log('[1/5] loading…');
  await page.goto(gameUrl, { waitUntil: 'domcontentloaded', timeout: 90000 });
  await page.waitForSelector('canvas', { timeout: 30000 });
  result.tests.canvas_attached = 'PASS';

  // Boot takes a while under SwiftShader; wait for the menu to actually draw.
  await page.waitForTimeout(25000);
  await shot('menu');
  result.tests.engine_booted = 'PASS';

  console.log('[2/5] opening the prototype…');
  // Menu geometry: the layer-shift column is anchored bottom-left at
  // (24, H - 8 - count*54); "BLUNT FORCE" is the first entry, 300x46.
  const COUNT = 9;
  const x = 24 + 150;
  const y = H - 8 - COUNT * 54 + 23;
  await page.mouse.click(x, y);
  await page.waitForTimeout(6000);
  await shot('room');

  if (!result.statesSeen.includes('PLAYING')) throw new Error('prototype never reached PLAYING');
  result.tests.prototype_playing = 'PASS';

  console.log('[3/5] strafe + aim…');
  await page.keyboard.down('d');
  await page.mouse.move(1000, 300, { steps: 12 });
  await page.waitForTimeout(1200);
  await page.keyboard.up('d');
  await shot('aim');

  console.log('[4/5] firing — must actually kill a drone…');
  // Sweep the aim vertically through the drone's patrol band and fire. Bolts
  // travel ~1440px so any ray crossing the drone connects; the drone needs two
  // hits to die. We require the score beacon to rise — "fired without erroring"
  // is not evidence the enemy is reachable.
  for (let pass = 0; pass < 3 && !(await page.evaluate(() => window.__score)); pass++) {
    for (let i = 0; i < 26; i++) {
      await page.mouse.move(1090, 210 + i * 13, { steps: 2 });
      await page.mouse.down();
      await page.waitForTimeout(110);
      await page.mouse.up();
      await page.waitForTimeout(70);
    }
  }
  result.score = await page.evaluate(() => window.__score);
  await shot('firing');
  result.tests.fire_no_errors = result.errors.length === 0 ? 'PASS' : 'FAIL';
  result.tests.drone_killable = result.score > 0
    ? 'PASS'
    : 'FAIL: score never rose — bolts cannot damage the drone, room is unwinnable';
  if (result.score === 0) result.errors.push('No drone kill registered');

  console.log('[5/5] taking cover…');
  await page.keyboard.down('d');
  await page.waitForTimeout(1600);      // walk into a crate's duck zone
  await page.keyboard.up('d');
  await page.keyboard.down('s');
  await page.waitForTimeout(1500);
  await shot('cover');
  await page.mouse.down();               // peek-fire out of cover
  await page.waitForTimeout(250);
  await page.mouse.up();
  await page.waitForTimeout(800);
  await page.keyboard.up('s');
  await shot('peek');

  result.tests.no_godot_errors = result.errors.length === 0 ? 'PASS' : 'FAIL';
} catch (e) {
  result.errors.push(`Fatal: ${e.message}`);
}

result.passed = result.errors.length === 0 &&
  Object.values(result.tests).every((v) => v === 'PASS') &&
  result.statesSeen.includes('PLAYING');

await browser.close();
fs.writeFileSync(`${prefix}.json`, JSON.stringify(result, null, 2));
console.log('\n=== SHOOTER PROTOTYPE VERIFICATION ===');
console.log(JSON.stringify(result, null, 2));
console.log(result.passed ? '\n✅ prototype reachable and interactive' : '\n❌ FAILED');
process.exit(result.passed ? 0 : 1);

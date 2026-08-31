#!/usr/bin/env node
// Owner-rage residual capture driver (2026-08-18).
//
// The founder's rule for this residual: a claim of FIXED is only valid if a
// browser frame no longer matches the circle they drew. So this walks the real
// web build and screenshots the exact places the complaints came from:
//   stage 3 track  -> orange box gone, mining carts visible, BTC coin legible
//   stage 1 opening-> HUD text size, weed-leaf pickup (music + celebration)
//
// Usage: node scripts/capture-rage-proof.mjs <baseUrl> <mode> <seconds>
//   mode: stage3 | stage1
import fs from 'fs';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require('@playwright/test')); }
catch { ({ chromium } = require(process.env.PLAYWRIGHT_PKG || '/opt/node22/lib/node_modules/playwright/index.js')); }

const base = process.argv[2] || 'http://localhost:8899/game/index.html';
const mode = process.argv[3] || 'stage3';
const runSeconds = parseInt(process.argv[4] || '40', 10);
const OUT = process.env.PLAYTEST_OUT || `docs/captures/2026-08-18-owner-rage/${mode}`;
fs.mkdirSync(OUT, { recursive: true });

const url = `${base}?stage=${mode === 'stage1' ? 1 : 3}`;
const result = { url, mode, booted: false, errors: [], shots: [] };
const ERR_RE = /USER SCRIPT ERROR|Parse Error|Failed to instantiate an autoload|The InputMap action/i;

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium',
  args: ['--no-sandbox', '--enable-unsafe-swiftshader', '--use-gl=angle',
         '--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'],
});

let n = 0;
const shot = async (page, lbl) => {
  const p = `${OUT}/shot-${String(n++).padStart(3, '0')}-${lbl}.png`;
  await page.screenshot({ path: p });
  result.shots.push(p);
  return p;
};

try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', (m) => {
    const t = m.text();
    const benign = /USER WARNING|at: push_warning|No loader found|Blocking on the main thread|ERR_CONNECTION_RESET|Failed to fetch|godot_js_fetch/.test(t);
    if ((m.type() === 'error' || ERR_RE.test(t)) && !benign) result.errors.push(`[${m.type()}] ${t.slice(0, 200)}`);
  });

  console.log(`[1] loading ${url}`);
  await page.goto(url, { waitUntil: 'load', timeout: 120000 });
  // Engine boot + fade into the level.
  await page.waitForTimeout(22000);
  result.booted = true;
  await shot(page, 'level-open');

  const canvas = await page.$('canvas');
  if (canvas) await canvas.click({ position: { x: 640, y: 360 } }).catch(() => {});

  // Walk right in bursts, shooting between them. MOVE is A/D in this game.
  const bursts = Math.max(3, Math.floor(runSeconds / 6));
  for (let i = 0; i < bursts; i++) {
    await page.keyboard.down('KeyD');
    await page.waitForTimeout(2200);
    // A hop keeps him off ledges and shows the airborne props behind him.
    await page.keyboard.press('KeyW').catch(() => {});
    await page.waitForTimeout(1600);
    await page.keyboard.up('KeyD');
    await page.waitForTimeout(600);
    await shot(page, `walk-${i}`);
  }
  await shot(page, 'final');
} catch (e) {
  result.errors.push(`FATAL ${e.message}`);
} finally {
  await browser.close();
}

fs.writeFileSync(`${OUT}/result.json`, JSON.stringify(result, null, 2));
console.log(JSON.stringify({ booted: result.booted, shots: result.shots.length, errors: result.errors }, null, 2));

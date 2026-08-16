#!/usr/bin/env node
// Browser capture of a boss fight on the REAL web build (founder mandate: no
// "boss chases" claim without a browser capture). Loads index.html?boss=N which
// routes straight into the boss arena, drives the player to one wall, holds, and
// screenshots a time sequence so the boss's horizontal travel toward the player
// is visible frame to frame.
//
// Usage: node scripts/capture-boss.mjs <base-url> <bossN> <outPrefix>
//   e.g. node scripts/capture-boss.mjs http://127.0.0.1:8099/index.html 3 boss3
import fs from 'fs';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require('@playwright/test')); }
catch { ({ chromium } = require(process.env.PLAYWRIGHT_PKG || '/opt/node22/lib/node_modules/playwright/index.js')); }

const base = process.argv[2] || 'http://127.0.0.1:8099/index.html';
const bossN = process.argv[3] || '3';
const prefix = process.argv[4] || `boss${bossN}`;
const url = `${base}?boss=${bossN}`;
const outDir = `docs/captures/2026-08-16-bosses`;
fs.mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium',
  args: ['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist'],
});
const shots = [];
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  await page.addInitScript(() => {
    window.__states = [];
    window.addEventListener('message', (e) => { try { if (e.data && e.data.type==='state') window.__states.push(String(e.data.value)); } catch(_){} });
  });
  const consoleTail = [];
  page.on('console', (m) => consoleTail.push(`[${m.type()}] ${m.text().slice(0,200)}`));
  page.on('pageerror', (e) => consoleTail.push(`[pageerror] ${String(e).slice(0,200)}`));

  console.log(`Loading ${url}`);
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForSelector('canvas', { timeout: 15000 });
  // boot
  await page.waitForFunction(() => {
    const s = document.getElementById('status'); const c = document.querySelector('canvas');
    const hid = !s || getComputedStyle(s).display === 'none';
    const live = c && c.width > 0 && !(c.width===300 && c.height===150);
    return hid && live;
  }, { timeout: 45000, polling: 500 }).catch(()=>{});
  // reach PLAYING (the warp routes into the boss level and sets PLAYING)
  const playing = await page.waitForFunction(() => window.__states && window.__states.includes('PLAYING'),
    { timeout: 30000, polling: 500 }).then(()=>true).catch(()=>false);
  // clear any first-run panels
  await page.keyboard.press('Escape'); await page.waitForTimeout(400);
  await page.mouse.click(640, 360); // focus canvas
  await page.waitForTimeout(1500);
  console.log('PLAYING reached:', playing, '| states:', await page.evaluate(()=>window.__states));

  async function shot(tag) {
    const p = `${outDir}/${prefix}_${tag}.png`;
    await page.screenshot({ path: p });
    shots.push(p);
  }
  // Move player to the LEFT wall and hold, so the boss must travel LEFT to chase.
  await shot('t0_spawn');
  await page.keyboard.down('KeyA');
  await page.waitForTimeout(1800);
  await page.keyboard.up('KeyA');
  for (let i = 0; i < 6; i++) { await shot(`left_${i}`); await page.waitForTimeout(500); }
  // Now move to the RIGHT and hold; boss must reverse and chase RIGHT.
  await page.keyboard.down('KeyD');
  await page.waitForTimeout(1800);
  await page.keyboard.up('KeyD');
  for (let i = 0; i < 6; i++) { await shot(`right_${i}`); await page.waitForTimeout(500); }

  fs.writeFileSync(`${outDir}/${prefix}_console.txt`, consoleTail.slice(-60).join('\n'));
  console.log(`captured ${shots.length} frames -> ${outDir}/${prefix}_*.png`);
} catch (e) {
  console.log('CAPTURE ERROR:', e.message);
} finally {
  await browser.close();
}

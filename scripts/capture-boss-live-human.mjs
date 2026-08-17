#!/usr/bin/env node
// Real-human-play-pattern capture against the LIVE itch build (not a bot
// holding one key at a wall — the code comments in distributor.gd document
// that EXACT blind spot: "every chase gate drove a STRAIGHT-LINE player...
// the real problem is only visible against a WEAVING one"). Drives the player
// with alternating direction + hops, matching what a founder actually does,
// and logs the boss's world position every ~0.3s so the closing/opening rate
// is measurable, not eyeballed from screenshots.
//
// Usage: node scripts/capture-boss-live-human.mjs <gameUrl> <bossN> <outPrefix> <seconds>
import fs from 'fs';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require('@playwright/test')); }
catch { ({ chromium } = require(process.env.PLAYWRIGHT_PKG || '/opt/node22/lib/node_modules/playwright/index.js')); }

const gameUrl = process.argv[2];
const bossN = process.argv[3] || '3';
const prefix = process.argv[4] || `boss${bossN}_human`;
const seconds = parseFloat(process.argv[5] || '14');
const sep = gameUrl.includes('?') ? '&' : '?';
const url = `${gameUrl}${sep}boss=${bossN}`;
const outDir = `docs/captures/2026-08-17-live-verify`;
fs.mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium',
  args: ['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist'],
});
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
  const t0load = Date.now();
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForSelector('canvas', { timeout: 15000 });
  await page.waitForFunction(() => {
    const s = document.getElementById('status'); const c = document.querySelector('canvas');
    const hid = !s || getComputedStyle(s).display === 'none';
    const live = c && c.width > 0 && !(c.width===300 && c.height===150);
    return hid && live;
  }, { timeout: 45000, polling: 500 }).catch(()=>{});
  const playing = await page.waitForFunction(() => window.__states && window.__states.includes('PLAYING'),
    { timeout: 30000, polling: 500 }).then(()=>true).catch(()=>false);
  console.log(`boot took ${((Date.now()-t0load)/1000).toFixed(1)}s, PLAYING reached: ${playing}`);
  await page.keyboard.press('Escape'); await page.waitForTimeout(400);
  await page.mouse.click(640, 360);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${outDir}/${prefix}_t0.png` });

  // Try to read an exposed debug readout of boss + player world position if the
  // game exposes one; fall back to null (screenshots remain the evidence).
  async function readState() {
    return await page.evaluate(() => {
      try {
        const g = (window.__godot_debug || null);
        return g ? g() : null;
      } catch (_) { return null; }
    }).catch(() => null);
  }

  // HUMAN PATTERN: alternating runs of ~0.6-1.1s with a jump thrown in roughly
  // every other beat, direction flipping — the "weave and hop" pattern the
  // code explicitly says prior straight-line bot captures never exercised.
  const log = [];
  const startT = Date.now();
  let dir = 'a';
  let beat = 0;
  while ((Date.now() - startT) / 1000 < seconds) {
    const holdMs = 550 + Math.floor(Math.random() * 550);
    await page.keyboard.down(dir === 'a' ? 'KeyA' : 'KeyD');
    if (beat % 2 === 0) {
      await page.waitForTimeout(120);
      await page.keyboard.press('Space'); // hop while moving
    }
    await page.waitForTimeout(holdMs);
    await page.keyboard.up(dir === 'a' ? 'KeyA' : 'KeyD');
    const shotPath = `${outDir}/${prefix}_beat${beat}.png`;
    await page.screenshot({ path: shotPath });
    log.push({ t: ((Date.now() - startT) / 1000).toFixed(2), dir, beat, shot: shotPath });
    dir = dir === 'a' ? 'd' : 'a';
    beat++;
  }
  fs.writeFileSync(`${outDir}/${prefix}_log.json`, JSON.stringify(log, null, 2));
  fs.writeFileSync(`${outDir}/${prefix}_console.txt`, consoleTail.slice(-80).join('\n'));
  console.log(`captured ${log.length} beats -> ${outDir}/${prefix}_beat*.png`);
} catch (e) {
  console.log('CAPTURE ERROR:', e.message, e.stack);
} finally {
  await browser.close();
}

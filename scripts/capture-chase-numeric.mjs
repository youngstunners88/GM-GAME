#!/usr/bin/env node
// NUMERIC chase proof. The founder has rejected "the boss chases" >10 times and
// every prior attempt argued from screenshots, which cannot tell "boss is
// stationary" apart from "boss tracks perfectly while the camera follows the
// player". This reads the game's own world coordinates (level_base.gd's
// test-only chase telemetry, armed only by ?boss=N) and computes the real gap
// over time, so the answer is a number, not an opinion.
//
// Usage: node scripts/capture-chase-numeric.mjs <baseUrl> <bossN> <label> [seconds]
import fs from 'fs';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require('@playwright/test')); }
catch { ({ chromium } = require(process.env.PLAYWRIGHT_PKG || '/opt/node22/lib/node_modules/playwright/index.js')); }

const base = process.argv[2] || 'http://127.0.0.1:8099/index.html';
const bossN = process.argv[3] || '2';
const label = process.argv[4] || `boss${bossN}`;
const seconds = parseFloat(process.argv[5] || '18');
const outDir = 'docs/captures/2026-08-17-chase-numeric';
fs.mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium',
  args: ['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist'],
});
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  await page.addInitScript(() => {
    window.__states = []; window.__chase = [];
    window.addEventListener('message', (e) => {
      try {
        const d = e.data;
        if (!d || !d.type) return;
        if (d.type === 'state') window.__states.push(String(d.value));
        else if (d.type === 'chase') window.__chase.push(d);
      } catch (_) {}
    });
  });
  await page.goto(`${base}?boss=${bossN}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForSelector('canvas', { timeout: 15000 });
  await page.waitForFunction(() => window.__states?.includes('PLAYING'), { timeout: 60000, polling: 500 }).catch(()=>{});
  await page.keyboard.press('Escape'); await page.waitForTimeout(300);
  await page.mouse.click(640, 360);
  await page.waitForTimeout(1200);
  // Wait for telemetry to actually start flowing before driving.
  await page.waitForFunction(() => (window.__chase||[]).length > 5, { timeout: 20000, polling: 250 })
    .catch(()=>console.log('WARN: no chase telemetry seen'));

  // Drive like a human fleeing: alternate direction, hop, never stand still.
  const t0 = Date.now();
  let dir = 'KeyA', beat = 0;
  while ((Date.now() - t0) / 1000 < seconds) {
    await page.keyboard.down(dir);
    if (beat % 2 === 0) { await page.waitForTimeout(100); await page.keyboard.press('Space'); }
    await page.waitForTimeout(700 + Math.floor(Math.random()*400));
    await page.keyboard.up(dir);
    dir = dir === 'KeyA' ? 'KeyD' : 'KeyA';
    beat++;
  }
  const samples = await page.evaluate(() => window.__chase || []);
  await page.screenshot({ path: `${outDir}/${label}_final.png` });
  fs.writeFileSync(`${outDir}/${label}_samples.json`, JSON.stringify(samples));

  if (!samples.length) { console.log(`${label}: NO TELEMETRY — cannot judge`); }
  else {
    const gap = s => Math.abs(s.bx - s.px);
    const bxs = samples.map(s => s.bx);
    const bossTravel = samples.slice(1).reduce((a,s,i)=>a+Math.abs(s.bx-samples[i].bx),0);
    const plyTravel  = samples.slice(1).reduce((a,s,i)=>a+Math.abs(s.px-samples[i].px),0);
    const gaps = samples.map(gap);
    const out = {
      label, samples: samples.length,
      duration_s: +(samples[samples.length-1].t - samples[0].t).toFixed(2),
      boss_x_min: +Math.min(...bxs).toFixed(1), boss_x_max: +Math.max(...bxs).toFixed(1),
      boss_x_range: +(Math.max(...bxs)-Math.min(...bxs)).toFixed(1),
      boss_path_len: +bossTravel.toFixed(1),
      player_path_len: +plyTravel.toFixed(1),
      gap_start: +gaps[0].toFixed(1), gap_end: +gaps[gaps.length-1].toFixed(1),
      gap_min: +Math.min(...gaps).toFixed(1), gap_max: +Math.max(...gaps).toFixed(1),
      gap_mean: +(gaps.reduce((a,b)=>a+b,0)/gaps.length).toFixed(1),
      states: [...new Set(samples.map(s=>s.st))],
      VERDICT_boss_moved: Math.max(...bxs)-Math.min(...bxs) > 40 ? 'MOVES' : 'ESSENTIALLY FROZEN',
    };
    console.log(JSON.stringify(out, null, 2));
    fs.writeFileSync(`${outDir}/${label}_summary.json`, JSON.stringify(out, null, 2));
  }
} catch (e) { console.log('CAPTURE ERROR:', e.message); }
finally { await browser.close(); }

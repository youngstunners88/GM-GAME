#!/usr/bin/env node
// capture-stages.mjs — pan sweep of levels 1-3 via ?stage=N for seam/smudge/sliver
// diagnosis. Usage: node scripts/capture-stages.mjs <base-url> <out-dir> [stage]
import fs from 'fs';
import { chromium } from 'playwright';

const URL_BASE = process.argv[2] || 'http://localhost:8899/game/index.html';
const OUT_DIR = process.argv[3] || 'artifacts/stage-shots';
const ONLY = process.argv[4] ? parseInt(process.argv[4], 10) : null;
fs.mkdirSync(OUT_DIR, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const PINNED = ['/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
                '/opt/pw-browsers/chromium/chrome-linux/chrome'];
const launchOpts = { args: ['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox'] };
for (const p of PINNED) { if (fs.existsSync(p)) { launchOpts.executablePath = p; break; } }
const browser = await chromium.launch(launchOpts);

async function shootStage(stage) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  page.on('console', (m) => { const t=m.text(); if(/USER SCRIPT ERROR|Parse Error|SCRIPT ERROR|Cannot call method/i.test(t)) errors.push(t); });
  page.on('pageerror', (e) => errors.push('pageerror: '+e.message));
  const url = URL_BASE + (URL_BASE.includes('?')?'&':'?') + 'stage=' + stage;
  console.log('opening', url);
  await page.goto(url, { waitUntil:'domcontentloaded', timeout:120000 });
  await page.waitForSelector('canvas', { timeout:120000 });
  await page.waitForFunction(()=>{const c=document.querySelector('canvas');return c&&c.width>100&&c.height>100;},{timeout:180000});
  await sleep(9000);
  await page.screenshot({ path: `${OUT_DIR}/s${stage}_00.png` });
  for (let i=1;i<=8;i++){
    await page.keyboard.down('KeyD'); await sleep(1100); await page.keyboard.up('KeyD'); await sleep(450);
    await page.screenshot({ path: `${OUT_DIR}/s${stage}_0${i}.png` });
  }
  console.log('stage',stage,'errors',errors.length, errors.slice(0,3));
  await page.close();
}
for (const s of (ONLY?[ONLY]:[1,2,3])) await shootStage(s);
await browser.close();
console.log('DONE');

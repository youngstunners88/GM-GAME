#!/usr/bin/env node
// capture-warp.mjs — capture a stage at explicit spawn_x positions (no walking).
// Usage: node scripts/capture-warp.mjs <base-url> <out-dir> <stage> <x1,x2,...>
import fs from 'fs';
import { chromium } from 'playwright';
const URL_BASE = process.argv[2];
const OUT_DIR = process.argv[3];
const STAGE = process.argv[4];
const XS = (process.argv[5]||'').split(',').filter(Boolean);
fs.mkdirSync(OUT_DIR, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const PINNED = ['/opt/pw-browsers/chromium-1194/chrome-linux/chrome','/opt/pw-browsers/chromium/chrome-linux/chrome'];
const launchOpts = { args: ['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox'] };
for (const p of PINNED) { if (fs.existsSync(p)) { launchOpts.executablePath = p; break; } }
const browser = await chromium.launch(launchOpts);
for (const x of XS) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors=[]; page.on('console',(m)=>{const t=m.text();if(/USER SCRIPT ERROR|Parse Error|SCRIPT ERROR/i.test(t))errors.push(t);});
  const url = `${URL_BASE}?stage=${STAGE}&spawn_x=${x}`;
  console.log('opening', url);
  await page.goto(url, { waitUntil:'domcontentloaded', timeout:120000 });
  await page.waitForSelector('canvas',{timeout:120000});
  await page.waitForFunction(()=>{const c=document.querySelector('canvas');return c&&c.width>100&&c.height>100;},{timeout:180000});
  await sleep(9500); // let warp + camera settle
  const f = `${OUT_DIR}/s${STAGE}_x${x}.png`;
  await page.screenshot({ path: f });
  console.log('  ->', f, 'errs', errors.length);
  await page.close();
}
await browser.close();
console.log('DONE');

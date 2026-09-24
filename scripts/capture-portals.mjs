#!/usr/bin/env node
// capture-portals.mjs — capture each protocol portal ladder, then the study
// room it opens, without any walking.
// Usage: node scripts/capture-portals.mjs <base-url> <out-dir>
import fs from 'fs';
import { chromium } from 'playwright';

const URL_BASE = process.argv[2];
const OUT_DIR = process.argv[3];
if (!URL_BASE || !OUT_DIR) {
  console.error('usage: node scripts/capture-portals.mjs <base-url> <out-dir>');
  process.exit(2);
}
fs.mkdirSync(OUT_DIR, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const PINNED = ['/opt/pw-browsers/chromium-1194/chrome-linux/chrome','/opt/pw-browsers/chromium/chrome-linux/chrome'];
const launchOpts = { args: ['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox'] };
for (const p of PINNED) { if (fs.existsSync(p)) { launchOpts.executablePath = p; break; } }

// stage id, ladder x in the level, protocol id
const STAGES = [ [1, 2100, 'smoke'], [2, 3300, 'diamonds'], [3, 3100, 'gold'] ];
const ERR_RE = /USER SCRIPT ERROR|Parse Error|SCRIPT ERROR/i;

async function waitForBoot(page) {
  await page.waitForSelector('canvas', { timeout: 120000 });
  await page.waitForFunction(() => { const c = document.querySelector('canvas'); return c && c.width > 100 && c.height > 100; }, { timeout: 180000 });
  await sleep(9500); // let warp + camera settle
}

async function openPage(browser) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  page.on('console', (m) => { const t = m.text(); if (ERR_RE.test(t)) errors.push(t); });
  return { page, errors };
}

let failures = 0;
try {
  const browser = await chromium.launch(launchOpts);

  for (const [stage, x, proto] of STAGES) {
    // (a) the ladder in situ, approached from the left
    {
      const { page, errors } = await openPage(browser);
      const url = `${URL_BASE}?stage=${stage}&spawn_x=${x - 250}`;
      console.log('opening', url);
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
      await waitForBoot(page);
      const f = `${OUT_DIR}/${proto}_ladder.png`;
      await page.screenshot({ path: f });
      console.log('  ->', f, 'errs', errors.length);
      await page.close();
    }

    // (b) stand in the shaft, press E, land in the study room
    {
      const { page, errors } = await openPage(browser);
      const url = `${URL_BASE}?stage=${stage}&spawn_x=${x}`;
      console.log('opening', url);
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
      await waitForBoot(page);
      for (let i = 0; i < 3; i += 1) {
        await page.keyboard.down('KeyE');
        await sleep(150);
        await page.keyboard.up('KeyE');
        await sleep(400);
      }
      await sleep(5000);
      const f = `${OUT_DIR}/${proto}_room.png`;
      await page.screenshot({ path: f });
      console.log('  ->', f, 'errs', errors.length);
      await page.close();
    }
  }

  await browser.close();
} catch (err) {
  console.error('capture-portals crashed:', err && err.stack ? err.stack : err);
  failures += 1;
}

if (failures > 0) {
  process.exit(1);
}
console.log('DONE');

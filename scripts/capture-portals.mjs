#!/usr/bin/env node
// capture-portals.mjs — capture each protocol portal ladder, the visible climb
// down its shaft, and the tour strip it opens.
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
const DESCEND_RE = /\[PortalLadder\] shaft bottom reached/;
const TOUR_WAIT_MS = 8000;
const FADE_SETTLE_MS = 1500;

async function waitForBoot(page) {
  await page.waitForSelector('canvas', { timeout: 120000 });
  await page.waitForFunction(() => { const c = document.querySelector('canvas'); return c && c.width > 100 && c.height > 100; }, { timeout: 180000 });
  await sleep(9500); // let warp + camera settle
}

async function openPage(browser) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  const consoleErrors = [];
  const lines = [];
  page.on('console', (m) => {
    const t = m.text();
    lines.push(t);
    if (ERR_RE.test(t)) errors.push(t);
    if (m.type() === 'error') consoleErrors.push(t);
  });
  page.on('pageerror', (e) => { consoleErrors.push(String(e)); });
  return { page, errors, consoleErrors, lines };
}

async function focusCanvas(page) {
  try { await page.locator('canvas').first().focus({ timeout: 2000 }); } catch (_) { /* keyboard still reaches the page */ }
}

function logErrors(label, errors, consoleErrors) {
  console.log(`  ${label}: script errors ${errors.length}, console errors ${consoleErrors.length}`);
  for (const e of errors.slice(0, 5)) console.log('    !', e);
  for (const e of consoleErrors.slice(0, 6)) console.log('    console:', e.slice(0, 200));
}

let failures = 0;
try {
  const browser = await chromium.launch(launchOpts);

  for (const [stage, x, proto] of STAGES) {
    // (a) the ladder in situ, approached from the left
    {
      const { page, errors, consoleErrors } = await openPage(browser);
      const url = `${URL_BASE}?stage=${stage}&spawn_x=${x - 250}`;
      console.log('opening', url);
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
      await waitForBoot(page);
      const f = `${OUT_DIR}/${proto}_ladder.png`;
      await page.screenshot({ path: f });
      console.log('  ->', f);
      logErrors(`${proto} ladder`, errors, consoleErrors);
      await page.close();
    }

    // (b) stand at the mouth, hold down, climb the shaft, land in the tour
    {
      const { page, errors, consoleErrors, lines } = await openPage(browser);
      const url = `${URL_BASE}?stage=${stage}&spawn_x=${x}`;
      console.log('opening', url);
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
      await waitForBoot(page);
      await focusCanvas(page);

      await page.keyboard.down('ArrowDown');
      await sleep(700);
      const climb = `${OUT_DIR}/${proto}_climb.png`;
      await page.screenshot({ path: climb });
      console.log('  ->', climb, '(mid-shaft, still holding down)');

      // Keep holding until the ladder reports the shaft bottom, then give the
      // fade + scene load a moment. Cap the whole hold at TOUR_WAIT_MS.
      const holdStart = Date.now();
      let descended = false;
      while (Date.now() - holdStart < TOUR_WAIT_MS) {
        if (lines.some((t) => DESCEND_RE.test(t))) { descended = true; break; }
        await sleep(100);
      }
      if (descended) {
        const left = TOUR_WAIT_MS - (Date.now() - holdStart);
        await sleep(Math.max(0, Math.min(FADE_SETTLE_MS, left)));
      }
      await page.keyboard.up('ArrowDown');
      console.log(`  descend ${descended ? 'reported' : 'NOT reported'} after ${Date.now() - holdStart} ms`);

      await sleep(3000);
      const start = `${OUT_DIR}/${proto}_tour_start.png`;
      await page.screenshot({ path: start });
      console.log('  ->', start);

      await page.keyboard.down('ArrowRight');
      await sleep(2500);
      await page.keyboard.up('ArrowRight');
      await sleep(300);
      const mid = `${OUT_DIR}/${proto}_tour_mid.png`;
      await page.screenshot({ path: mid });
      console.log('  ->', mid);

      logErrors(`${proto} climb+tour`, errors, consoleErrors);
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

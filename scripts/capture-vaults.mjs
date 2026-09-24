#!/usr/bin/env node
// capture-vaults.mjs — real-browser screenshots of the Fort Knox & Diamond Vault
// staking realms via the test-only ?vault=fort|diamond warp in main_menu.gd.
// Usage: node scripts/capture-vaults.mjs <base-url> <out-dir>
import fs from 'fs';
import { chromium } from 'playwright';

const URL_BASE = process.argv[2] || 'http://localhost:8899/game/index.html';
const OUT_DIR = process.argv[3] || 'artifacts/vault-shots';
fs.mkdirSync(OUT_DIR, { recursive: true });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const PINNED_CANDIDATES = [
  '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  '/opt/pw-browsers/chromium/chrome-linux/chrome',
];
const launchOpts = {
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
         '--disable-dev-shm-usage', '--no-sandbox'],
};
for (const p of PINNED_CANDIDATES) { if (fs.existsSync(p)) { launchOpts.executablePath = p; break; } }

const browser = await chromium.launch(launchOpts);

async function shoot(vault) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  page.on('console', (m) => {
    const t = m.text();
    if (/USER SCRIPT ERROR|Parse Error|SCRIPT ERROR|Cannot call method/i.test(t)) errors.push(t);
  });
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  const url = URL_BASE + (URL_BASE.includes('?') ? '&' : '?') + 'vault=' + vault;
  console.log('opening', url);
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
  await page.waitForSelector('canvas', { timeout: 120000 });
  await page.waitForFunction(() => {
    const c = document.querySelector('canvas');
    return c && c.width > 100 && c.height > 100;
  }, { timeout: 180000 });
  await sleep(9000);
  const shots = [];
  // shot 0: spawn view
  let f = `${OUT_DIR}/${vault}_00_spawn.png`;
  await page.screenshot({ path: f }); shots.push(f);
  // pan right by holding D to scroll the parallax and expose any mirror/paste seam
  for (let i = 1; i <= 4; i++) {
    await page.keyboard.down('KeyD');
    await sleep(1400);
    await page.keyboard.up('KeyD');
    await sleep(500);
    f = `${OUT_DIR}/${vault}_0${i}_pan.png`;
    await page.screenshot({ path: f }); shots.push(f);
  }
  console.log(vault, 'errors:', errors.length, errors.slice(0, 4));
  await page.close();
  return shots;
}

for (const v of ['fort', 'diamond']) {
  await shoot(v);
}
await browser.close();
console.log('DONE');

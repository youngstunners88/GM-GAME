// live-itch-probe.mjs - prove what the PLAYERS get on itch, from the terminal, in a real Chromium.
//   node scripts/live-itch-probe.mjs [--expect <build-tag-substring>] [--extras] [--shot <png>]
// It opens the public itch page, finds the game iframe (the page the players actually run), loads it in a
// browser and reads the game's own console: the [BUILD] line, the extras log line and the extras HTTP status.
// Exit 0 only when every asked-for check passes. Never report "live" from anything else.
import { createRequire } from 'node:module';
import { existsSync, readdirSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const args = process.argv.slice(2);
const opt = (k) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : ''; };
const expect = opt('--expect');
const wantExtras = args.includes('--extras');
const shot = opt('--shot');
const PAGE = process.env.ITCH_PAGE || 'https://youngstunners88.itch.io/smokerealm';

// playwright: the npx cache copy (no project install needed), else a local node_modules
function loadPlaywright() {
  const npx = join(homedir(), '.npm', '_npx');
  if (existsSync(npx)) for (const d of readdirSync(npx)) {
    const p = join(npx, d, 'node_modules', 'playwright', 'index.mjs');
    if (existsSync(p)) return import(p);
  }
  return import('playwright');
}
const { chromium } = await loadPlaywright();
const chrome = join(homedir(), '.cache', 'ms-playwright');
const exe = existsSync(chrome) ? readdirSync(chrome).filter((d) => d.startsWith('chromium-')).sort().map((d) => join(chrome, d, 'chrome-linux64', 'chrome')).find(existsSync) : undefined;

// --url <game index.html> probes a game directly (a local export behind tools/ep2_extras/gzip_server.py); otherwise the public page's iframe
let gameUrl = opt('--url');
if (!gameUrl) {
  const page0 = await fetch(PAGE).then((r) => r.text());
  const m = page0.match(/https:\/\/html-classic\.itch\.zone\/html\/\d+-\d+\/index\.html\?v=\d+/);
  if (!m) { console.log('FAIL: no game iframe on the public page'); process.exit(1); }
  gameUrl = m[0].replace(/&amp;/g, '&');
}
gameUrl += (gameUrl.includes('?') ? '&' : '?') + 'ep2=1';

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_BIN || exe, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const lines = [];
const extrasStatus = [];
page.on('console', (msg) => { const t = msg.text(); if (/\[BUILD\]|\[EP2\]/.test(t)) lines.push(t.slice(0, 200)); });
page.on('response', (r) => { if (r.url().includes('ep2_extras.pck')) extrasStatus.push(r.status()); });
await page.goto(gameUrl, { waitUntil: 'domcontentloaded' });
const end = Date.now() + 180000;
while (Date.now() < end && !lines.some((l) => /\[EP2\] extras (ready|failed)/.test(l))) await page.waitForTimeout(500);
if (shot) await page.screenshot({ path: shot });
await browser.close();

const build = (lines.find((l) => l.startsWith('[BUILD]')) || '').replace(/^\[BUILD\].*build\s*/, '').trim();
const extras = (lines.find((l) => /\[EP2\] extras/.test(l)) || '').trim();
const checks = [];
checks.push(['game page loaded and printed its build tag', build !== '', build]);
if (expect) checks.push([`live build tag contains ${expect}`, build.includes(expect), build]);
if (wantExtras) checks.push(['extras log says ready', /extras ready/.test(extras), extras || 'no extras line']);
console.log(JSON.stringify({ gameUrl, build, extras, extrasHttp: extrasStatus }, null, 1));
let ok = true;
for (const [label, pass, detail] of checks) { console.log(`${pass ? 'PASS' : 'FAIL'}  ${label}  (${detail})`); ok = ok && pass; }
process.exit(ok ? 0 : 1);

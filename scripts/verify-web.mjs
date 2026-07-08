#!/usr/bin/env node
// Live-site smoke test: open the launcher in headless Chromium, press PLAY,
// and report every console message / page error / failed request from both
// the launcher and the Godot game iframe. Exit 0 only if the engine boots.
//
// Usage: node scripts/verify-web.mjs [url] [screenshotPath]

import { createRequire } from 'module';
// Resolve the globally installed playwright (ESM ignores NODE_PATH).
const require = createRequire(import.meta.url);
const { chromium } = require(
  process.env.PLAYWRIGHT_PKG || '/opt/node22/lib/node_modules/playwright/index.js'
);

const URL = process.argv[2] || 'https://lil-blunt-game.vercel.app/';
const SHOT = process.argv[3] || '/tmp/claude-0/verify-web.png';

const executablePath = process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium/chrome-linux/chrome';

const logs = [];
const log = (tag, text) => {
  const line = `[${tag}] ${text}`;
  logs.push(line);
  console.log(line);
};

const browser = await chromium.launch({
  executablePath,
  args: [
    '--no-sandbox',
    '--enable-unsafe-swiftshader',
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--enable-webgl',
    '--ignore-gpu-blocklist',
  ],
});

const page = await browser.newPage({ viewport: { width: 900, height: 1600 } });

page.on('console', (m) => log(`console:${m.type()}`, m.text().slice(0, 400)));
page.on('pageerror', (e) => log('pageerror', String(e).slice(0, 400)));
page.on('requestfailed', (r) =>
  log('requestfailed', `${r.url().slice(0, 120)} — ${r.failure()?.errorText}`)
);
page.on('frameattached', (f) => log('frame', `attached: ${f.url() || '(pending)'}`));

log('info', `opening ${URL}`);
await page.goto(URL, { waitUntil: 'networkidle', timeout: 60000 });

// Capability probe from the top-level page.
const caps = await page.evaluate(() => ({
  crossOriginIsolated: globalThis.crossOriginIsolated,
  hasSAB: typeof SharedArrayBuffer !== 'undefined',
  webgl2: (() => {
    try { return !!document.createElement('canvas').getContext('webgl2'); }
    catch { return false; }
  })(),
  ua: navigator.userAgent.slice(0, 80),
}));
log('caps', JSON.stringify(caps));

await page.click('#playBtn');
log('info', 'clicked PLAY');

// Give the loading animation + engine boot time.
await page.waitForTimeout(20000);

// Any Godot script/parse error is an automatic failure — these are the
// silent killers that made the game "not work" while the menu still rendered.
const scriptErrors = () =>
  logs.filter((l) => /USER SCRIPT ERROR|Parse Error|Failed to instantiate an autoload/.test(l));

const frame = page.frames().find((f) => f.url().includes('game/index.html'));
if (!frame) {
  log('result', 'FAIL — game iframe never attached');
} else {
  const state = await frame.evaluate(() => {
    const status = document.getElementById('status-notice');
    const canvas = document.getElementById('canvas');
    return {
      crossOriginIsolated: globalThis.crossOriginIsolated,
      notice: status ? status.textContent.slice(0, 300) : null,
      noticeVisible: status ? getComputedStyle(status).display !== 'none' : false,
      canvasSize: canvas ? `${canvas.width}x${canvas.height}` : 'no canvas',
      engineStarted: typeof window.Engine !== 'undefined',
    };
  }).catch((e) => ({ evalError: String(e).slice(0, 200) }));
  log('framestate', JSON.stringify(state));

  const booted =
    !state.evalError &&
    !state.noticeVisible &&
    state.canvasSize !== 'no canvas' &&
    state.canvasSize !== '0x0' &&
    state.canvasSize !== '300x150';
  log('result', booted ? 'PASS — engine booted' : 'FAIL — see framestate/notice above');

  if (booted) {
    // Drive into Level 1: the Godot main menu is in-canvas; "PLAY LEVEL 1"
    // sits mid-screen (see design/art_direction_reference.md HUD notes).
    const vp = page.viewportSize();
    await page.mouse.click(vp.width * 0.5, vp.height * 0.517);
    log('info', 'clicked PLAY LEVEL 1 (canvas)');
    await page.waitForTimeout(9000);
    await page.screenshot({ path: SHOT.replace('.png', '-level.png') });
    log('info', `level screenshot: ${SHOT.replace('.png', '-level.png')}`);
  }
}

const errs = scriptErrors();
if (errs.length) {
  log('result', `FAIL — ${errs.length} Godot script/autoload errors (see above)`);
} else {
  log('info', 'no Godot script errors detected');
}

await page.screenshot({ path: SHOT, fullPage: false });
log('info', `screenshot: ${SHOT}`);

await browser.close();

const failed = logs.some((l) => l.startsWith('[result] FAIL'));
process.exit(failed ? 1 : 0);

#!/usr/bin/env node
// Playwright verification for a DIRECT Godot web export URL (game/index.html,
// an itch.io embed frame, or a local build served over http). For the Vercel
// launcher page (with the PLAY button + iframe), use scripts/verify-web.mjs.
//
// Gates (all must pass):
//   1. page loads, Godot canvas attaches
//   2. engine BOOTS: loading overlay (#status) hides and canvas leaves its
//      default size — a splash screen alone is NOT a pass
//   3. no Godot script errors (USER SCRIPT ERROR / Parse Error / autoload /
//      InputMap) and no SharedArrayBuffer errors (thread_support regression)
//   4. clicks PLAY LEVEL 1 on the in-canvas menu, waits, screenshots gameplay
//
// Usage: node scripts/verify-game.mjs <game-url> [screenshot.png]
// Exit 0 = verified. Artifacts: game-verify.json, game-verify.png,
// game-verify-level.png

import fs from 'fs';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);

// Prefer the local @playwright/test install; fall back to global playwright.
let chromium;
try {
  ({ chromium } = require('@playwright/test'));
} catch {
  ({ chromium } = require(
    process.env.PLAYWRIGHT_PKG || '/opt/node22/lib/node_modules/playwright/index.js'
  ));
}

const gameUrl = process.argv[2] || 'https://lil-blunt-game.vercel.app/game/index.html';
const screenshotFile = process.argv[3] || 'game-verify.png';
const levelShot = screenshotFile.replace(/\.png$/, '-level.png');
const resultFile = 'game-verify.json';

const result = {
  url: gameUrl,
  timestamp: new Date().toISOString(),
  tests: {},
  errors: [],
  consoleTail: [],
  screenshots: [screenshotFile],
  passed: false,
};

const GODOT_ERROR_RE =
  /USER SCRIPT ERROR|Parse Error|Failed to instantiate an autoload|The InputMap action|SharedArrayBuffer/i;

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium',
  // Sandboxed environments route all egress through a mandatory proxy;
  // Chromium ignores the env vars unless told explicitly.
  ...(process.env.HTTPS_PROXY && !gameUrl.includes('localhost')
    ? { proxy: { server: process.env.HTTPS_PROXY } }
    : {}),
  // SwiftShader flags: headless Chromium has no GPU; without these WebGL (and
  // therefore Godot rendering) fails even though the page "loads".
  args: [
    '--no-sandbox',
    '--enable-unsafe-swiftshader',
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--enable-webgl',
    '--ignore-gpu-blocklist',
  ],
});

try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

  // The game's StateMachine posts {type:"state", value:<STATE>} to the page
  // (same-origin postMessage) on every transition. Collect them — gate 4 needs
  // a POSITIVE "PLAYING" signal, not just "no errors after clicking".
  await page.addInitScript(() => {
    window.__states = [];
    window.addEventListener('message', (e) => {
      try {
        if (e.data && e.data.type === 'state') window.__states.push(String(e.data.value));
      } catch (_) { /* ignore */ }
    });
  });

  page.on('console', (m) => {
    const line = `[${m.type()}] ${m.text().slice(0, 300)}`;
    result.consoleTail = [...result.consoleTail.slice(-30), line];
    // Known-benign patterns:
    // - push_warning() output (Godot routes it through console.error)
    // - missing placeholder audio (fixed in audio_manager.gd; still present in
    //   builds exported before that fix)
    // - emscripten main-thread warning (threaded builds only; gone once the
    //   non-threaded export ships)
    // ALLOW_BACKEND_FETCH_ERRORS=1: the Claude remote sandbox's egress proxy
    // blocks Chromium's external HTTPS (documented skill gotcha), so the
    // game's calls to its LIVE backend reset — an environment artifact, not a
    // game bug (the game degrades to offline mode and still reaches PLAYING).
    // CI runners CAN reach the backend, so CI runs stay strict by default.
    const sandboxEgress =
      process.env.ALLOW_BACKEND_FETCH_ERRORS === '1' &&
      /ERR_CONNECTION_RESET|Failed to fetch|godot_js_fetch/.test(m.text());
    const benign =
      sandboxEgress ||
      /USER WARNING|at: push_warning|No loader found for resource: res:\/\/src\/assets\/(sounds|music)\/|at: _load \(core\/io\/resource_loader|Blocking on the main thread/.test(
        m.text()
      );
    if ((m.type() === 'error' || GODOT_ERROR_RE.test(m.text())) && !benign)
      result.errors.push(line);
  });
  page.on('pageerror', (e) => result.errors.push(`[pageerror] ${String(e).slice(0, 300)}`));

  // Gate 1: load + canvas attach
  console.log('[1/4] Loading page + waiting for canvas...');
  await page.goto(gameUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForSelector('canvas', { timeout: 15000 });
  result.tests.canvas_attached = 'PASS';

  // Gate 2: real engine boot — poll until the Godot loading overlay hides and
  // the canvas has been resized by the engine. A splash screenshot is a FAIL.
  console.log('[2/4] Waiting for engine boot (status overlay hides)...');
  const booted = await page
    .waitForFunction(
      () => {
        const status = document.getElementById('status');
        const canvas = document.querySelector('canvas');
        const statusHidden = !status || getComputedStyle(status).display === 'none';
        const canvasLive =
          canvas && canvas.width > 0 && !(canvas.width === 300 && canvas.height === 150);
        return statusHidden && canvasLive;
      },
      { timeout: 45000, polling: 500 }
    )
    .then(() => true)
    .catch(() => false);
  result.tests.engine_booted = booted ? 'PASS' : 'FAIL: loading overlay never cleared';
  if (!booted) result.errors.push('Engine did not finish booting within 45s');

  // Gate 3: script + threading errors accumulated so far
  console.log('[3/4] Checking console for Godot/threading errors...');
  const godotErrors = result.errors.filter((e) => GODOT_ERROR_RE.test(e));
  result.tests.no_godot_errors = godotErrors.length === 0 ? 'PASS' : `FAIL: ${godotErrors.length} error(s)`;
  const sab = result.errors.some((e) => /SharedArrayBuffer/i.test(e));
  result.tests.thread_support = sab
    ? 'FAIL: SharedArrayBuffer error — thread_support must be false'
    : 'PASS';

  await page.waitForTimeout(2000); // let the menu settle
  await page.screenshot({ path: screenshotFile });

  // Gate 4: drive into Level 1 and REQUIRE the game's own PLAYING state
  // beacon. (The old version only checked "no new errors after clicking" —
  // a missed click false-passed with a menu screenshot as "gameplay".)
  if (booted) {
    console.log('[4/4] Clicking PLAY LEVEL 1 and waiting for PLAYING state...');
    const vp = page.viewportSize();
    // Current menu layout: PLAY button center ≈ y 0.60 (was 0.553 pre-subtitle).
    await page.mouse.click(vp.width * 0.5, vp.height * 0.6);
    // First run shows the optional email-signup panel; Escape skips it (the
    // panel's documented keyboard path). Harmless if no panel appeared.
    await page.waitForTimeout(2500);
    await page.keyboard.press('Escape');
    const playing = await page
      .waitForFunction(() => window.__states && window.__states.includes('PLAYING'), {
        timeout: 20000,
        polling: 500,
      })
      .then(() => true)
      .catch(() => false);
    await page.waitForTimeout(4000); // let gameplay actually render
    await page.screenshot({ path: levelShot });
    result.screenshots.push(levelShot);
    result.statesSeen = await page.evaluate(() => window.__states || []);
    const newErrors = result.errors.filter((e) => GODOT_ERROR_RE.test(e));
    if (!playing) {
      result.tests.level_1_runs = 'FAIL: PLAYING state never reached (click missed or level failed to load)';
      result.errors.push('Level 1 never reached PLAYING state');
    } else {
      result.tests.level_1_runs =
        newErrors.length === godotErrors.length ? 'PASS' : 'FAIL: errors during gameplay';
    }
  } else {
    result.tests.level_1_runs = 'SKIP: engine never booted';
  }

  result.passed =
    Object.values(result.tests).every((v) => v === 'PASS') && result.errors.length === 0;
} catch (err) {
  result.errors.push(`Fatal: ${err.message}`);
} finally {
  await browser.close();
}

fs.writeFileSync(resultFile, JSON.stringify(result, null, 2));
console.log('\n=== VERIFICATION RESULT ===');
console.log(JSON.stringify(result, null, 2));
console.log(result.passed ? '\n✅ VERIFIED — game boots and plays' : '\n❌ FAILED — see errors');
process.exit(result.passed ? 0 : 1);

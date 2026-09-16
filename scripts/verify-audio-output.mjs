#!/usr/bin/env node
// Real audio-OUTPUT verification: does sound actually reach the WebAudio
// destination, not just "AudioContext.state === 'running'" or "bus is
// unmuted / volume_db is 0". Those checks are NECESSARY but proved NOT
// SUFFICIENT on 2026-09-16 — a founder P0 report ("all sound has
// disappeared, only cutscene videos still play") shipped past every prior
// headless bus-health gate, because the actual regression was
// `AudioServer.set_bus_send(idx, "Master")` being called (redundantly —
// new buses already default to "Master") on each Episode 2 audio bus in
// audio_manager.gd::_setup_ep2_buses(). That call corrupts Godot 4.3's
// non-threaded HTML5 audio mix graph: every AudioStreamPlayer on every bus
// then produces genuine, permanent silence, while bus mute flags and
// volume_db stay reported as perfectly healthy (0 dB, unmuted) the whole
// time. Root-caused by bisecting bus setup in a from-scratch minimal Godot
// project until silence reproduced deterministically (see git history on
// this file's introduction for the full account).
//
// This script taps a real AnalyserNode into whatever connects to
// `AudioContext.destination` (works regardless of whether Godot's web
// driver uses an AudioWorkletNode, ScriptProcessorNode, or anything else)
// and measures REAL peak sample amplitude while:
//   1. idle at the main menu (informational only — no BGM is expected here)
//   2. idle inside Level 1 (BGM must be audible)
//   3. pressing jump repeatedly (the jump SFX must spike)
//
// A silent build with zero errors in the console and healthy bus state is
// exactly the failure mode this exists to catch. Treat this as load-bearing
// for any change that touches AudioServer bus setup, not just SFX/BGM code.
//
// Usage: node scripts/verify-audio-output.mjs [game-url] [--json out.json]
// Exit 0 = audible. Exit 1 = silent or inconclusive (see printed reason).

import fs from 'fs';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);

let chromium;
try {
  ({ chromium } = require('@playwright/test'));
} catch {
  ({ chromium } = require(
    process.env.PLAYWRIGHT_PKG || '/opt/node22/lib/node_modules/playwright/index.js'
  ));
}

const args = process.argv.slice(2);
const jsonIdx = args.indexOf('--json');
const jsonOut = jsonIdx >= 0 ? args[jsonIdx + 1] : null;
const gameUrl = args.find((a) => !a.startsWith('--') && a !== jsonOut) || 'http://127.0.0.1:8899/game/index.html';

// A real jump/BGM spike reads well above this on a 0-128 peak scale; the
// threshold is deliberately low so genuine-but-quiet audio still passes
// while true silence (a flat 0 for the whole sampling window) still fails.
const AUDIBLE_THRESHOLD = 5;

const result = { url: gameUrl, tests: {}, passed: false };

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium',
  args: [
    '--no-sandbox',
    '--enable-unsafe-swiftshader',
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--enable-webgl',
    '--ignore-gpu-blocklist',
    '--autoplay-policy=no-user-gesture-required',
  ],
});

try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

  await page.addInitScript(() => {
    const OrigAC = window.AudioContext || window.webkitAudioContext;
    if (!OrigAC) return;
    function instrument(ctx) {
      window.__ctx = ctx;
      const analyser = ctx.createAnalyser();
      analyser.fftSize = 2048;
      analyser.connect(ctx.destination);
      // Splice the analyser into every connection that targets
      // ctx.destination, regardless of what kind of node Godot's driver
      // uses (AudioWorkletNode, ScriptProcessorNode, plain source nodes).
      const origConnect = AudioNode.prototype.connect;
      AudioNode.prototype.connect = function (dest, ...rest) {
        if (dest === ctx.destination) return origConnect.call(this, analyser, ...rest);
        return origConnect.call(this, dest, ...rest);
      };
      const data = new Uint8Array(analyser.fftSize);
      window.__samplePeak = () => {
        analyser.getByteTimeDomainData(data);
        let peak = 0;
        for (let i = 0; i < data.length; i++) {
          const v = Math.abs(data[i] - 128);
          if (v > peak) peak = v;
        }
        return peak;
      };
    }
    window.AudioContext = new Proxy(OrigAC, {
      construct(target, args2) {
        const ctx = new target(...args2);
        instrument(ctx);
        return ctx;
      },
    });
  });

  const consoleErrors = [];
  page.on('console', (m) => {
    if (m.type() === 'error') consoleErrors.push(m.text().slice(0, 300));
  });

  console.log('[1/4] loading', gameUrl);
  await page.goto(gameUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForSelector('canvas', { timeout: 15000 });

  console.log('[2/4] waiting for engine boot...');
  await page
    .waitForFunction(
      () => {
        const status = document.getElementById('status');
        const canvas = document.querySelector('canvas');
        const statusHidden = !status || getComputedStyle(status).display === 'none';
        const canvasLive = canvas && canvas.width > 0 && !(canvas.width === 300 && canvas.height === 150);
        return statusHidden && canvasLive;
      },
      { timeout: 45000, polling: 500 }
    )
    .catch(() => console.log('  (boot wait timed out, continuing anyway)'));
  await page.waitForTimeout(1000);

  // First click: dismiss the controls panel + unlock WebAudio.
  await page.keyboard.press('Escape');
  await page.waitForTimeout(400);
  const vp = page.viewportSize();
  await page.mouse.click(vp.width * 0.5, vp.height * 0.5);
  await page.waitForTimeout(500);

  const ctxState = await page.evaluate(() => (window.__ctx ? window.__ctx.state : 'NO_CONTEXT'));
  result.tests.audio_context_running = ctxState === 'running' ? 'PASS' : `FAIL: state=${ctxState}`;

  console.log('[3/4] entering Level 1 and sampling BGM...');
  await page.mouse.click(vp.width * 0.5, vp.height * 0.71);
  await page.waitForTimeout(2500);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(1500);

  const levelPeaks = [];
  for (let i = 0; i < 12; i++) {
    await page.waitForTimeout(150);
    levelPeaks.push(await page.evaluate(() => (window.__samplePeak ? window.__samplePeak() : -1)));
  }
  const maxLevelPeak = Math.max(...levelPeaks);
  result.tests.bgm_audible = maxLevelPeak >= AUDIBLE_THRESHOLD
    ? 'PASS'
    : `FAIL: max peak ${maxLevelPeak} < threshold ${AUDIBLE_THRESHOLD} (peaks: ${levelPeaks})`;

  console.log('[4/4] triggering jump SFX...');
  const jumpPeaks = [];
  for (let i = 0; i < 8; i++) {
    await page.keyboard.down('Space');
    await page.waitForTimeout(60);
    await page.keyboard.up('Space');
    for (let j = 0; j < 5; j++) {
      await page.waitForTimeout(40);
      jumpPeaks.push(await page.evaluate(() => (window.__samplePeak ? window.__samplePeak() : -1)));
    }
  }
  const maxJumpPeak = Math.max(...jumpPeaks);
  result.tests.jump_sfx_audible = maxJumpPeak >= AUDIBLE_THRESHOLD
    ? 'PASS'
    : `FAIL: max peak ${maxJumpPeak} < threshold ${AUDIBLE_THRESHOLD} (peaks: ${jumpPeaks})`;

  result.maxLevelPeak = maxLevelPeak;
  result.maxJumpPeak = maxJumpPeak;
  result.consoleErrorsTail = consoleErrors.slice(-20);
  result.passed = Object.values(result.tests).every((v) => v === 'PASS');
} catch (err) {
  result.tests.fatal = `FAIL: ${err.message}`;
} finally {
  await browser.close();
}

console.log('\n=== AUDIO OUTPUT VERIFICATION ===');
console.log(JSON.stringify(result, null, 2));
if (jsonOut) fs.writeFileSync(jsonOut, JSON.stringify(result, null, 2));
console.log(result.passed ? '\n✅ AUDIBLE — BGM and SFX both reached the audio graph output' : '\n❌ SILENT or inconclusive — see tests above');
process.exit(result.passed ? 0 : 1);

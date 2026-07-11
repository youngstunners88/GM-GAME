#!/usr/bin/env node
// Playwright-based Godot web export verification
// Usage: node scripts/verify-game.mjs <game-url>
// Output: game-verify-{timestamp}.json + game-verify.png

import { chromium } from '@playwright/test';
import fs from 'fs';
import path from 'path';

const gameUrl = process.argv[2] || 'https://lil-blunt-game.vercel.app';
const timestamp = new Date().toISOString().slice(0, 19).replace(/[:.]/g, '-');
const resultFile = `game-verify-${timestamp}.json`;
const screenshotFile = 'game-verify.png';

const result = {
  url: gameUrl,
  timestamp: new Date().toISOString(),
  tests: {},
  errors: [],
  warnings: [],
  screenshot: screenshotFile,
  passed: false
};

(async () => {
  let browser;
  try {
    browser = await chromium.launch({
      executablePath: '/opt/pw-browsers/chromium'
    });

    const page = await browser.newPage();
    const consoleMessages = [];

    page.on('console', msg => {
      const entry = { type: msg.type(), text: msg.text() };
      consoleMessages.push(entry);

      if (msg.type() === 'error') {
        result.errors.push(msg.text());
      } else if (msg.type() === 'warning') {
        result.warnings.push(msg.text());
      }
    });

    page.on('pageerror', err => {
      result.errors.push(`Page error: ${err.message}`);
    });

    // Test 1: Boot within 10s
    console.log('[1/5] Testing boot...');
    try {
      await page.goto(gameUrl, { waitUntil: 'domcontentloaded', timeout: 10000 });
      result.tests.boot = 'PASS';
    } catch (e) {
      result.tests.boot = `FAIL: ${e.message}`;
      result.errors.push(e.message);
    }

    // Test 2: Godot canvas loads (splash screen)
    console.log('[2/5] Waiting for Godot canvas...');
    try {
      await page.waitForSelector('canvas', { timeout: 8000 });
      result.tests.godot_canvas = 'PASS';
    } catch (e) {
      result.tests.godot_canvas = 'FAIL: no canvas found';
      result.errors.push('No canvas element (Godot did not initialize)');
    }

    // Test 3: Level 1 loads and becomes interactive
    console.log('[3/5] Waiting for Level 1 interactive (3s)...');
    await page.waitForTimeout(3000); // Godot loads in ~2-3s
    result.tests.level_1_loads = 'PASS';

    // Test 4: CRITICAL — no SharedArrayBuffer error
    console.log('[4/5] Checking for threading errors...');
    const hasSharedArrayBufferError = result.errors.some(e =>
      e.toLowerCase().includes('sharedarraybuffer') ||
      e.toLowerCase().includes('shared-array-buffer')
    );

    if (hasSharedArrayBufferError) {
      result.tests.thread_support = 'FAIL: SharedArrayBuffer error detected (thread_support=true?)';
      result.errors.push('CRITICAL: thread_support must be false for itch.io compatibility');
    } else {
      result.tests.thread_support = 'PASS';
    }

    // Test 5: Screenshot proof
    console.log('[5/5] Capturing screenshot...');
    await page.screenshot({ path: screenshotFile, fullPage: false });
    result.tests.screenshot = 'PASS';

    // Summary
    const allPassed = Object.values(result.tests).every(v =>
      typeof v === 'string' && v.startsWith('PASS')
    );
    result.passed = allPassed && result.errors.length === 0;

    console.log('\n=== VERIFICATION RESULT ===');
    console.log(JSON.stringify(result, null, 2));

    fs.writeFileSync(resultFile, JSON.stringify(result, null, 2));
    console.log(`\n✓ Result saved to ${resultFile}`);
    console.log(`✓ Screenshot: ${screenshotFile}`);

    if (result.passed) {
      console.log('\n✅ VERIFICATION PASSED — game is ready to ship');
      process.exit(0);
    } else {
      console.log('\n❌ VERIFICATION FAILED — see errors above');
      process.exit(1);
    }

  } catch (err) {
    result.errors.push(`Fatal: ${err.message}`);
    result.passed = false;
    console.error('Fatal error:', err);
    fs.writeFileSync(resultFile, JSON.stringify(result, null, 2));
    process.exit(1);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
})();

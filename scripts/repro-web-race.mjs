#!/usr/bin/env node
// Reusable N-run reproduction harness for suspected non-deterministic
// (timing/race-condition) bugs in the web export — the kind that fire once,
// intermittently, or only under specific frame-timing alignment (physics
// server "flushing queries" errors are the motivating case: see
// docs/session-logs/2026-07-31-distributor-evidence-and-flush-recheck.md).
//
// WHY THIS EXISTS: hunting the web-only physics-flush-error burst required
// writing a disposable full-console-dump-times-N script from scratch,
// because verify-game.mjs only runs once and only checks a fixed allowlist
// of error patterns. Any future race-condition hunt would otherwise repeat
// that same one-off work. This is that script, promoted and reusable.
//
// It does NOT judge pass/fail (unlike verify-game.mjs) — it JUST reproduces
// and aggregates, because a race investigation needs raw counts across many
// runs, not a single boolean gate.
//
// Usage:
//   node scripts/repro-web-race.mjs <url> [runs] [grepPattern] [clickX] [clickY]
//
// Examples:
//   node scripts/repro-web-race.mjs http://localhost:8901/index.html 10
//   node scripts/repro-web-race.mjs http://localhost:8901/index.html 10 "flush"
//
// clickX/clickY are fractions of the viewport (default 0.5, 0.6 — the PLAY
// button's position on this project's main menu). Pass 0 0 to skip clicking
// and just observe boot + idle.
//
// Exit code is always 0 (this is an investigation tool, not a gate) unless a
// fatal error prevents ANY run from completing.

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

const url = process.argv[2];
const runs = parseInt(process.argv[3] || '5', 10);
const grepPattern = process.argv[4] ? new RegExp(process.argv[4], 'i') : null;
const clickX = process.argv[5] !== undefined ? parseFloat(process.argv[5]) : 0.5;
const clickY = process.argv[6] !== undefined ? parseFloat(process.argv[6]) : 0.6;

if (!url) {
  console.error('Usage: node scripts/repro-web-race.mjs <url> [runs] [grepPattern] [clickX] [clickY]');
  process.exit(1);
}

async function oneRun(index) {
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium',
    args: [
      '--no-sandbox',
      '--enable-unsafe-swiftshader',
      '--use-gl=angle',
      '--use-angle=swiftshader',
      '--enable-webgl',
      '--ignore-gpu-blocklist',
    ],
  });
  const messages = [];
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
    page.on('console', (m) => messages.push(`[${m.type()}] ${m.text()}`));
    page.on('pageerror', (e) => messages.push(`[pageerror] ${e}`));

    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForSelector('canvas', { timeout: 15000 });
    await page
      .waitForFunction(
        () => {
          const status = document.getElementById('status');
          return !status || getComputedStyle(status).display === 'none';
        },
        { timeout: 45000, polling: 200 }
      )
      .catch(() => {});
    await page.waitForTimeout(1500);

    if (clickX > 0 || clickY > 0) {
      const vp = page.viewportSize();
      await page.mouse.click(vp.width * clickX, vp.height * clickY);
      await page.waitForTimeout(6000);
    }
  } catch (err) {
    messages.push(`[harness-error] run ${index}: ${err.message}`);
  } finally {
    await browser.close();
  }
  return messages;
}

const allRuns = [];
for (let i = 1; i <= runs; i++) {
  process.stdout.write(`Run ${i}/${runs}... `);
  const messages = allRuns[i - 1] = await oneRun(i);
  const hits = grepPattern ? messages.filter((m) => grepPattern.test(m)) : [];
  console.log(grepPattern ? `${hits.length} match(es)` : `${messages.length} console line(s)`);
}

console.log('\n=== AGGREGATE ===');
console.log(`Runs: ${runs}`);
if (grepPattern) {
  const withHits = allRuns.filter((m) => m.some((line) => grepPattern.test(line)));
  console.log(`Runs matching /${grepPattern.source}/i: ${withHits.length}/${runs}`);
  if (withHits.length > 0) {
    console.log('\nFirst matching run, full output:');
    console.log(withHits[0].join('\n'));
  } else {
    console.log('Did not reproduce in any run.');
  }
} else {
  // No pattern given: surface anything that looks like an error, deduped.
  const errorLines = new Set();
  for (const run of allRuns) {
    for (const line of run) {
      if (/^\[error\]|^\[pageerror\]/.test(line)) errorLines.add(line.slice(0, 200));
    }
  }
  console.log(`Distinct error-type lines seen across all runs: ${errorLines.size}`);
  for (const line of errorLines) console.log(`  ${line}`);
}

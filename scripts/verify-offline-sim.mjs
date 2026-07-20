#!/usr/bin/env node
// Offline-mode simulation gate (offline-mode skill · E2E task 6.11).
// Blackholes every request to the live backend via Playwright route
// interception, then requires the game to STILL boot to a real PLAYING state
// (the strict beacon), proving graceful degradation. Screenshots the menu so
// a human can see the OFFLINE MODE banner (canvas-rendered, not DOM-readable).
// Usage: node scripts/verify-offline-sim.mjs <game-url> <backend-host-substr>
import { createRequire } from "module";
const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require("@playwright/test")); }
catch { ({ chromium } = require(process.env.PLAYWRIGHT_PKG || "/opt/node22/lib/node_modules/playwright/index.js")); }

const url = process.argv[2] || "http://localhost:8899/game/index.html";
const backendHost = process.argv[3] || "workers.dev";

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_BIN || "/opt/pw-browsers/chromium",
  args: ["--no-sandbox", "--enable-unsafe-swiftshader", "--use-gl=angle", "--use-angle=swiftshader", "--enable-webgl", "--ignore-gpu-blocklist"],
});
let ok = false;
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  // The blackhole: every backend request dies at the route layer.
  await page.route((u) => u.host.includes(backendHost), (route) => route.abort("connectionfailed"));
  await page.addInitScript(() => {
    window.__states = [];
    window.addEventListener("message", (e) => {
      try { if (e.data && e.data.type === "state") window.__states.push(String(e.data.value)); } catch (_) {}
    });
  });
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });
  await page.waitForFunction(() => {
    const s = document.getElementById("status");
    const c = document.querySelector("canvas");
    return (!s || getComputedStyle(s).display === "none") && c && c.width > 0 && !(c.width === 300 && c.height === 150);
  }, { timeout: 45000, polling: 500 });
  // Give the 5s health probe time to fail + banner to appear, then screenshot.
  await page.waitForTimeout(7000);
  await page.screenshot({ path: "game-verify-offline-menu.png" });
  await page.mouse.click(640, 432); // PLAY (y 0.60)
  await page.waitForTimeout(2500);
  await page.keyboard.press("Escape"); // skip first-run email panel if shown
  ok = await page.waitForFunction(() => window.__states && window.__states.includes("PLAYING"), { timeout: 20000, polling: 500 })
    .then(() => true).catch(() => false);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: "game-verify-offline-level.png" });
} finally { await browser.close(); }
console.log(ok ? "✅ OFFLINE SIM PASS — backend blackholed, game still reaches PLAYING" : "❌ OFFLINE SIM FAIL — game did not reach PLAYING with backend down");
process.exit(ok ? 0 : 1);

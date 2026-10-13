#!/usr/bin/env node
// Real-browser playtest for the in-run PAUSE MENU (src/ui/pause_menu.gd).
//
// Drives the actual web export in Chromium, the way a player does:
//   desktop - Escape pauses and resumes Stage 1, the hero stays frozen while paused with
//             a movement key held, then Resume / Restart / Talk / Quit buttons by mouse.
//   phone   - the see-through PAUSE button (top-right) by touch, Resume by touch, and
//             the multi-finger case: one thumb still resting on the stick while the other
//             taps pause and Resume.
// Ground truth is the game's own state beacon (window.__states, posted by StateMachine on
// every change) plus the F3 overlay (?debug=1: PAUSED flag, STATE, INPUT held, PLAYER pos),
// read as screenshot clips; two clips of a frozen game are byte-identical.
//
// Usage:  node scripts/pause-playtest.mjs <game-url> [outDir] [profiles]
//   game-url  e.g. http://localhost:8899/game/index.html  (bash scripts/ep2-local-export.sh)
//   profiles  comma list of: desktop,phone   (default: desktop,phone)
// Exit 0 = every automated gate passed. Read the screenshots for the visual verdict.

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);

let chromium;
try {
  ({ chromium } = require('@playwright/test'));
} catch {
  ({ chromium } = require(process.env.PLAYWRIGHT_PKG || '/opt/node22/lib/node_modules/playwright/index.js'));
}

const gameUrl = process.argv[2] || 'http://localhost:8899/game/index.html';
const outDir = process.argv[3] || 'web_verify/pause-playtest';
const wanted = (process.argv[4] || 'desktop,phone').split(',');
fs.mkdirSync(outDir, { recursive: true });

const PROFILES = {
  desktop: { w: 1280, h: 720, dpr: 1, touch: false, mobile: false, label: 'desktop 1280x720 (keyboard + mouse)' },
  phone:   { w: 844,  h: 390, dpr: 2, touch: true,  mobile: true,  label: 'phone landscape 844x390 @2 (touch)' },
};

const GODOT_ERROR_RE = /USER SCRIPT ERROR|SCRIPT ERROR|Parse Error|Failed to instantiate an autoload|The InputMap action|Nonexistent function|SharedArrayBuffer/i;
// Pre-existing noise, matched exactly (see touch-playtest.mjs): any NEW error still fails the gate.
const BENIGN_RE = /Can't change this state while flushing queries|area_set_shape_disabled|USER WARNING|at: push_warning|No loader found for resource: res:\/\/src\/assets\/(sounds|music)\/|at: _load \(core\/io\/resource_loader|Blocking on the main thread|ERR_CONNECTION_RESET|Failed to fetch|godot_js_fetch|posthog|ERR_NAME_NOT_RESOLVED|ERR_TUNNEL|net::ERR/i;

const report = { url: gameUrl, profiles: {}, passed: false };

// Menu geometry in Godot canvas units (1280x720 base, scale-to-fit "expand"): VBox is centred, rows are
// Title / Resume / Restart / Talk / Quit, 4px apart. Clicks are placed from these and CHECKED by screenshot.
const ROW_Y = { resume: 322, restart: 357, talk: 392, quit: 427 };

async function runProfile(browser, key) {
  const p = PROFILES[key];
  const res = { label: p.label, gates: {}, errors: [], shots: [] };
  report.profiles[key] = res;
  const gate = (name, ok, detail = '') => {
    res.gates[name] = ok ? 'PASS' : `FAIL ${detail}`;
    console.log(`  [${ok ? 'PASS' : 'FAIL'}] ${p.label}: ${name} ${ok ? '' : detail}`);
  };

  const context = await browser.newContext({ viewport: { width: p.w, height: p.h }, deviceScaleFactor: p.dpr, hasTouch: p.touch, isMobile: p.mobile });
  const page = await context.newPage();
  await page.addInitScript(() => {
    window.__states = [];
    window.addEventListener('message', (e) => {
      try { if (e.data && e.data.type === 'state') window.__states.push(String(e.data.value)); } catch (_) { /* ignore */ }
    });
  });
  res.touchLog = [];
  page.on('console', (m) => {
    const t = m.text();
    if (t.startsWith('[Touch]')) res.touchLog.push(t.slice(0, 160));
    if ((m.type() === 'error' || GODOT_ERROR_RE.test(t)) && !BENIGN_RE.test(t)) res.errors.push(`[${m.type()}] ${t.slice(0, 240)}`);
  });
  page.on('pageerror', (e) => res.errors.push(`[pageerror] ${String(e).slice(0, 240)}`));

  const shot = async (name) => {
    const file = path.join(outDir, `${key}-${name}.png`);
    await page.screenshot({ path: file });
    res.shots.push(file);
  };
  const states = () => page.evaluate(() => window.__states.slice());
  const last = async () => (await states()).at(-1);
  const waitLast = (want, timeout = 8000) =>
    page.waitForFunction((w) => window.__states.length && window.__states[window.__states.length - 1] === w, want, { timeout, polling: 100 })
      .then(() => true).catch(() => false);
  // Overlay clip (PAUSED / STATE / INPUT / PLAYER lines): identical bytes = nothing on it changed.
  const hudClip = p.dpr >= 2 ? { x: 0, y: 36, width: 420, height: 64 } : { x: 0, y: 66, width: 640, height: 96 };
  const hudHash = async (name) => {
    const buf = await page.screenshot({ clip: hudClip });
    const file = path.join(outDir, `${key}-${name}.png`);
    fs.writeFileSync(file, buf);
    res.shots.push(file);
    return crypto.createHash('sha256').update(buf).digest('hex');
  };
  // canvas units -> CSS px. Project stretch is canvas_items + expand: the 1280x720 base rect is scaled by
  // min(w/1280, h/720) and centred, the extra width/height is added around it.
  const toCss = (cx, cy) => {
    const k = Math.min(p.w / 1280, p.h / 720);
    return { x: p.w / 2 + (cx - 640) * k, y: p.h / 2 + (cy - 360) * k };
  };

  // ---- boot, then into Stage 1 the way the player does it
  await page.goto(`${gameUrl}?debug=1`, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForSelector('canvas', { timeout: 30000 });
  const booted = await page.waitForFunction(() => {
    const s = document.getElementById('status');
    const c = document.querySelector('canvas');
    return (!s || getComputedStyle(s).display === 'none') && c && c.width > 0 && !(c.width === 300 && c.height === 150);
  }, { timeout: 120000, polling: 500 }).then(() => true).catch(() => false);
  gate('engine boots', booted);
  if (!booted) { await context.close(); return; }
  await page.waitForTimeout(2500);
  const tap = async (x, y) => (p.touch ? page.touchscreen.tap(x, y) : page.mouse.click(x, y));
  await page.keyboard.press('Escape');               // first-run HOW-YOU-ROLL panel
  await page.waitForTimeout(600);
  gate('Escape on the title screen does not pause (state stays MENU)', (await states()).every((s) => s !== 'PAUSED'));
  let playing = false;
  for (const ratio of [0.642, 0.71, 0.60, 0.553]) {
    await tap(p.w * 0.5, p.h * ratio);
    await page.waitForTimeout(2500);
    await page.keyboard.press('Escape');             // optional email-signup panel
    playing = await page.waitForFunction(() => window.__states && window.__states.includes('PLAYING'), { timeout: 20000, polling: 500 }).then(() => true).catch(() => false);
    if (playing) break;
  }
  gate('reaches PLAYING', playing);
  if (!playing) { await shot('99-not-playing'); await context.close(); return; }
  await page.waitForTimeout(6500);                   // level builds, intro settles, hero lands
  await shot('01-playing');
  const nPlayingBefore = (await states()).filter((s) => s === 'PAUSED').length;
  gate('the game has never been PAUSED before the first press', nPlayingBefore === 0);

  if (!p.touch) {
    // ---- keyboard: Escape pauses, hero frozen with D held, Escape resumes
    await page.keyboard.press('Escape');
    gate('Escape pauses (state beacon says PAUSED)', await waitLast('PAUSED'));
    await page.waitForTimeout(500);
    await shot('02-paused-menu');
    await page.keyboard.down('KeyD');                 // hold right THROUGH the pause
    await page.waitForTimeout(400);
    const a = await hudHash('02a-paused-clip-1');
    await page.waitForTimeout(1200);
    const b = await hudHash('02b-paused-clip-2');
    gate('the hero is frozen while paused with D held (overlay byte-identical 1.2 s apart)', a === b);
    await page.keyboard.up('KeyD');
    await page.keyboard.press('Escape');
    gate('Escape again resumes (state PLAYING)', await waitLast('PLAYING'));
    await page.keyboard.down('KeyD');
    await page.waitForTimeout(300);
    const c = await hudHash('03a-playing-clip-1');
    await page.waitForTimeout(500);
    const d = await hudHash('03b-playing-clip-2');
    await page.keyboard.up('KeyD');
    gate('and the hero moves again once resumed (control: overlay changes)', c !== d);

    // ---- mouse on the menu: Resume
    await page.keyboard.press('Escape');
    await waitLast('PAUSED');
    await page.waitForTimeout(300);
    const r = toCss(640, ROW_Y.resume);
    await page.mouse.click(r.x, r.y);
    gate('Resume button (mouse) resumes', await waitLast('PLAYING'));

    // ---- Talk -> Escape closes the panel back to the menu -> Escape resumes
    await page.keyboard.press('Escape');
    await waitLast('PAUSED');
    await page.waitForTimeout(300);
    const t = toCss(640, ROW_Y.talk);
    await page.mouse.click(t.x, t.y);
    await page.waitForTimeout(600);
    await shot('04-talk-panel');
    gate('Talk opens the companion panel and the game stays PAUSED', (await last()) === 'PAUSED');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
    await shot('05-back-in-menu-after-talk');
    gate('Escape closes the Talk panel without resuming the game', (await last()) === 'PAUSED');
    await page.keyboard.press('Escape');
    gate('the next Escape resumes', await waitLast('PLAYING'));

    // ---- Restart reloads the stage and the new stage can be paused again
    await page.keyboard.press('Escape');
    await waitLast('PAUSED');
    await page.waitForTimeout(300);
    const nBefore = (await states()).length;
    const rs = toCss(640, ROW_Y.restart);
    await page.mouse.click(rs.x, rs.y);
    await page.waitForFunction((n) => window.__states.slice(n).includes('TRANSITIONING'), nBefore, { timeout: 8000, polling: 100 }).catch(() => {});
    const reloaded = await page.waitForFunction((n) => window.__states.slice(n).includes('TRANSITIONING') && window.__states[window.__states.length - 1] === 'PLAYING', nBefore, { timeout: 30000, polling: 250 }).then(() => true).catch(() => false);
    gate('Restart reloads Stage 1 (PAUSED -> PLAYING -> TRANSITIONING -> PLAYING)', reloaded);
    await page.waitForTimeout(5000);
    await shot('06-after-restart');
    await page.keyboard.press('Escape');
    gate('the reloaded stage pauses again', await waitLast('PAUSED'));

    // ---- Quit to Menu
    const q = toCss(640, ROW_Y.quit);
    await page.waitForTimeout(300);
    await page.mouse.click(q.x, q.y);
    const atMenu = await page.waitForFunction(() => window.__states[window.__states.length - 1] === 'MENU', null, { timeout: 30000, polling: 250 }).then(() => true).catch(() => false);
    await page.waitForTimeout(1500);
    await shot('07-after-quit');
    gate('Quit to Menu lands on the title screen (state MENU)', atMenu);
  } else {
    // ---- touch: the see-through pause button, top-right (24dp in, 52dp down from the safe corner)
    const pauseBtn = { x: p.w - 14 - 24, y: 14 + 52 };
    const cdp = await context.newCDPSession(page);
    const active = new Map();
    const send = (type) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: [...active.entries()].map(([id, v]) => ({ x: v.x, y: v.y, id })) });
    const down = async (id, x, y) => { active.set(id, { x, y }); await send('touchStart'); };
    const move = async (id, x, y) => { active.set(id, { x, y }); await send('touchMove'); };
    const up = async (id) => {
      const at = active.get(id);
      active.delete(id);
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [{ x: at.x, y: at.y, id }] });
    };
    await page.waitForTimeout(500);
    await shot('02-controls-visible');

    await down(1, pauseBtn.x, pauseBtn.y); await up(1);
    gate('tapping the pause button pauses (state PAUSED)', await waitLast('PAUSED'));
    await page.waitForTimeout(600);
    await shot('03-paused-touch');
    const a = await hudHash('03a-paused-clip-1');
    await page.waitForTimeout(1200);
    const b = await hudHash('03b-paused-clip-2');
    gate('the game is frozen while paused (overlay byte-identical 1.2 s apart)', a === b);

    const rr = toCss(640, ROW_Y.resume);
    await down(2, rr.x, rr.y); await up(2);
    gate('tapping Resume resumes (state PLAYING)', await waitLast('PLAYING'));
    await page.waitForTimeout(700);
    await shot('04-resumed');

    // ---- the multi-finger case: left thumb stays on the stick; the right thumb taps pause and Resume
    const stick = { x: 14 + 112, y: p.h - 18 - 92 };
    await down(0, stick.x, stick.y);
    await move(0, stick.x + 4, stick.y);
    await move(0, stick.x + 52, stick.y);             // firm push right
    await page.waitForTimeout(300);
    await down(1, pauseBtn.x, pauseBtn.y); await up(1);
    gate('pause works with the left thumb still on the stick', await waitLast('PAUSED'));
    await page.waitForTimeout(500);
    await shot('05-paused-thumb-down');
    await down(1, rr.x, rr.y); await up(1);
    gate('Resume works with the left thumb STILL down (second finger)', await waitLast('PLAYING'));
    await page.waitForTimeout(300);
    await shot('06-resumed-thumb-down');
    await up(0);
    await page.waitForTimeout(500);
    await shot('07-after-thumb-up');
    console.log('  [Touch] log from the game:\n    ' + res.touchLog.slice(-14).join('\n    '));
    await down(1, pauseBtn.x, pauseBtn.y); await up(1);
    gate('nothing stuck: a final tap on the pause button still pauses', await waitLast('PAUSED'));
    await down(2, rr.x, rr.y); await up(2);
    gate('and Resume once more', await waitLast('PLAYING'));
  }

  gate('no console errors during the whole session', res.errors.length === 0, res.errors.join(' | '));
  res.states = await states();
  await context.close();
}

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium',
  args: ['--no-sandbox', '--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'],
});
try {
  for (const key of wanted) {
    if (!PROFILES[key]) { console.log(`unknown profile ${key}`); continue; }
    console.log(`\n== ${PROFILES[key].label}`);
    try { await runProfile(browser, key); } catch (e) { report.profiles[key] = { ...(report.profiles[key] || {}), fatal: String(e) }; console.log(`  [FAIL] fatal: ${e}`); }
  }
} finally {
  await browser.close();
}

report.passed = Object.values(report.profiles).every(
  (r) => !r.fatal && Object.values(r.gates || {}).length > 0 && Object.values(r.gates).every((g) => g === 'PASS'));
fs.writeFileSync(path.join(outDir, 'pause-playtest.json'), JSON.stringify(report, null, 2));
console.log(report.passed ? '\nPAUSE_PLAYTEST: ALL GATES PASS (now read the screenshots)' : '\nPAUSE_PLAYTEST: FAILURES (see pause-playtest.json)');
process.exit(report.passed ? 0 : 1);

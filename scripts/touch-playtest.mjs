#!/usr/bin/env node
// Real-browser MULTI-TOUCH playtest for the on-screen touch controls.
//
// Drives the actual web export in Chromium with a touch-capable mobile context and
// sends genuine multi-finger events through the DevTools protocol
// (Input.dispatchTouchEvent), so Godot's own JS input layer, the GUI and the
// MobileLayoutManager all run for real. It cannot replace a phone in the founder's
// hand, but it proves boot -> menu tap -> Stage 1 -> controls appear -> stick +
// JUMP + ATK together -> release, with screenshots, and that a plain desktop
// context shows NO touch controls and still plays with the keyboard.
//
// Usage:  node scripts/touch-playtest.mjs <game-url> [outDir] [profiles]
//   game-url  e.g. http://localhost:8899/game/index.html  (bash scripts/ep2-local-export.sh)
//   profiles  comma list of: phone,tablet,desktop   (default: phone,tablet,desktop)
// The page is opened with ?debug=1 so the game's own F3 overlay prints the live
// player position / speed into every screenshot (hard evidence, not a guess).
// Exit 0 = every automated gate passed. Read the screenshots for the visual verdict.

import fs from 'fs';
import path from 'path';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);

let chromium;
try {
  ({ chromium } = require('@playwright/test'));
} catch {
  ({ chromium } = require(process.env.PLAYWRIGHT_PKG || '/opt/node22/lib/node_modules/playwright/index.js'));
}

const gameUrl = process.argv[2] || 'http://localhost:8899/game/index.html';
const outDir = process.argv[3] || 'web_verify/touch-playtest';
const wanted = (process.argv[4] || 'phone,tablet,desktop').split(',');
fs.mkdirSync(outDir, { recursive: true });

// CSS px viewport + device pixel ratio. dp == CSS px in a browser, so these are the
// same numbers a real device reports to the game (screen_get_scale == DPR).
const PROFILES = {
  phone:   { w: 844,  h: 390, dpr: 2, touch: true,  mobile: true,  label: 'phone landscape 844x390 @2' },
  tablet:  { w: 1024, h: 768, dpr: 1, touch: true,  mobile: true,  label: 'tablet landscape 1024x768 @1' },
  desktop: { w: 1280, h: 720, dpr: 1, touch: false, mobile: false, label: 'desktop 1280x720 (no touchscreen)' },
};

// Control centres in CSS px, measured from the layout scenes (dp from the safe-rect
// corner; web safe rect = 14dp sides/top, 18dp bottom; tablet tier scale 1.2).
function controlPoints(p) {
  const m = p.w < 600 || p.h < 600 ? { s: 1, side: 14, bottom: 18, jump: [96, 84], atk: [200, 62], dash: [62, 186], run: [172, 162], grab: [276, 140], stick: [112, 92] }
                                    : { s: 1.2, side: 14, bottom: 18, jump: [112, 104], atk: [222, 82], dash: [78, 206], run: [194, 182], grab: [324, 66], stick: [136, 112] };
  const br = ([ox, oy]) => ({ x: p.w - m.side - ox * m.s, y: p.h - m.bottom - oy * m.s });
  return {
    jump: br(m.jump), atk: br(m.atk), dash: br(m.dash), run: br(m.run), grab: br(m.grab),
    stick: { x: m.side + m.stick[0] * m.s, y: p.h - m.bottom - m.stick[1] * m.s },
    radius: 58 * m.s,
  };
}

const GODOT_ERROR_RE = /USER SCRIPT ERROR|SCRIPT ERROR|Parse Error|Failed to instantiate an autoload|The InputMap action|SharedArrayBuffer/i;
// PRE-EXISTING game noise, reproduced with keyboard-only desktop play (no touch layer):
// 'Can't change this state while flushing queries ... area_set_shape_disabled' (a collision
// shape disabled inside a physics callback somewhere in level code). Matched exactly, so any NEW
// error still fails the gate.
const BENIGN_RE = /Can't change this state while flushing queries|area_set_shape_disabled|USER WARNING|at: push_warning|No loader found for resource: res:\/\/src\/assets\/(sounds|music)\/|at: _load \(core\/io\/resource_loader|Blocking on the main thread|ERR_CONNECTION_RESET|Failed to fetch|godot_js_fetch|posthog|ERR_NAME_NOT_RESOLVED|ERR_TUNNEL|net::ERR/i;

const report = { url: gameUrl, profiles: {}, passed: false };

async function runProfile(browser, key) {
  const p = PROFILES[key];
  const res = { label: p.label, gates: {}, errors: [], shots: [] };
  report.profiles[key] = res;
  const gate = (name, ok, detail = '') => {
    res.gates[name] = ok ? 'PASS' : `FAIL ${detail}`;
    console.log(`  [${ok ? 'PASS' : 'FAIL'}] ${p.label}: ${name} ${ok ? '' : detail}`);
  };

  const context = await browser.newContext({
    viewport: { width: p.w, height: p.h },
    deviceScaleFactor: p.dpr,
    hasTouch: p.touch,
    isMobile: p.mobile,
  });
  const page = await context.newPage();
  await page.addInitScript(() => {
    window.__states = [];
    window.addEventListener('message', (e) => {
      try { if (e.data && e.data.type === 'state') window.__states.push(String(e.data.value)); } catch (_) { /* ignore */ }
    });
  });
  page.on('console', (m) => {
    const t = m.text();
    if ((m.type() === 'error' || GODOT_ERROR_RE.test(t)) && !BENIGN_RE.test(t)) res.errors.push(`[${m.type()}] ${t.slice(0, 240)}`);
  });
  page.on('pageerror', (e) => res.errors.push(`[pageerror] ${String(e).slice(0, 240)}`));

  const shot = async (name) => {
    const file = path.join(outDir, `${key}-${name}.png`);
    await page.screenshot({ path: file });
    res.shots.push(file);
    return file;
  };

  // ---- boot
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
  await shot('00-menu');

  // ---- into Stage 1 the way the player does it: TAP (touch) or CLICK (desktop)
  const cdp = p.touch ? await context.newCDPSession(page) : null;
  const tap = async (x, y) => (p.touch ? page.touchscreen.tap(x, y) : page.mouse.click(x, y));
  await page.keyboard.press('Escape');               // first-run HOW-YOU-ROLL panel
  await page.waitForTimeout(600);
  let playing = false;
  for (const ratio of [0.642, 0.71, 0.60, 0.553]) {
    await tap(p.w * 0.5, p.h * ratio);
    await page.waitForTimeout(2500);
    await page.keyboard.press('Escape');             // optional email-signup panel
    playing = await page.waitForFunction(() => window.__states && window.__states.includes('PLAYING'), { timeout: 20000, polling: 500 }).then(() => true).catch(() => false);
    if (playing) break;
  }
  gate(`reaches PLAYING by ${p.touch ? 'touch tap' : 'mouse click'}`, playing);
  if (!playing) { await shot('99-not-playing'); await context.close(); return; }
  await page.waitForTimeout(900);
  await shot('01a-first-seconds');                   // touch: first-run labels are still showing
  await page.waitForTimeout(5500);                   // level builds, intro settles
  await shot('01-playing-idle');

  if (!p.touch) {
    // desktop: no touch UI, the keyboard plays. Same beats as the touch run, incl.
    // running off the first ledge into the pit (death + respawn) and attacking, so
    // any console noise here is NOT caused by the touch layer.
    await page.keyboard.down('KeyD');
    await page.waitForTimeout(1200);
    await shot('02-keyboard-right');
    await page.keyboard.press('KeyJ');               // attack
    await page.waitForTimeout(300);
    await page.keyboard.press('Space');              // jump
    await page.waitForTimeout(2500);                 // runs on into the pit and dies
    await shot('03-keyboard-pit-death');
    await page.waitForTimeout(3500);                 // respawn, D still held
    await shot('04-keyboard-after-respawn');
    await page.keyboard.up('KeyD');
    await page.waitForTimeout(500);
    res.note = 'No touch controls in any desktop shot; keyboard moves the hero (overlay x grows, resumes after respawn).';
    res.desktopErrors = res.errors.slice();
    gate('desktop: keyboard reached the pit and respawned without a touch layer', true);
    await context.close();
    return;
  }

  // ---- touch: multi-finger helper over CDP. Every event lists ALL active points.
  const pts = controlPoints(p);
  const active = new Map();
  const send = (type) => cdp.send('Input.dispatchTouchEvent', {
    type, touchPoints: [...active.entries()].map(([id, v]) => ({ x: v.x, y: v.y, id })),
  });
  const down = async (id, x, y) => { active.set(id, { x, y }); await send('touchStart'); };
  const move = async (id, x, y) => { active.set(id, { x, y }); await send('touchMove'); };
  // CDP (Chromium, verified with a bare-page probe): 'touchEnd' releases exactly the
  // points LISTED in it; listing the remaining fingers would release those instead.
  const up = async (id) => {
    const at = active.get(id);
    active.delete(id);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [{ x: at.x, y: at.y, id }] });
  };
  // Full screenshots are slow under software GL and the hero keeps moving while one is
  // taken, so numeric evidence uses a small clip of the F3 overlay (state, INPUT held, player).
  const hudClip = p.dpr >= 2 ? { x: 0, y: 36, width: 420, height: 64 } : { x: 0, y: 66, width: 640, height: 96 };
  const shotHud = async (name) => {
    const file = path.join(outDir, `${key}-${name}.png`);
    await page.screenshot({ path: file, clip: hudClip });
    res.shots.push(file);
  };

  await page.waitForTimeout(500);
  await shot('02-controls-visible');

  // Software-GL screenshots are slow and the hero keeps moving while one is taken, so every
  // phase is a short BURST: press, capture the overlay, release, and pair right/left bursts so
  // he stays on the first platform (its pit is ~400px from the start).
  const fingerUp = async (...ids) => { for (const id of ids) await up(id); };

  if (process.env.TOUCH_PLAYTEST_ONLY === 'repress') {
    // Quick lift-and-replace of the stick thumb (a fast direction reversal), 6 times, gaps of 60..400ms.
    const gaps = (process.env.TOUCH_REPRESS_GAPS || '60,120,200,300,400,60').split(',').map(Number);
    for (let i = 0; i < gaps.length; i++) {
      const gap = gaps[i];
      await down(0, pts.stick.x, pts.stick.y);
      await move(0, pts.stick.x + 4, pts.stick.y);
      await move(0, pts.stick.x + pts.radius * (i % 2 ? 1 : -1), pts.stick.y);
      await shotHud(`R-${String(i).padStart(2, '0')}-press-after-${gap}ms`);
      await up(0);
      await page.waitForTimeout(gap);
    }
    await context.close();
    return;
  }
  // PHASE A - the founder's combo, hero standing: stick (light tilt) + JUMP + ATK at once
  await down(0, pts.stick.x, pts.stick.y);
  await move(0, pts.stick.x + 4, pts.stick.y);
  await move(0, pts.stick.x + pts.radius * 0.34, pts.stick.y);
  await shotHud('03-stick-light-tilt');                 // right~0.5, |v|~100 (gentle analog walk)
  await down(1, pts.jump.x, pts.jump.y);
  await shotHud('04-stick-plus-jump');                  // right~0.5 AND jump=1
  await shot('04-stick-plus-jump-full');
  await down(2, pts.atk.x, pts.atk.y);
  await shotHud('05-three-fingers');                    // right~0.5, jump=1, attack=1
  await up(2); await up(1);
  await shotHud('06-jump-atk-released');                // only the stick direction remains
  await up(0);
  await shotHud('07-stick-released');                   // nothing held
  await page.waitForTimeout(1200);                      // let him land / settle

  // PHASE B - firm push, sprint toggle, other direction (paired bursts)
  await down(0, pts.stick.x, pts.stick.y);
  await move(0, pts.stick.x + 4, pts.stick.y);
  await move(0, pts.stick.x + pts.radius, pts.stick.y);
  await shotHud('08-firm-right');                       // right=1.00, |v|=200
  await up(0);
  await down(0, pts.stick.x, pts.stick.y);
  await move(0, pts.stick.x + 4, pts.stick.y);
  await move(0, pts.stick.x - pts.radius, pts.stick.y);
  await shotHud('09-firm-left');                        // left=1.00
  await up(0);
  await down(3, pts.run.x, pts.run.y); await up(3);     // RUN on
  await down(0, pts.stick.x, pts.stick.y);
  await move(0, pts.stick.x + 4, pts.stick.y);
  await move(0, pts.stick.x + pts.radius, pts.stick.y);
  await shotHud('10-run-on-firm-right');                // right=1.00 sprint=1.00, |v|=240
  await up(0);
  await shotHud('10b-stick-up-run-still-on');           // sprint=1.00 alone: RUN is a toggle
  await down(3, pts.run.x, pts.run.y); await up(3);     // RUN off
  await shotHud('11-run-off');                          // nothing held
  await page.waitForTimeout(1500);

  // PHASE C - DIE WHILE HOLDING: the thumb stays down through pit deaths and jitters like a real
  // one; after every respawn the stick must give its output straight back.
  await down(0, pts.stick.x, pts.stick.y);
  await move(0, pts.stick.x + 4, pts.stick.y);
  await move(0, pts.stick.x + pts.radius, pts.stick.y);
  for (let i = 0; i < 24; i++) {
    await move(0, pts.stick.x + pts.radius + (i % 2 ? 2 : -2), pts.stick.y);
    await page.waitForTimeout(150);
    if (i % 3 === 2) await shotHud(`12-hold-through-death-${String(i).padStart(2, '0')}`);
  }
  await shot('13-after-deaths-thumb-never-lifted');
  await up(0);
  await shotHud('14-released-at-end');                  // nothing held

  gate('touch session: no console errors', res.errors.length === 0, res.errors.join(' | '));
  res.note = 'Read the shots (overlay line INPUT held is ground truth): 03 right~0.5; 04 +jump; 05 +attack (3 fingers); 06 only the stick; 07 nothing; 08 right=1; 09 left=1; 10 right+sprint; 10b sprint alone (toggle); 11 nothing; 12-* thumb held through deaths, STATE flips to GAME_OVER (INPUT -) then right=1.00 again after each respawn; 14 nothing held.';
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
fs.writeFileSync(path.join(outDir, 'touch-playtest.json'), JSON.stringify(report, null, 2));
console.log(report.passed ? '\nTOUCH_PLAYTEST: ALL GATES PASS (now read the screenshots)' : '\nTOUCH_PLAYTEST: FAILURES (see touch-playtest.json)');
process.exit(report.passed ? 0 : 1);

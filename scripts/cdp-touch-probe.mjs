#!/usr/bin/env node
// Bare-page proof of the multi-touch semantics of Chromium's DevTools `Input.dispatchTouchEvent`.
//
// WHY: the touch SKILL once said "touchEnd must carry no points (it ends everything); release ONE finger with a
// touchMove listing the others". On Chromium 1194 that is the opposite of the truth, and a script written to that
// note never lifts a finger (false green on "stick held while JUMP released"). This probe pins the REAL semantics
// with page-side touch listeners, no game involved, so it can be re-run whenever the Chromium version changes
// (`playwright` bump, new /opt/pw-browsers build).
//
// VERIFIED SEMANTICS (this is what scripts/lib/pw.mjs `multiTouch()` encodes):
//   touchStart / touchMove : list EVERY active point {x,y,id}
//   touchEnd               : releases exactly the point(s) LISTED in it  -> list ONLY the finger you lift
//   touchEnd with []       : ends ALL fingers
//   touchMove omitting one : changes nothing, the omitted finger is NOT released
//
// Usage:  node scripts/cdp-touch-probe.mjs        (exit 0 = all four semantics hold, 1 = the browser changed)
// No game, no network, no secrets.

import { launch, newProfilePage, playwrightSource } from './lib/pw.mjs';

const browser = await launch();
const { context, page, cdp, mt } = await newProfilePage(browser, 'phone');
await page.setContent('<body style="margin:0;width:100vw;height:100vh"></body>');
await page.evaluate(() => {
  window.log = [];
  for (const t of ['touchstart', 'touchmove', 'touchend', 'touchcancel']) {
    window.addEventListener(t, (e) => window.log.push(
      `${t} changed=[${[...e.changedTouches].map((x) => x.identifier)}] active=[${[...e.touches].map((x) => x.identifier)}]`),
    { passive: true });
  }
});
const settle = () => page.waitForTimeout(120);
const read = () => page.evaluate(() => window.log.slice());
const clear = () => page.evaluate(() => { window.log.length = 0; });

console.log(`playwright from: ${playwrightSource}`);
console.log(`chromium: ${browser.version()}`);

const results = [];
const check = (name, ok, detail) => {
  results.push(ok);
  console.log(`  [${ok ? 'PASS' : 'FAIL'}] ${name}${ok ? '' : `  ->  ${detail}`}`);
};
const lastActive = (line) => {
  const m = /active=\[([^\]]*)\]/.exec(line || '');
  return m ? m[1].split(',').filter(Boolean).map(Number) : null;
};

// A) touchEnd listing ONLY the lifted finger releases exactly that finger (multiTouch.up).
await mt.down(0, 100, 100);
await mt.down(1, 300, 100);
await mt.down(2, 500, 100);
await clear();
await mt.up(2);
await settle();
let log = await read();
console.log('--- A  touchEnd listing only the lifted point (fingers 0,1,2 down; lift 2)');
console.log(log.map((l) => `    ${l}`).join('\n'));
const endA = log.find((l) => l.startsWith('touchend'));
check('A: touchEnd [2] reports changed=[2] and leaves 0,1 active',
  !!endA && endA.includes('changed=[2]') && JSON.stringify(lastActive(endA)) === '[0,1]', endA || 'no touchend seen');
await clear();
await mt.up(1);
await settle();
log = await read();
const endA2 = log.find((l) => l.startsWith('touchend'));
check('A: then touchEnd [1] leaves only finger 0 active',
  !!endA2 && endA2.includes('changed=[1]') && JSON.stringify(lastActive(endA2)) === '[0]', endA2 || 'no touchend seen');
await mt.up(0);
await settle();

// B) touchMove that omits a finger releases nothing (the old SKILL note claimed the opposite).
await clear();
await mt.down(0, 100, 100);
await mt.down(1, 300, 100);
await clear();
await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: 110, y: 100, id: 0 }] }); // omits finger 1
await settle();
log = await read();
console.log('--- B  touchMove listing only finger 0 while 0 and 1 are down');
console.log(log.map((l) => `    ${l}`).join('\n'));
const anyEnd = log.some((l) => l.startsWith('touchend') || l.startsWith('touchcancel'));
const mv = log.find((l) => l.startsWith('touchmove'));
check('B: touchMove omitting finger 1 produced no touchend/touchcancel', !anyEnd, log.join(' | '));
check('B: finger 1 is still active after that touchMove', !!mv && (lastActive(mv) || []).includes(1), mv || 'no touchmove seen');

// C) touchEnd with [] ends ALL fingers.
await clear();
await mt.upAll();
await settle();
log = await read();
console.log('--- C  touchEnd with an empty point list');
console.log(log.map((l) => `    ${l}`).join('\n'));
const endC = log.filter((l) => l.startsWith('touchend')).pop();
check('C: touchEnd [] leaves no active fingers', !!endC && JSON.stringify(lastActive(endC)) === '[]', endC || 'no touchend seen');

// D) the keyboard guard really throws in a touch profile (a phone has no keyboard).
let threw = false;
try { await page.keyboard.press('Escape'); } catch (e) { threw = /PHONE HAS NO KEYBOARD/.test(String(e)); }
check('D: page.keyboard.press throws in the phone profile', threw, 'no throw');
threw = false;
try { await cdp.send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Escape' }); } catch (e) { threw = /PHONE HAS NO KEYBOARD/.test(String(e)); }
check('D: guarded CDP refuses Input.dispatchKeyEvent', threw, 'no throw');

await context.close();
await browser.close();
const failed = results.filter((r) => !r).length;
console.log(failed ? `CDP_TOUCH_PROBE: ${failed} FAILURE(S) - the browser's touch semantics changed, fix lib/pw.mjs multiTouch + the touch SKILL`
                    : 'CDP_TOUCH_PROBE: ALL PASS');
process.exit(failed ? 1 : 0);

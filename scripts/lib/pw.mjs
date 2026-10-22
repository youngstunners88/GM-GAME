// scripts/lib/pw.mjs - shared Playwright loader + phone-realism harness helpers.
//
// WHY THIS EXISTS
//  * 18 older scripts do a bare ESM `import { chromium } from 'playwright'`. ESM ignores NODE_PATH, so in this
//    container (global install only, no node_modules) they die with ERR_MODULE_NOT_FOUND. The touch/pause/verify
//    scripts use a createRequire fallback and work. This module is that fallback, written once.
//  * A phone has no keyboard. A script that presses Escape in a "phone" context proves nothing (a real key event
//    flips MobileLayoutManager into keyboard mode and hides the touch layer), and it can never discover a panel that
//    cannot be dismissed by touch alone. `noKeyboard()` makes that a hard error.
//  * Multi-finger CDP dispatch has exact semantics that the touch SKILL once got wrong. `multiTouch()` encodes the
//    verified ones (re-prove them with `node scripts/cdp-touch-probe.mjs`).
//
// Usage from a script in scripts/:
//   import { chromium, launchOptions, newProfilePage, multiTouch } from './lib/pw.mjs';
//
// Nothing here touches the game, the repo or the network. No secrets.

import { createRequire } from 'module';
const require = createRequire(import.meta.url);

// ---------------------------------------------------------------------------------------------------------------
// 1. Playwright loader. Order: explicit PLAYWRIGHT_PKG (wins), the repo-local package, then the container global.
// ---------------------------------------------------------------------------------------------------------------
const PW_GLOBAL = '/opt/node22/lib/node_modules/playwright/index.js';
const PW_CANDIDATES = [
  process.env.PLAYWRIGHT_PKG,
  '@playwright/test',
  'playwright',
  PW_GLOBAL,
].filter(Boolean);

function loadPlaywright() {
  const failures = [];
  for (const id of PW_CANDIDATES) {
    try {
      const mod = require(id);
      if (mod && mod.chromium) return { chromium: mod.chromium, source: id };
      failures.push(`${id}: loaded but has no .chromium`);
    } catch (e) {
      failures.push(`${id}: ${String(e && e.code || e).slice(0, 80)}`);
    }
  }
  throw new Error(
    'scripts/lib/pw.mjs: Playwright not found. Tried:\n  ' + failures.join('\n  ') +
    '\nFix: `npm install --no-save playwright@1` in the repo root, or set PLAYWRIGHT_PKG=/path/to/playwright/index.js');
}

const _pw = loadPlaywright();
/** Playwright's chromium launcher (BrowserType). */
export const chromium = _pw.chromium;
/** Which candidate actually loaded (printed by the probe so a version drift is visible). */
export const playwrightSource = _pw.source;
/** The Chromium binary the harness was calibrated on (symlink to chromium-1194 in this container). */
export const CHROMIUM_BIN = process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium';

/**
 * Chromium flags identical to scripts/touch-playtest.mjs (software GL so the Godot web export renders on a GPU-less box).
 * @returns {string[]}
 */
export function launchArgs() {
  return ['--no-sandbox', '--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader',
    '--enable-webgl', '--ignore-gpu-blocklist'];
}

/** `chromium.launch()` options: pinned binary + the flags above. `extra` is shallow-merged (args are appended). */
export function launchOptions(extra = {}) {
  const { args = [], ...rest } = extra;
  return { executablePath: CHROMIUM_BIN, args: [...launchArgs(), ...args], ...rest };
}

/** Launch Chromium the way every game script does. */
export function launch(extra = {}) {
  return chromium.launch(launchOptions(extra));
}

// ---------------------------------------------------------------------------------------------------------------
// 2. Device profiles (CSS px; dp == CSS px on web). Same numbers as scripts/touch-playtest.mjs.
// ---------------------------------------------------------------------------------------------------------------
export const PROFILES = {
  phone:    { w: 844,  h: 390,  dpr: 2, touch: true,  mobile: true,  label: 'phone landscape 844x390 @2' },
  tablet:   { w: 1024, h: 768,  dpr: 1, touch: true,  mobile: true,  label: 'tablet landscape 1024x768 @1' },
  portrait: { w: 390,  h: 844,  dpr: 2, touch: true,  mobile: true,  portrait: true, label: 'phone PORTRAIT 390x844 @2' },
  tabletPortrait: { w: 768, h: 1024, dpr: 1, touch: true, mobile: true, portrait: true, label: 'tablet PORTRAIT 768x1024 @1' },
  desktop:  { w: 1280, h: 720,  dpr: 1, touch: false, mobile: false, label: 'desktop 1280x720 (no touchscreen)' },
};

/** True when the profile (a key of PROFILES or a profile object) is a touch device, i.e. has no keyboard. */
export function isTouchProfile(profile) {
  const p = typeof profile === 'string' ? PROFILES[profile] : profile;
  if (!p) throw new Error(`pw.mjs: unknown profile ${String(profile)}`);
  return !!p.touch;
}

/** `browser.newContext()` options for a profile. */
export function contextOptions(profile) {
  const p = typeof profile === 'string' ? PROFILES[profile] : profile;
  if (!p) throw new Error(`pw.mjs: unknown profile ${String(profile)}`);
  return { viewport: { width: p.w, height: p.h }, deviceScaleFactor: p.dpr, hasTouch: p.touch, isMobile: p.mobile };
}

// ---------------------------------------------------------------------------------------------------------------
// 3. Page-side hooks (installed BEFORE the game loads).
//    window.__states  : StateMachine postMessage beacon (state_machine.gd), names in order
//    window.__stateT  : [[performance.now(), name], ...] the same, timestamped
//    window.__gm      : latest DebugOverlay beacon object (needs ?debug=1 or ?debug=beacon), window.__gmAt = its time
//    window.__gmWords : latest on-demand visible-text list (see requestWords)
//    window.__fr      : rAF frame recorder {n,max,gaps:[[t,dt]>100ms],recent:[last 60 dt]}
// ---------------------------------------------------------------------------------------------------------------
const HARNESS_INIT = () => {
  window.__states = [];
  window.__stateT = [];
  window.__gm = null;
  window.__gmAt = 0;
  window.__gmWords = null;
  window.__gmWordsReq = 0;
  window.addEventListener('message', (e) => {
    try {
      const d = e.data;
      if (!d || typeof d !== 'object') return;
      if (d.type === 'state') {
        window.__states.push(String(d.value));
        window.__stateT.push([Math.round(performance.now()), String(d.value)]);
      } else if (d.type === 'gm') {
        window.__gm = d.value;
        window.__gmAt = performance.now();
      } else if (d.type === 'gm_words') {
        window.__gmWords = d.value;
      }
    } catch (_) { /* ignore */ }
  });
  window.__fr = { last: performance.now(), n: 0, max: 0, gaps: [], recent: [] };
  const tick = (t) => {
    const fr = window.__fr;
    const dt = t - fr.last;
    fr.last = t;
    fr.n++;
    if (dt > fr.max) fr.max = dt;
    if (dt > 100) fr.gaps.push([Math.round(t), Math.round(dt)]);
    fr.recent.push(dt);
    if (fr.recent.length > 60) fr.recent.shift();
    requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
};

/** Install the page-side hooks above. Call before `page.goto`. */
export function installHarnessHooks(page) {
  return page.addInitScript(HARNESS_INIT);
}

/** Latest `window.__gm` beacon object, or null if the game has not posted one (is ?debug=1 on, game top-level?). */
export function gm(page) {
  return page.evaluate(() => window.__gm);
}

/** Age in ms of the latest beacon (Infinity if none) - assert it is small so a stale object is not trusted. */
export function gmAgeMs(page) {
  return page.evaluate(() => (window.__gmAt ? performance.now() - window.__gmAt : Infinity));
}

/**
 * Ask the game (DebugOverlay) for the list of visible text nodes and wait for it. The game only walks its tree when
 * asked, so the 4 Hz beacon stays scalar and frame times are not perturbed by the harness.
 * @returns {Promise<Array<{path:string,text:string}>|null>} null if no answer inside `timeoutMs` (overlay off?)
 */
export async function requestWords(page, timeoutMs = 3000) {
  await page.evaluate(() => { window.__gmWords = null; window.__gmWordsReq = (window.__gmWordsReq | 0) + 1; });
  const ok = await page.waitForFunction(() => window.__gmWords !== null, { timeout: timeoutMs, polling: 100 })
    .then(() => true).catch(() => false);
  return ok ? page.evaluate(() => window.__gmWords) : null;
}

/** Median of the last <=60 rAF intervals (ms) - the "measured frame time" a dwell must be a multiple of. */
export async function measuredFrameMs(page) {
  return page.evaluate(() => {
    const r = (window.__fr && window.__fr.recent ? window.__fr.recent.slice() : []).sort((a, b) => a - b);
    return r.length ? r[Math.floor(r.length / 2)] : 16.7;
  });
}

/** Minimum press->release dwell (ms): >= 3 measured frames, never under `floorMs`. Polled reads can miss shorter taps. */
export async function suggestedDwellMs(page, floorMs = 80) {
  return Math.max(floorMs, Math.ceil(3 * (await measuredFrameMs(page))));
}

/** rAF recorder snapshot {n,max,gaps,recent}. Gaps >100 ms = visible hitch; >250 ms = stall (TransitionDirector.STALL_MS). */
export function frameGaps(page) {
  return page.evaluate(() => window.__fr);
}

// ---------------------------------------------------------------------------------------------------------------
// 4. Console capture shared by the scripts (same regexes as touch-playtest.mjs).
// ---------------------------------------------------------------------------------------------------------------
export const GODOT_ERROR_RE = /USER SCRIPT ERROR|SCRIPT ERROR|Parse Error|Failed to instantiate an autoload|The InputMap action|SharedArrayBuffer/i;
// PRE-EXISTING noise, matched exactly so any NEW error still fails a gate.
export const BENIGN_RE = /Can't change this state while flushing queries|area_set_shape_disabled|USER WARNING|at: push_warning|No loader found for resource: res:\/\/src\/assets\/(sounds|music)\/|at: _load \(core\/io\/resource_loader|Blocking on the main thread|ERR_CONNECTION_RESET|Failed to fetch|godot_js_fetch|posthog|ERR_NAME_NOT_RESOLVED|ERR_TUNNEL|net::ERR/i;
const DEFAULT_PREFIXES = ['[Touch]', '[TD]', '[SceneRouter]', '[EP2]', '[Blaze]'];

/**
 * Attach console/pageerror capture. Returns a live object: `lines` ({t,text} for prefixed game logs, t = ms since
 * attach), `errors` (strings; GODOT_ERROR_RE or console error, minus BENIGN_RE).
 */
export function collectConsole(page, { prefixes = DEFAULT_PREFIXES, echo = false } = {}) {
  const t0 = Date.now();
  const out = { lines: [], errors: [] };
  page.on('console', (m) => {
    const text = m.text();
    if (prefixes.some((p) => text.startsWith(p))) {
      out.lines.push({ t: Date.now() - t0, text: text.slice(0, 200) });
      if (echo) console.log(`    ${text.slice(0, 160)}`);
    }
    if ((m.type() === 'error' || GODOT_ERROR_RE.test(text)) && !BENIGN_RE.test(text)) {
      out.errors.push(`[${m.type()}] ${text.slice(0, 240)}`);
    }
  });
  page.on('pageerror', (e) => out.errors.push(`[pageerror] ${String(e).slice(0, 240)}`));
  return out;
}

// ---------------------------------------------------------------------------------------------------------------
// 5. Touch-profile invariant: a phone has no keyboard.
// ---------------------------------------------------------------------------------------------------------------
const KEY_CDP_METHODS = new Set(['Input.dispatchKeyEvent', 'Input.insertText', 'Input.imeSetComposition']);
const realKeyboards = new WeakMap();

function keyboardError(what, label) {
  return new Error(
    `PHONE HAS NO KEYBOARD: ${what} was called in touch profile "${label}". A real key event flips MobileLayoutManager ` +
    'into keyboard mode and hides the touch layer, so the run no longer proves what a phone does. ' +
    'Dismiss/advance by tapping (page.touchscreen.tap / multiTouch) or by waiting. ' +
    'A deliberate hybrid-laptop test must use hybridKeyboard(page).');
}

/**
 * Make `page.keyboard` (every method), `page.press` and `page.type` throw. Call right after `newPage()` for any touch
 * profile. Idempotent. Returns `page`.
 */
export function noKeyboard(page, label = 'touch') {
  if (realKeyboards.has(page)) return page;
  const real = page.keyboard;
  realKeyboards.set(page, real);
  const guarded = new Proxy(real, {
    get(target, prop) {
      const v = target[prop];
      if (typeof v === 'function') {
        return () => { throw keyboardError(`page.keyboard.${String(prop)}()`, label); };
      }
      return v;
    },
  });
  Object.defineProperty(page, 'keyboard', { value: guarded, configurable: true });
  for (const m of ['press', 'type']) {
    Object.defineProperty(page, m, {
      value: () => { throw keyboardError(`page.${m}()`, label); },
      configurable: true,
    });
  }
  return page;
}

/** The real keyboard of a page that went through noKeyboard() - ONLY for a deliberate hybrid-device scenario. */
export function hybridKeyboard(page) {
  return realKeyboards.get(page) || page.keyboard;
}

/** Wrap a CDP session so key-event methods throw (touch events still pass). Returns the wrapper. */
export function guardCdp(cdp, label = 'touch') {
  return new Proxy(cdp, {
    get(target, prop) {
      if (prop === 'send') {
        return (method, params) => {
          if (KEY_CDP_METHODS.has(method)) throw keyboardError(`CDP ${method}`, label);
          return target.send(method, params);
        };
      }
      const v = target[prop];
      return typeof v === 'function' ? v.bind(target) : v;
    },
  });
}

// ---------------------------------------------------------------------------------------------------------------
// 6. Multi-touch over CDP with the VERIFIED semantics (Chromium 1194; proof: node scripts/cdp-touch-probe.mjs).
//      touchStart / touchMove : list EVERY active point {x,y,id}.
//      touchEnd               : releases exactly the point(s) LISTED in it (list only the finger you lift).
//      touchEnd with []       : ends ALL fingers.
//      touchMove omitting one : changes nothing - the omitted finger is NOT released.
//    Polled reads (Input.is_action_pressed) can miss a press+release inside one frame: tap() dwells for dwellMs
//    (get a safe number from suggestedDwellMs(page)). Event-based consumers are robust either way.
// ---------------------------------------------------------------------------------------------------------------
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * @param cdp  a CDPSession (context.newCDPSession(page)); pass guardCdp(cdp) to also forbid key events
 * @param opts {dwellMs?: default tap dwell, stepMs?: pause between drag steps}
 */
export function multiTouch(cdp, { dwellMs = 100, stepMs = 16 } = {}) {
  const active = new Map(); // id -> {x,y}
  const points = () => [...active.entries()].map(([id, v]) => ({ x: v.x, y: v.y, id }));
  const send = (type, touchPoints) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints });
  const need = (id) => {
    const at = active.get(id);
    if (!at) throw new Error(`multiTouch: finger ${id} is not down (active: [${[...active.keys()]}])`);
    return at;
  };
  const api = {
    /** Finger ids currently down. */
    ids: () => [...active.keys()],
    /** Position of a finger that is down. */
    at: (id) => ({ ...need(id) }),
    count: () => active.size,
    async down(id, x, y) {
      if (active.has(id)) throw new Error(`multiTouch: finger ${id} is already down`);
      active.set(id, { x, y });
      await send('touchStart', points());
    },
    async move(id, x, y) {
      need(id);
      active.set(id, { x, y });
      await send('touchMove', points());           // always ALL active points (omitting one releases nothing)
    },
    /** Lift ONE finger: touchEnd that lists only that point. */
    async up(id) {
      const at = need(id);
      active.delete(id);
      await send('touchEnd', [{ x: at.x, y: at.y, id }]);
    },
    /** Lift every finger: touchEnd with no points. */
    async upAll() {
      active.clear();
      await send('touchEnd', []);
    },
    /** The OS took the touch away (system gesture, call, notification shade): touchCancel for all fingers. */
    async cancelAll() {
      active.clear();
      await send('touchCancel', []);
    },
    async tap(id, x, y, ms = dwellMs) {
      await api.down(id, x, y);
      await sleep(ms);
      await api.up(id);
    },
    /** Straight drag of a finger that is already down, in `steps` moves of `stepMs`. */
    async dragTo(id, x, y, steps = 6, ms = stepMs) {
      const a = need(id);
      for (let i = 1; i <= steps; i++) {
        await api.move(id, a.x + ((x - a.x) * i) / steps, a.y + ((y - a.y) * i) / steps);
        await sleep(ms);
      }
    },
    /** down, drag to (x1,y1), (optionally hold), up. */
    async swipe(id, x0, y0, x1, y1, { steps = 6, holdMs = 0 } = {}) {
      await api.down(id, x0, y0);
      await api.dragTo(id, x1, y1, steps);
      if (holdMs) await sleep(holdMs);
      await api.up(id);
    },
    sleep,
  };
  return api;
}

// ---------------------------------------------------------------------------------------------------------------
// 7. One call to get a profile-correct page: context + hooks + (for touch) the keyboard guard and a guarded CDP.
// ---------------------------------------------------------------------------------------------------------------
/**
 * @param browser  from launch()
 * @param key      key of PROFILES
 * @returns {{context, page, cdp, touch:boolean, profile, mt: ReturnType<typeof multiTouch>|null}}
 *          `cdp`/`mt` are null on the desktop profile.
 */
export async function newProfilePage(browser, key, { dwellMs } = {}) {
  const profile = PROFILES[key];
  if (!profile) throw new Error(`pw.mjs: unknown profile ${key}`);
  const context = await browser.newContext(contextOptions(profile));
  const page = await context.newPage();
  await installHarnessHooks(page);
  let cdp = null;
  let mt = null;
  if (profile.touch) {
    noKeyboard(page, key);
    cdp = guardCdp(await context.newCDPSession(page), key);
    mt = multiTouch(cdp, dwellMs ? { dwellMs } : {});
  }
  return { context, page, cdp, touch: profile.touch, profile, mt };
}

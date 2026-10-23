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
export function contextOptions(profile, { dpr, size } = {}) {
  const p = typeof profile === 'string' ? PROFILES[profile] : profile;
  if (!p) throw new Error(`pw.mjs: unknown profile ${String(profile)}`);
  const [w, h] = size || [p.w, p.h];
  return { viewport: { width: w, height: h }, deviceScaleFactor: dpr || p.dpr, hasTouch: p.touch, isMobile: p.mobile };
}

// ---------------------------------------------------------------------------------------------------------------
// 3. Page-side hooks (installed BEFORE the game loads). Everything is stamped with performance.now() so rAF gaps,
//    long tasks, game log lines, StateMachine changes and luminance samples all share ONE clock.
//    window.__states  : StateMachine postMessage beacon (state_machine.gd), names in order
//    window.__stateT  : [[t, name], ...] the same, timestamped
//    window.__gm      : latest DebugOverlay beacon object (needs ?debug=1 or ?debug=beacon), window.__gmAt = its time
//    window.__gmLog   : [[t, {scene,state,td,held,shown,susp,profile,worst_ms,mem_mb}], ...] every beacon (<= 4000)
//    window.__gmWords : latest on-demand visible-text list (see requestWords)
//    window.__fr      : rAF frame recorder {n,max,gaps:[[t,dt]>40ms],all:[[t,dt]...],recent:[last 60 dt]}
//    window.__logT    : [[t, text], ...] console lines starting [TD] [EP2] [HARNESS] [MEM] [SceneRouter] [Touch] [Blaze]
//    window.__mem     : [[t, wasmHeapBytes, jsHeapUsedBytes], ...] once a second (peak = max)
//    window.__long    : [[startTime, duration], ...] PerformanceObserver 'longtask' entries (>50 ms main-thread tasks)
//    window.__lum     : [[t, mean luminance 0..1], ...] opt-in (installHarnessHooks(page,{lum:true})): three 1-px rows of the
//                       WebGL framebuffer are read right after each Godot rAF callback, in the same task, so the canvas is
//                       not yet cleared. A luminance < 0.08 is a "black frame".
// ---------------------------------------------------------------------------------------------------------------
const HARNESS_INIT = (opts) => {
  const now = () => Math.round(performance.now() * 10) / 10;
  window.__states = [];
  window.__stateT = [];
  window.__gm = null;
  window.__gmAt = 0;
  window.__gmLog = [];
  window.__gmWords = null;
  window.__gmWordsReq = 0;
  window.__logT = [];
  window.__long = [];
  window.__lum = [];
  window.addEventListener('message', (e) => {
    try {
      const d = e.data;
      if (!d || typeof d !== 'object') return;
      if (d.type === 'state') {
        window.__states.push(String(d.value));
        window.__stateT.push([now(), String(d.value)]);
      } else if (d.type === 'gm') {
        window.__gm = d.value;
        window.__gmAt = performance.now();
        const v = d.value || {};
        const t = v.touch || {};
        if (window.__gmLog.length < 4000) {
          window.__gmLog.push([now(), { scene: v.scene, state: v.state, td: v.td, held: t.held, heldActions: v.held,
            shown: t.shown, susp: t.susp, profile: t.profile, worst_ms: v.worst_ms, mem_mb: v.mem_mb, tex_mb: v.tex_mb }]);
        }
      } else if (d.type === 'gm_words') {
        window.__gmWords = d.value;
      }
    } catch (_) { /* ignore */ }
  });
  // game log lines on the shared clock
  const keep = /^\[(TD|EP2|HARNESS|MEM|SceneRouter|Touch|Blaze)\]/;
  for (const m of ['log', 'info', 'warn']) {
    const orig = console[m].bind(console);
    console[m] = (...args) => {
      try { const t = String(args[0]); if (keep.test(t) && window.__logT.length < 20000) window.__logT.push([now(), t.slice(0, 200)]); } catch (_) { /* ignore */ }
      return orig(...args);
    };
  }
  try {
    new PerformanceObserver((list) => {
      for (const e of list.getEntries()) window.__long.push([Math.round(e.startTime * 10) / 10, Math.round(e.duration * 10) / 10]);
    }).observe({ type: 'longtask', buffered: true });
  } catch (_) { /* longtask unsupported */ }
  // peak memory: the WASM heap (hook the constructor BEFORE the engine creates it) + the JS heap where Chromium exposes it
  window.__mem = [];
  try {
    const OrigMem = WebAssembly.Memory;
    window.__wasmMems = [];
    WebAssembly.Memory = class extends OrigMem { constructor(...a) { super(...a); window.__wasmMems.push(this); } };
    // Godot 4.3's non-threaded web build EXPORTS the memory from the module instead of constructing it in JS
    for (const fn of ['instantiate', 'instantiateStreaming']) {
      const orig = WebAssembly[fn];
      if (!orig) continue;
      WebAssembly[fn] = function (...a) {
        return orig.apply(this, a).then((r) => {
          try { const m = (r.instance || r).exports.memory; if (m) window.__wasmMems.push(m); } catch (_) { /* ignore */ }
          return r;
        });
      };
    }
  } catch (_) { /* leave it */ }
  setInterval(() => {
    try {
      let wasm = 0;
      for (const m of window.__wasmMems || []) wasm = Math.max(wasm, m.buffer.byteLength);
      const jh = performance.memory ? performance.memory.usedJSHeapSize : 0;
      if (window.__mem.length < 4000) window.__mem.push([now(), wasm, jh]);
    } catch (_) { /* ignore */ }
  }, 1000);
  window.__fr = { last: performance.now(), n: 0, max: 0, gaps: [], all: [], recent: [] };
  const origRaf = window.requestAnimationFrame.bind(window);
  // our own recorder uses the ORIGINAL rAF
  const tick = (t) => {
    const fr = window.__fr;
    const dt = t - fr.last;
    fr.last = t;
    fr.n++;
    if (dt > fr.max) fr.max = dt;
    if (dt > 40 && fr.gaps.length < 20000) fr.gaps.push([Math.round(t), Math.round(dt)]);
    if (fr.all.length < 40000) fr.all.push([Math.round(t), Math.round(dt)]);
    fr.recent.push(dt);
    if (fr.recent.length > 60) fr.recent.shift();
    origRaf(tick);
  };
  origRaf(tick);
  if (opts && opts.lum) {
    let lastS = 0;
    let cv = null;
    let cx = null;
    let glc = null;
    let strip = null;
    const sample = () => {
      const t = performance.now();
      if (t - lastS < (opts.lumEveryMs || 90)) return;
      lastS = t;
      const c = document.querySelector('canvas');
      if (!c || !c.width) return;
      try {
        // Three 1-px rows of the default framebuffer via readPixels: the frame was just drawn (same task, buffer not yet
        // presented/cleared) and this avoids drawImage()'s full-frame copy, which under SwiftShader costs more than the
        // frame itself. Skipped (not black!) when an off-screen FBO is bound.
        if (!glc) glc = c.getContext('webgl2') || c.getContext('webgl');
        if (!glc) return;
        const w = glc.drawingBufferWidth;
        const h = glc.drawingBufferHeight;
        if (!strip || strip.length !== w * 4) strip = new Uint8Array(w * 4);
        // Godot leaves an off-screen FBO bound, so point ONLY the READ binding (WebGL2) at the default framebuffer and
        // put it back afterwards: the engine's own (draw) binding and its state cache are untouched.
        const prevRead = glc.READ_FRAMEBUFFER ? glc.getParameter(glc.READ_FRAMEBUFFER_BINDING) : glc.getParameter(glc.FRAMEBUFFER_BINDING);
        if (!glc.READ_FRAMEBUFFER && prevRead !== null) return;       // WebGL1 with an FBO bound: skip, never rebind
        if (glc.READ_FRAMEBUFFER) glc.bindFramebuffer(glc.READ_FRAMEBUFFER, null);
        let sum = 0;
        let n = 0;
        try {
          for (const f of [0.25, 0.5, 0.75]) {
            glc.readPixels(0, Math.floor(h * f), w, 1, glc.RGBA, glc.UNSIGNED_BYTE, strip);
            for (let i = 0; i < strip.length; i += 4 * 4) { sum += 0.2126 * strip[i] + 0.7152 * strip[i + 1] + 0.0722 * strip[i + 2]; n++; }
          }
        } finally {
          if (glc.READ_FRAMEBUFFER) glc.bindFramebuffer(glc.READ_FRAMEBUFFER, prevRead);
        }
        if (window.__lum.length < 20000) window.__lum.push([Math.round(t * 10) / 10, Math.round(sum / n / 255 * 10000) / 10000]);
      } catch (_) { /* lost context */ }
    };
    // wrap the page's rAF so the sample is taken in the SAME task, right after the engine's own frame callback
    window.requestAnimationFrame = (cb) => origRaf((ts) => { try { cb(ts); } finally { sample(); } });
  }
};

/** Install the page-side hooks above. Call before `page.goto`. opts: {lum:bool, lumEveryMs:number} */
export function installHarnessHooks(page, opts = {}) {
  return page.addInitScript(HARNESS_INIT, opts);
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
export const BENIGN_RE = /Can't change this state while flushing queries|area_set_shape_disabled|USER WARNING|at: push_warning|No loader found for resource: res:\/\/src\/assets\/(sounds|music)\/|at: _load \(core\/io\/resource_loader|at: open \(core\/io\/resource_format_binary|Blocking on the main thread|ERR_CONNECTION_RESET|Failed to fetch|godot_js_fetch|posthog|ERR_NAME_NOT_RESOLVED|ERR_TUNNEL|net::ERR/i;
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
 * @param opts     {dwellMs, dpr (override the profile's deviceScaleFactor), hooks:{lum,lumEveryMs}} (hooks -> installHarnessHooks)
 * @returns {{context, page, cdp, touch:boolean, profile, mt: ReturnType<typeof multiTouch>|null}}
 *          `cdp`/`mt` are null on the desktop profile.
 */
export async function newProfilePage(browser, key, { dwellMs, hooks = {}, dpr, size } = {}) {
  const profile = PROFILES[key];
  if (!profile) throw new Error(`pw.mjs: unknown profile ${key}`);
  const context = await browser.newContext(contextOptions(profile, { dpr, size }));
  const page = await context.newPage();
  await installHarnessHooks(page, hooks);
  let cdp = null;
  let mt = null;
  if (profile.touch) {
    noKeyboard(page, key);
    cdp = guardCdp(await context.newCDPSession(page), key);
    mt = multiTouch(cdp, dwellMs ? { dwellMs } : {});
  }
  return { context, page, cdp, touch: profile.touch, profile, mt };
}

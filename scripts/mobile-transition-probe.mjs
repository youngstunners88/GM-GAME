#!/usr/bin/env node
// mobile-transition-probe.mjs - numbers for the Episode 1 -> Episode 2 hand-off and the Part 1 cuts, from a REAL browser
// running the REAL web export, in a phone-shaped Chromium (844x390 @2, touch, mobile) with the CPU throttled.
//
//   (A) Stage 3 boss kill -> film -> Episode 2 first runner frame     (a thumb stays on the stick the whole way)
//   (B) menu boot warp -> Episode 2 first runner frame                (?ep2=1)
//   (C) runner -> cliff film -> hideout                               (?ep2=1&ep2chamber=1, an 8 m runner)
//
// WHAT IT IS NOT: a phone. SwiftShader (software GL) + Emulation.setCPUThrottlingRate conflates CPU and GPU cost, so the
// numbers are a RELATIVE regression gate ("did this change make the hand-off worse than before?"), never "60 fps on a
// phone". The founder's hard-refresh on a real phone stays the final gate. Say "pushed / deploying", not "live".
//
// NEEDS a build with the gm_harness feature tag for scenario A (the fast boss kill) and for B/C (the access-code skip):
//   GM_HARNESS=1 bash scripts/ep2-local-export.sh          # serves http://localhost:8899/game/index.html
// The tag is compiled out of the shipped build; against a normal build A and B/C stop at the gate / the boss fight and
// the probe reports exactly how far they got.
//
// Usage:
//   node scripts/mobile-transition-probe.mjs [--url http://localhost:8899/game/index.html] [--scenario A,B,C]
//        [--throttle 1,4] [--out web_verify/mobile-transition-probe] [--json result.json] [--label before|after]
//        [--no-lum] [--run-s 30] [--dpr 1] [--size 422x195]     (--dpr overrides the phone profile's deviceScaleFactor 2: SwiftShader
//        renders the 3D runner at 1688x780 in ~1 frame per several seconds, which buries every stall in slow frames)
//   node scripts/mobile-transition-probe.mjs --selftest        # pure analysis checks, no browser (exit 1 on failure)
//
// METRICS (all times on ONE clock, performance.now() in the page; see scripts/lib/pw.mjs HARNESS_INIT):
//   die_window_longtask_ms     long-task time (>50 ms main-thread tasks) in [t_die, t_die + 2500 ms]            (A)
//   gap_die/film/handoff_ms    longest requestAnimationFrame gap in that window
//   film_gaps_over_120         number of rAF gaps > 120 ms during the film (goal: at most 2)
//   cover_hold_ms              StateMachine TRANSITIONING -> PLAYING (the director's cover hold)                (A)
//   first_runner_after_go_ms   TRANSITIONING -> "[EP2] leg start"
//   black_frames / black_ms    luminance samples < 0.08 between the cut and the reveal (+700 ms fade)
//   runner_over100_30s         rAF gaps > 100 ms in the first 30 s of the runner (goal: fewer than 5)
//   held_after_swap            max TouchActions held count in the beacons after the swap (goal: 0)
//   wasm_peak_mb / jsheap_peak_mb  peak WebAssembly.Memory size / Chromium JS heap (page hook; Godot's MEMORY_STATIC is 0 on web)
//   tex_peak_mb                RENDER_TEXTURE_MEM_USED peak (beacon)
// Deliver numbers even when a scenario does not reach its end: `reached` says how far it got and `why`.

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { launch, newProfilePage, collectConsole, PROFILES, playwrightSource } from './lib/pw.mjs';

// ------------------------------------------------------------------------------------------------------------------
// 1. Pure analysis (exported; --selftest exercises it without a browser)
// ------------------------------------------------------------------------------------------------------------------
export const BLACK_LUM = 0.08;

/** rAF gaps are [endTime, dt]; a gap belongs to a window when [end-dt, end] overlaps [t0, t1]. */
export function gapsIn(gaps, t0, t1) {
  return gaps.filter(([t, dt]) => t >= t0 && t - dt <= t1);
}
export function longestGap(gaps, t0, t1) {
  let best = { ms: 0, at: null };
  for (const [t, dt] of gapsIn(gaps, t0, t1)) if (dt > best.ms) best = { ms: dt, at: t };
  return best;
}
export function countOver(gaps, thr, t0, t1) {
  return gapsIn(gaps, t0, t1).filter(([, dt]) => dt > thr).length;
}
/** Frame count / median / p95 of rAF intervals [[end, dt], ...] whose end lies in [t0, t1]. The median says how slow a
 *  "normal" frame is in this environment (SwiftShader: often > 100 ms), which is what every gap must be read against. */
export function framesIn(all, t0, t1) {
  const d = all.filter(([t]) => t >= t0 && t <= t1).map(([, dt]) => dt).sort((a, b) => a - b);
  if (!d.length) return { n: 0, median: null, p95: null };
  return { n: d.length, median: d[Math.floor(d.length / 2)], p95: d[Math.min(d.length - 1, Math.floor(d.length * 0.95))] };
}
/** Sum of long-task time overlapping [t0, t1]. long = [[start, dur], ...] */
export function longtaskMs(long, t0, t1) {
  let sum = 0;
  for (const [s, d] of long) {
    const a = Math.max(s, t0);
    const b = Math.min(s + d, t1);
    if (b > a) sum += b - a;
  }
  return Math.round(sum);
}
/** Black-frame statistics from luminance samples [[t, lum], ...] inside [t0, t1]. */
export function blackFrames(lum, t0, t1, thr = BLACK_LUM) {
  const s = lum.filter(([t]) => t >= t0 && t <= t1);
  const runs = [];
  let cur = null;
  for (const [t, l] of s) {
    if (l < thr) {
      if (!cur) cur = { start: t, end: t, n: 0, min: l };
      cur.end = t;
      cur.n++;
      cur.min = Math.min(cur.min, l);
    } else if (cur) {
      runs.push(cur);
      cur = null;
    }
  }
  if (cur) runs.push(cur);
  return {
    samples: s.length,
    black: s.filter(([, l]) => l < thr).length,
    min: s.length ? Math.min(...s.map(([, l]) => l)) : null,
    runs: runs.map((r) => ({ start: Math.round(r.start), end: Math.round(r.end), ms: Math.round(r.end - r.start), n: r.n, min: r.min })),
    black_ms: Math.round(runs.reduce((a, r) => a + (r.end - r.start), 0)),
  };
}
/** First entry of a [[t, text]] list whose text matches `re` and t >= after. */
export function firstLog(logs, re, after = -Infinity) {
  return logs.find(([t, text]) => t >= after && re.test(text)) || null;
}
export function firstState(states, name, after = -Infinity) {
  const e = states.find(([t, n]) => t >= after && n === name);
  return e ? e[0] : null;
}
/** Highest held-action count among beacon entries in [t0, t1] (gmlog = [[t, {held,...}], ...]); null if none. */
export function heldMax(gmlog, t0, t1 = Infinity) {
  const v = gmlog.filter(([t]) => t >= t0 && t <= t1).map(([, e]) => e.held).filter((h) => typeof h === 'number');
  return v.length ? Math.max(...v) : null;
}
export function peak(gmlog, key) {
  const v = gmlog.map(([, e]) => e[key]).filter((x) => typeof x === 'number');
  return v.length ? Math.max(...v) : null;
}

/** Turn raw page data + the scenario's marks into the metrics object. `m` = marks in page ms (or null when not reached). */
export function analyse(scn, raw, m, opts = {}) {
  const runS = (opts.runS ?? 30) * 1000;
  const gaps = raw.fr?.gaps || [];
  const out = { marks: m };
  const win = (name, a, b) => {
    if (a == null || b == null) return;
    const g = longestGap(gaps, a, b);
    out[`gap_${name}_ms`] = g.ms;
    out[`gap_${name}_at`] = g.at;
    out[`over120_${name}`] = countOver(gaps, 120, a, b);
    out[`longtask_${name}_ms`] = longtaskMs(raw.long || [], a, b);
  };
  const black = (name, a, b) => {
    if (a == null || b == null) return;
    const bf = blackFrames(raw.lum || [], a, b);
    out[`black_${name}`] = { samples: bf.samples, black: bf.black, black_ms: bf.black_ms, min_lum: bf.min, runs: bf.runs };
  };
  if (scn === 'A') {
    win('die', m.die, m.die == null ? null : m.die + 2500);
    win('film', m.die == null ? null : m.die + 2500, m.go);
    win('handoff', m.go, m.reveal == null ? null : m.reveal + 700);
    black('cut', m.go == null ? null : m.go - 300, m.reveal == null ? null : m.reveal + 700);
    if (m.go != null && m.reveal != null) out.cover_hold_ms = Math.round(m.reveal - m.go);
    if (m.go != null && m.leg != null) out.first_runner_after_go_ms = Math.round(m.leg - m.go);
    if (m.go != null) out.held_after_swap = heldMax(raw.gmlog || [], m.go);
    if (m.die != null) out.held_before_die = heldMax(raw.gmlog || [], m.die - 1500, m.die);
  } else if (scn === 'B') {
    win('swap', m.load, m.leg == null ? null : m.leg + 800);
    black('swap', m.load == null ? null : m.load - 200, m.leg == null ? null : m.leg + 800);
    if (m.load != null && m.leg != null) out.load_to_runner_ms = Math.round(m.leg - m.load);
  } else if (scn === 'C') {
    win('runner_to_film', m.runnerEnd == null ? null : m.runnerEnd - 300, m.chamber == null ? null : m.chamber + 1500);
    black('runner_to_film', m.runnerEnd == null ? null : m.runnerEnd - 300, m.chamber == null ? null : m.chamber + 1500);
    win('film_to_hideout', m.filmEndLo, m.hideout == null ? null : m.hideout + 1500);
    black('film_to_hideout', m.filmEndLo, m.hideout == null ? null : m.hideout + 1500);
    if (m.chamber != null && m.hideout != null) out.film_ms = Math.round(m.hideout - m.chamber);
  }
  if (m.leg != null) {
    out.runner_over100_30s = countOver(gaps, 100, m.leg, m.leg + runS);
    out.runner_worst_gap_30s_ms = longestGap(gaps, m.leg, m.leg + runS).ms;
    out.runner_longtask_30s_ms = longtaskMs(raw.long || [], m.leg, m.leg + runS);
    const fa = framesIn(raw.fr?.all || [], m.leg, m.leg + runS);
    out.runner_frames_30s = fa.n;
    out.runner_median_dt_ms = fa.median;
    out.runner_p95_dt_ms = fa.p95;
  }
  out.frames_total = raw.fr?.n ?? null;
  out.gap_worst_overall_ms = Math.round(raw.fr?.max ?? 0);
  out.wasm_peak_mb = raw.mem?.length ? Math.round(Math.max(...raw.mem.map((e) => e[1])) / 1048576) : null;
  out.jsheap_peak_mb = raw.mem?.length ? Math.round(Math.max(...raw.mem.map((e) => e[2])) / 1048576) : null;
  out.tex_peak_mb = peak(raw.gmlog || [], 'tex_mb');
  return out;
}

function selftest() {
  let bad = 0;
  const eq = (name, got, want) => {
    const ok = JSON.stringify(got) === JSON.stringify(want);
    if (!ok) bad++;
    console.log(`  [${ok ? 'PASS' : 'FAIL'}] ${name}${ok ? '' : `  got ${JSON.stringify(got)} want ${JSON.stringify(want)}`}`);
  };
  const gaps = [[1000, 120], [2000, 300], [3000, 90], [9000, 500]];
  eq('longestGap in a window', longestGap(gaps, 1500, 3500), { ms: 300, at: 2000 });
  eq('a gap that only overlaps the window edge counts', longestGap(gaps, 8600, 8700), { ms: 500, at: 9000 });
  eq('a gap outside the window does not', longestGap(gaps, 3100, 8000), { ms: 0, at: null });
  eq('countOver is strict >', countOver(gaps, 120, 0, 10000), 2);
  eq('framesIn', framesIn([[10, 16], [20, 17], [30, 400], [900, 5]], 0, 100), { n: 3, median: 17, p95: 400 });
  eq("longtaskMs clips to the window", longtaskMs([[100, 200], [900, 300]], 250, 1000), 50 + 100);
  const lum = [[0, 0.5], [100, 0.02], [200, 0.01], [300, 0.4], [400, 0.05], [500, 0.5]];
  const bf = blackFrames(lum, 0, 600);
  eq('blackFrames counts + runs', [bf.black, bf.runs.length, bf.black_ms, bf.min], [3, 2, 100, 0.01]);
  eq('blackFrames threshold is 0.08 (0.08 itself is not black)', blackFrames([[0, 0.08], [1, 0.0799]], 0, 5).black, 1);
  eq('firstLog respects after', firstLog([[10, '[EP2] leg start 0'], [50, '[EP2] leg start 1']], /leg start/, 20), [50, '[EP2] leg start 1']);
  eq('firstState', firstState([[5, 'PLAYING'], [9, 'TRANSITIONING'], [20, 'PLAYING']], 'PLAYING', 6), 20);
  const gml = [[100, { held: 2, mem_mb: 50 }], [200, { held: 0, mem_mb: 80 }], [300, { held: 1 }]];
  eq('heldMax window', heldMax(gml, 150), 1);
  eq('heldMax none -> null', heldMax(gml, 1000), null);
  eq('peak', peak(gml, 'mem_mb'), 80);
  const raw = { fr: { gaps: [[1100, 200], [5000, 180], [5400, 110], [20000, 90]], n: 999, max: 200 },
    long: [[1000, 150]], lum: [[4900, 0.3], [5000, 0.01], [5100, 0.02], [5300, 0.4]], gmlog: [[5200, { held: 0 }], [5300, { held: 3 }]] };
  const a = analyse('A', raw, { die: 1000, go: 4900, reveal: 5200, leg: 5400 }, { runS: 30 });
  eq('A: cover hold', a.cover_hold_ms, 300);
  eq('A: first runner after go', a.first_runner_after_go_ms, 500);
  eq('A: die-window gap', [a.gap_die_ms, a.longtask_die_ms], [200, 150]);
  eq('A: black frames in the cut', [a.black_cut.black, a.black_cut.black_ms], [2, 100]);
  eq('A: held after swap is the max after go', a.held_after_swap, 3);
  eq('A: runner gaps >100 in the first 30 s', a.runner_over100_30s, 1);
  console.log(bad ? `MOBILE_TRANSITION_PROBE_SELFTEST: ${bad} FAILURE(S)` : 'MOBILE_TRANSITION_PROBE_SELFTEST: ALL PASS');
  return bad;
}

// ------------------------------------------------------------------------------------------------------------------
// 2. Browser driver
// ------------------------------------------------------------------------------------------------------------------
const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (!isMain) {
  // imported for its analysis functions only
} else {
  await main();
}

function arg(name, def) {
  const i = process.argv.indexOf(`--${name}`);
  if (i < 0) return def;
  const v = process.argv[i + 1];
  return v === undefined || v.startsWith('--') ? true : v;
}

async function main() {
  if (process.argv.includes('--selftest')) process.exit(selftest() ? 1 : 0);
  const base = String(arg('url', 'http://localhost:8899/game/index.html'));
  const scenarios = String(arg('scenario', 'A,B,C')).split(',').map((s) => s.trim().toUpperCase()).filter(Boolean);
  const rates = String(arg('throttle', '1,4')).split(',').map(Number).filter((n) => n >= 1);
  const outDir = String(arg('out', 'web_verify/mobile-transition-probe'));
  const jsonOut = String(arg('json', path.join(outDir, 'result.json')));
  const label = String(arg('label', 'run'));
  const lum = !process.argv.includes('--no-lum');
  const runS = Number(arg('run-s', 30));
  const size = arg('size', '') ? String(arg('size')).split('x').map(Number) : undefined;   // e.g. 422x195 (CSS px)
  const dpr = arg('dpr', 0) ? Number(arg('dpr', 0)) : undefined;   // default: the phone profile's own DPR (2)
  fs.mkdirSync(outDir, { recursive: true });

  const T0 = Date.now();
  const say = (s) => console.log(`[${((Date.now() - T0) / 1000).toFixed(0).padStart(5)}s] ${s}`);
  const results = [];
  say(`probe label=${label} url=${base} scenarios=${scenarios} throttle=${rates} dpr=${dpr ?? 'profile(2)'} size=${size ? size.join('x') : 'profile(844x390)'} lum=${lum} playwright=${playwrightSource}`);

  for (const scn of scenarios) {
    for (const rate of rates) {
      say(`=== scenario ${scn} @ ${rate}x CPU ===`);
      let r;
      try {
        r = await runScenario(scn, rate, { base, outDir, lum, runS, say, label, dpr, size });
      } catch (e) {
        r = { scenario: scn, throttle: rate, reached: 'driver error', why: String(e && e.stack || e).slice(0, 600) };
      }
      results.push(r);
      say(`--- ${scn} @ ${rate}x: reached=${r.reached}${r.why ? ` (${r.why})` : ''}`);
      fs.writeFileSync(jsonOut, JSON.stringify({ label, url: base, results, finished: false }, null, 2));
    }
  }
  const doc = { label, url: base, when: new Date().toISOString(), tool: 'scripts/mobile-transition-probe.mjs',
    caveat: 'SwiftShader + CPU throttle is a RELATIVE gate only, not a phone.', results, finished: true };
  fs.writeFileSync(jsonOut, JSON.stringify(doc, null, 2));
  say(`wrote ${jsonOut}`);
  printSummary(results);
}

function printSummary(results) {
  console.log('\nSUMMARY');
  for (const r of results) {
    const m = r.metrics || {};
    const keys = Object.keys(m).filter((k) => !k.startsWith('marks') && typeof m[k] !== 'object' && !k.endsWith('_at'));
    console.log(`  ${r.scenario} @${r.throttle}x  reached=${r.reached}${r.why ? ` (${r.why})` : ''}`);
    console.log(`     ${keys.map((k) => `${k}=${m[k]}`).join('  ')}`);
    for (const k of Object.keys(m).filter((x) => x.startsWith('black_') && m[x] && typeof m[x] === 'object')) {
      console.log(`     ${k}: ${m[k].black}/${m[k].samples} black samples, ${m[k].black_ms} ms, min lum ${m[k].min_lum}`);
    }
  }
}

async function runScenario(scn, rate, { base, outDir, lum, runS, say, label, dpr, size }) {
  const browser = await launch();
  const res = { scenario: scn, throttle: rate, label, reached: 'nothing', why: '', metrics: null, notes: [], errors: [] };
  try {
    const { context, page, cdp, mt } = await newProfilePage(browser, 'phone', { hooks: { lum }, dpr, size });
    const con = collectConsole(page, { prefixes: ['[TD]', '[EP2]', '[HARNESS]', '[SceneRouter]', '[Blaze]'], echo: false });
    let crashed = false;
    page.on('crash', () => { crashed = true; });
    const throttle = async (r) => { await cdp.send('Emulation.setCPUThrottlingRate', { rate: r }); say(`CPU throttle ${r}x`); };
    const shot = async (name) => {
      try { await page.screenshot({ path: path.join(outDir, `${label}-${scn}-${rate}x-${name}.png`) }); } catch (_) { /* page busy */ }
    };
    const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
    const find = (re, after = 0) => page.evaluate(([src, a]) => {
      const rx = new RegExp(src);
      for (const e of window.__logT) if (e[0] >= a && rx.test(e[1])) return e;
      return null;
    }, [re.source, after]);
    const findState = (name, after = 0) => page.evaluate(([n, a]) => {
      for (const e of window.__stateT) if (e[0] >= a && e[1] === n) return e[0];
      return null;
    }, [name, after]);
    const waitFor = async (probe, timeoutMs, what) => {
      const end = Date.now() + timeoutMs;
      while (Date.now() < end) {
        if (crashed) throw new Error(`page crashed while waiting for ${what}`);
        const v = await probe();
        if (v) return v;
        await sleep(250);
      }
      return null;
    };
    const stage = (s) => { res.reached = s; say(`reached: ${s}`); };

    // --- URL per scenario ---------------------------------------------------------------------------------------
    const q = {
      A: '?boss=3&bosskill=8&ep2probe=1&debug=beacon',
      B: '?ep2=1&ep2gate=skip&ep2probe=1&debug=beacon',
      C: '?ep2=1&ep2gate=skip&ep2chamber=1&ep2probe=1&debug=beacon',
    }[scn];
    if (!q) throw new Error(`unknown scenario ${scn}`);
    // B and C start their cut within seconds of the engine finishing boot, so the throttle must already be on.
    // A arms a fixed 8 s fuse (bosskill=8) and prints "[HARNESS] bosskill armed": the throttle goes on then.
    if (scn !== 'A' && rate > 1) await throttle(rate);
    const slow = Math.max(1, rate);
    const bootT0 = Date.now();
    await page.goto(base + q, { waitUntil: 'domcontentloaded', timeout: 120000 });
    await page.waitForSelector('canvas', { timeout: 60000 });
    const booted = await waitFor(() => page.evaluate(() => {
      const s = document.getElementById('status');
      const c = document.querySelector('canvas');
      return (!s || getComputedStyle(s).display === 'none') && c && c.width > 0 && !(c.width === 300 && c.height === 150);
    }), 600000 * slow / 2, 'engine boot');
    if (!booted) { res.why = 'engine did not finish booting'; return res; }
    res.boot_s = Math.round((Date.now() - bootT0) / 1000);
    stage(`engine booted in ${res.boot_s}s`);

    const raw = async () => page.evaluate(() => ({
      fr: { gaps: window.__fr.gaps, all: window.__fr.all, n: window.__fr.n, max: window.__fr.max },
      long: window.__long, lum: window.__lum, gmlog: window.__gmLog, mem: window.__mem, stateT: window.__stateT, logT: window.__logT, gm: window.__gm,
    }));
    const finish = async (marks) => {
      const data = await raw();
      res.harness_tag = !!(data.gm && data.gm.harness);
      res.metrics = analyse(scn, data, marks, { runS });
      res.lum_series = (data.lum || []).slice(-1500);
      res.timeline = { states: data.stateT, logs: data.logT.filter(([, t]) => !/^\[EP2\] d=/.test(t)).slice(-120) };
      res.errors = con.errors.slice(0, 20);
      res.beacon_last = data.gm;
      if (!data.gm) res.notes.push('no window.__gm beacon was received (is ?debug=beacon honoured by this build?)');
      else if (!data.gm.harness) res.notes.push('beacon.harness is false: this build does not carry the gm_harness tag');
    };

    // --- A: boss kill -> film -> Episode 2 --------------------------------------------------------------------
    if (scn === 'A') {
      const armed = await waitFor(() => find(/^\[HARNESS\] bosskill armed/), 300000 * slow, 'bosskill fuse');
      if (!armed) {
        res.why = 'no "[HARNESS] bosskill armed" line: the build is not a GM_HARNESS=1 export, or ?boss=3 did not open the arena';
        await finish({}); return res;
      }
      stage('stage-3 arena open, fuse armed');
      await throttle(rate);
      // the thumb: stick centre of the phone-landscape layout, pushed right, and it never lifts
      await mt.down(0, 126, 280);
      await mt.dragTo(0, 176, 280, 4);
      await shot('fight');
      const die = await waitFor(() => find(/^\[HARNESS\] bosskill: /), 60000 * slow, 'boss die()');
      if (!die) { res.why = 'fuse never fired'; await finish({}); return res; }
      const tDie = die[0];
      stage('boss die() called');
      const lc = await waitFor(() => findState('LEVEL_COMPLETE', tDie - 50), 30000 * slow, 'LEVEL_COMPLETE');
      const go = await waitFor(() => findState('TRANSITIONING', tDie), 240000 * slow, 'film end / TransitionDirector.go');
      if (!go) { res.why = 'the film did not end (no TRANSITIONING after die)'; await finish({ die: tDie }); return res; }
      stage('film over, hand-off started');
      await shot('cover');
      const reveal = await waitFor(() => findState('PLAYING', go), 240000 * slow, 'reveal');
      const leg = await waitFor(() => find(/^\[EP2\] leg start/, go - 100), 240000 * slow, 'first runner frame');
      const marks = { die: tDie, levelComplete: lc, go, reveal, leg: leg ? leg[0] : null };
      if (!leg) { res.why = 'Episode 2 never started a runner leg'; await finish(marks); return res; }
      stage('Episode 2 first runner frame');
      await sleep(runS * 1000 + 1500);          // the first 30 s of the runner are measured
      await shot('runner');
      await mt.upAll();
      await finish(marks);
      res.reached = 'Episode 2 runner (first frame + run window)';
      return res;
    }

    // --- B: boot warp -> Episode 2 ----------------------------------------------------------------------------
    if (scn === 'B') {
      const load = await waitFor(() => find(/^\[SceneRouter\] Loading .*ep2_entry|^\[TD\] IDLE->(WARMING|COVERING)/), 120000 * slow, 'swap start');
      const leg = await waitFor(() => find(/^\[EP2\] leg start/), 600000 * slow, 'first runner frame');
      const marks = { load: load ? load[0] : null, leg: leg ? leg[0] : null };
      if (!leg) {
        const code = await find(/^\[EP2\] code prompt/);
        res.why = code ? 'stopped at the access-code prompt: this build ignores ?ep2gate=skip (not a GM_HARNESS=1 export)' : 'no runner leg started';
        res.reached = code ? 'access-code gate' : 'before Episode 2';
        await finish(marks); return res;
      }
      stage('Episode 2 first runner frame');
      await sleep(runS * 1000 + 1500);
      await shot('runner');
      await finish(marks);
      res.reached = 'Episode 2 runner (first frame + run window)';
      return res;
    }

    // --- C: runner -> cliff film -> hideout -------------------------------------------------------------------
    if (scn === 'C') {
      const leg = await waitFor(() => find(/^\[EP2\] leg start/), 600000 * slow, 'runner');
      if (!leg) {
        const code = await find(/^\[EP2\] code prompt/);
        res.why = code ? 'stopped at the access-code prompt (not a GM_HARNESS=1 export)' : 'no runner leg started';
        res.reached = code ? 'access-code gate' : 'before Episode 2';
        await finish({}); return res;
      }
      stage('runner started (8 m)');
      const beat = await waitFor(() => find(/^\[EP2\] chamber beat=/, leg[0]), 300000 * slow, 'chamber entered');
      const marks = { leg: leg[0], chamber: beat ? beat[0] : null };
      // last runner distance line before the chamber
      const lastD = await page.evaluate((cut) => {
        let t = null;
        for (const e of window.__logT) if (e[0] < cut && /^\[EP2\] d=/.test(e[1])) t = e[0];
        return t;
      }, beat ? beat[0] : Infinity);
      marks.runnerEnd = lastD ?? (beat ? beat[0] - 500 : null);
      if (!beat) { res.why = 'the runner never reached the chamber'; await finish(marks); return res; }
      stage('cliff film running');
      await shot('film');
      // film over = the first chamber beat that is not CINEMATIC; the 1 Hz print means the film ended between the two
      const after = await waitFor(() => find(/^\[EP2\] chamber beat=(?!CINEMATIC)/, beat[0]), 420000 * slow, 'hideout (film end)');
      if (!after) { res.why = 'the film did not end inside the timeout'; await finish(marks); return res; }
      const lastCin = await page.evaluate((cut) => {
        let t = null;
        for (const e of window.__logT) if (e[0] < cut && /^\[EP2\] chamber beat=CINEMATIC/.test(e[1])) t = e[0];
        return t;
      }, after[0]);
      marks.filmEndLo = lastCin ?? after[0] - 1000;
      marks.hideout = after[0];
      stage('hideout');
      await sleep(6000);
      await shot('hideout');
      await finish(marks);
      res.reached = 'hideout (first beat after the film)';
      return res;
    }
    return res;
  } finally {
    await browser.close().catch(() => {});
  }
}

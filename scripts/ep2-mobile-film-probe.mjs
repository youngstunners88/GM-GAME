// ep2-mobile-film-probe.mjs - does the cart-exit film play SMOOTHLY on a phone-class CPU? (mobile sprint 2026-11-10)
//
// A non-threaded web build decodes the Theora film, mixes its audio and builds the hideout behind it on ONE thread. Every long
// frame during the film is a frozen picture and a gap in the sound. This probe plays the real film in a phone-profile Chromium
// with the CPU throttled (CDP Emulation.setCPUThrottlingRate) and reports the frame gaps inside the film window.
//
//   GM_HARNESS=1 bash scripts/ep2-local-export.sh          # serves :8899, ?ep2gate=skip works only in this build
//   CHROMIUM_BIN=/usr/bin/chromium node scripts/ep2-mobile-film-probe.mjs [throttle=4] [outdir=.farm/filmprobe]
//
// Output: one FILM_PROBE line per run + the 12 worst gaps with their film-relative time, and <outdir>/gaps-<throttle>.json.
// A Chromium CPU throttle is not a phone: it has no thermal limit and a desktop GPU path. It ranks causes; a device confirms.
import fs from 'node:fs';
import { launch, newProfilePage } from './lib/pw.mjs';

const throttle = Number(process.argv[2] || 4);
const out = process.argv[3] || '.farm/filmprobe';
const base = process.env.GM_URL || 'http://localhost:8899/game/index.html';
fs.mkdirSync(out, { recursive: true });

const browser = await launch({ headless: true, args: ['--autoplay-policy=no-user-gesture-required'] });
const { page, cdp } = await newProfilePage(browser, 'phone', { dpr: 1 });
const lines = [];
let filmStart = -1;       // page clock (ms) of the first CINEMATIC beat line
let filmEnd = -1;         // ...and of the film's own "finished" line
let summary = '';
page.on('console', (m) => {
  const t = m.text();
  lines.push(t);
  if (/\[VIDEO\]/.test(t)) console.log('  ' + t.slice(0, 200));
});
page.on('pageerror', (e) => console.log('PAGEERROR ' + String(e).slice(0, 200)));
// ep2chamber=1 shortens the runner to a few metres (the film follows in seconds); ep2bot=1 rides it; ep2probe=1 prints the beat.
await page.goto(`${base}?ep2=1&ep2gate=skip&ep2probe=1&ep2bot=1&ep2chamber=1&debug=beacon`);   // beacon: the build prints its stages
const t0 = Date.now();
const has = (re) => lines.some((l) => re.test(l));
while (!has(/\[EP2\] leg start/) && Date.now() - t0 < 300000) await page.waitForTimeout(200);
if (!has(/\[EP2\] leg start/)) { console.log('FILM_PROBE FAIL the runner never started (is this a GM_HARNESS build?)'); await browser.close(); process.exit(2); }
await page.touchscreen.tap(422, 120);                                  // a first touch: audio unlock, as on a phone
while (!has(/chamber beat=CINEMATIC/) && Date.now() - t0 < 420000) await page.waitForTimeout(100);
if (!has(/chamber beat=CINEMATIC/)) { console.log('FILM_PROBE FAIL the film beat never came'); await browser.close(); process.exit(2); }
filmStart = await page.evaluate(() => { window.__fr.all = []; return performance.now(); });   // the recorder keeps 40000 frames: start clean
await cdp.send('Emulation.setCPUThrottlingRate', { rate: throttle });  // the phone-class CPU, for the film only
const tFilm = Date.now();
while (!has(/\[VIDEO\] Ep2 film: finished at clock/) && Date.now() - tFilm < 240000) await page.waitForTimeout(250);
filmEnd = await page.evaluate(() => performance.now());
summary = lines.filter((l) => /\[VIDEO\]/.test(l)).join(' | ').slice(0, 400);
await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
const fr = await page.evaluate(() => window.__fr);
const logT = await page.evaluate(() => window.__logT || []);
await browser.close();

const inFilm = (fr.all || []).filter(([t]) => t >= filmStart && t <= filmEnd);
const gaps = inFilm.map(([t, dt]) => [Math.round((t - filmStart) / 100) / 10, Math.round(dt)]);
const over = (ms) => gaps.filter(([, dt]) => dt > ms).length;
const lost = gaps.reduce((s, [, dt]) => s + Math.max(0, dt - 42), 0);  // time the picture stood still beyond one film frame (24 fps)
const worst = gaps.slice().sort((a, b) => b[1] - a[1]).slice(0, 12);
const real = (filmEnd - filmStart) / 1000;
fs.writeFileSync(`${out}/gaps-${throttle}.json`, JSON.stringify({ throttle, real, gaps, summary }, null, 0));
console.log(`FILM_PROBE throttle=${throttle}x real=${real.toFixed(1)}s frames=${gaps.length} avg_fps=${(gaps.length / real).toFixed(1)} ` +
  `gaps>50ms=${over(50)} >100ms=${over(100)} >250ms=${over(250)} >500ms=${over(500)} worst=${worst[0] ? worst[0][1] : 0}ms frozen_total=${(lost / 1000).toFixed(1)}s`);
console.log('  worst gaps [film s, ms]: ' + JSON.stringify(worst));
// where in the film the long frames fall, in 5 s buckets (the hideout is built from film second 3)
const buckets = {};
for (const [t, dt] of gaps) if (dt > 100) { const b = Math.floor(t / 5) * 5; buckets[b] = (buckets[b] || 0) + 1; }
console.log('  gaps >100 ms per 5 s of film: ' + JSON.stringify(buckets));
// what the engine was doing: the hideout's build stages (engine ms between marks = that stage's own frame) and the extras pack
const marks = lines.filter((l) => /hideout build:/.test(l)).map((l) => { const m = l.match(/build: (.+) @(\d+)/); return m ? [m[1], Number(m[2])] : null; }).filter(Boolean);
const stages = marks.map(([name, t], i) => [name, i ? t - marks[i - 1][1] : 0]).filter(([, d]) => d >= 30).sort((a, b) => b[1] - a[1]).slice(0, 14);
console.log('  build stages >= 30 ms (engine ms since the previous mark, includes the frame it waited): ' + JSON.stringify(stages));
const inWin = logT.filter(([t, text]) => t >= filmStart - 2000 && t <= filmEnd && /extras|hideout build: (shell begin|room ready)/.test(text)).map(([t, text]) => [Math.round((t - filmStart) / 100) / 10, text.slice(0, 60)]);
console.log('  marks [film s]: ' + JSON.stringify(inWin));
console.log('  ' + (lines.find((l) => /hideout warm:/.test(l)) || 'no hideout warm line (warm-up not run)'));

#!/usr/bin/env node
/**
 * FPS FEEL SIMULATION (skill ep2-fps-shooter-feel, founder 2026-10-04).
 *
 * The founder asked for Jev to "play shooter games" so the Winchester handles like Modern Warfare. Jev is a
 * text-only DECISIONS model: it cannot play, watch or see anything. What it CAN do is rank options from numbers.
 * So the honest version of that request is this file: a seeded bot-player runs the real target-practice drill
 * (three plates at 5.8 / 8.8 / 11.8 m, plate radius 0.34 m) against three candidate weapon-handling profiles,
 * and the measured outcomes go to Jev as `state`. The profiles' shapes come from what Infinity Ward and the
 * wider genre document (ADS narrows spread and FOV and costs a short transition, tactical/ADS reloads, a fire
 * cycle for lever and bolt guns, view kick that recovers); the numbers are ours.
 *
 *   node tools/ep2_sim/fps_feel_sim.mjs            # simulate, print the table, write docs/ep2_fps_feel_simulation.json
 *   node tools/ep2_sim/fps_feel_sim.mjs --jev      # also ask Jev (needs OPENROUTER_API_KEY in the environment)
 */
import { writeFileSync, mkdirSync } from 'node:fs';
import { evaluate, decide } from '../../scripts/jev.mjs';

// --- seeded RNG so the table is reproducible -----------------------------------------------------------
let seed = 20261004;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const gauss = () => Math.sqrt(-2 * Math.log(rnd() + 1e-12)) * Math.cos(2 * Math.PI * rnd());

const PLATES = [5.8, 8.8, 11.8];          // metres from the firing line
const PLATE_R = 0.34;
const DEG = Math.PI / 180;

/** Candidate weapon-handling profiles. */
const PROFILES = {
  arcade_current: {
    note: 'what shipped: fire at will from the hip, a 0.7 m forgiving tolerance, 1.2 deg aim jitter, no ADS, no cycle, no reload',
    ads: false, hipSigmaDeg: 1.2, tolM: 0.7, fireInterval: 0.05, kickDeg: 0.0, magazine: 99, reloadPerShell: 0,
    adsTime: 0, adsSigmaDeg: 0,
  },
  cod_lever: {
    note: 'Modern-Warfare-style lever action: hip is loose, ADS is tight, 0.24 s ADS, 0.65 s lever cycle, shell-by-shell reload',
    ads: true, hipSigmaDeg: 2.6, tolM: 0.34, adsSigmaDeg: 0.62, adsTime: 0.24, fireInterval: 0.65, kickDeg: 2.0,
    kickRecoverS: 0.32, magazine: 4, reloadPerShell: 0.5,
  },
  heavy_realism: {
    note: 'slower and heavier: 0.38 s ADS, 1.0 s cycle, 4.0 deg kick, 0.7 s per shell',
    ads: true, hipSigmaDeg: 3.4, tolM: 0.34, adsSigmaDeg: 0.75, adsTime: 0.38, fireInterval: 1.0, kickDeg: 4.0,
    kickRecoverS: 0.55, magazine: 4, reloadPerShell: 0.7,
  },
};

/** One shot's miss distance at the plate, in metres, for a bot that aims at the plate centre. */
function shotMiss(p, dist, useAds, settled, sinceShot) {
  const sigma = (useAds ? p.adsSigmaDeg : p.hipSigmaDeg) * DEG;
  // kick not yet recovered adds error; an unsettled ADS (just raised) adds a flinch
  const kickLeft = Math.max(0, 1 - sinceShot / (p.kickRecoverS || 1)) * (p.kickDeg || 0) * DEG * 0.5;
  const flinch = useAds && !settled ? 0.6 * DEG : 0;
  const ang = Math.hypot(gauss() * sigma, gauss() * sigma) + kickLeft + flinch;
  return Math.tan(ang) * dist;
}

/** Human-ish bot: reaction 0.35 s + acquire 0.25 s per plate; ADS users raise the sights when the plate is far. */
function runDrill(p, strategy) {
  let t = 0, shots = 0, hits = 0;
  let sinceShot = 9, loaded = p.magazine;
  for (const dist of PLATES) {
    t += 0.35 + 0.25 + dist * 0.02;                   // react + acquire (farther plates take longer to settle on)
    const useAds = p.ads && (strategy === 'ads' || (strategy === 'mixed' && dist > 6));
    if (useAds) t += p.adsTime;
    let settled = !useAds; let wait = 0;
    for (let tries = 0; tries < 12; tries++) {
      if (loaded === 0) { const n = p.magazine; t += n * p.reloadPerShell; loaded = n; }
      if (useAds && !settled) { t += 0.12; settled = true; }
      t += Math.max(p.fireInterval - sinceShot, 0);   // the lever must be cycled
      shots++; loaded--; sinceShot = 0;
      const miss = shotMiss(p, dist, useAds, settled, 0.0);
      if (miss <= p.tolM) { hits++; break; }
      sinceShot = 0; t += 0.18;                       // re-aim after a miss
    }
    sinceShot = p.fireInterval;
  }
  return { t, shots, hits };
}

function simulate(name, p, strategy, n = 4000) {
  let tt = 0, ss = 0;
  for (let i = 0; i < n; i++) { const r = runDrill(p, strategy); tt += r.t; ss += r.shots; }
  // single-shot hit rates by distance
  const hit = {};
  for (const d of PLATES) {
    let h = 0;
    for (let i = 0; i < n; i++) h += shotMiss(p, d, strategy !== 'hip' && p.ads, true, 9) <= p.tolM ? 1 : 0;
    hit[d] = h / n;
  }
  return { profile: name, strategy, timeToClearS: +(tt / n).toFixed(2), shotsPerDrill: +(ss / n).toFixed(2),
    hitRate: Object.fromEntries(Object.entries(hit).map(([k, v]) => [k, +v.toFixed(2)])) };
}

const rows = [];
for (const [name, p] of Object.entries(PROFILES)) {
  rows.push(simulate(name, p, 'hip'));
  if (p.ads) { rows.push(simulate(name, p, 'ads')); rows.push(simulate(name, p, 'mixed')); }
}
console.log('profile'.padEnd(16), 'style'.padEnd(6), 'clear s'.padEnd(8), 'shots'.padEnd(6), 'hit@5.8'.padEnd(8), 'hit@8.8'.padEnd(8), 'hit@11.8');
for (const r of rows) console.log(r.profile.padEnd(16), r.strategy.padEnd(6), String(r.timeToClearS).padEnd(8), String(r.shotsPerDrill).padEnd(6),
  String(r.hitRate['5.8']).padEnd(8), String(r.hitRate['8.8']).padEnd(8), String(r.hitRate['11.8']));

mkdirSync('docs', { recursive: true });
const out = { generated: new Date().toISOString().slice(0, 10), plates: PLATES, plateRadius: PLATE_R, profiles: PROFILES, rows };

if (process.argv.includes('--jev')) {
  const by = (n, s) => rows.find((r) => r.profile === n && r.strategy === s);
  const cod = by('cod_lever', 'ads'), codHip = by('cod_lever', 'hip'), heavy = by('heavy_realism', 'ads'), arc = by('arcade_current', 'hip');
  const state = [
    'Seeded bot-player simulation of a 3-plate rifle practice drill (plates at 5.8, 8.8 and 11.8 m, 0.34 m radius), 4000 runs per row.',
    'This is a first-person Western shooter tutorial; the founder wants Modern Warfare-style weapon handling: aim-down-sights, a lever cycle, shell-by-shell reload, view kick.',
    `Profile arcade_current (hip fire, forgiving 0.7 m cone, no ADS, no cycle): clears in ${arc.timeToClearS}s, ${arc.shotsPerDrill} shots, hit rate ${JSON.stringify(arc.hitRate)}.`,
    `Profile cod_lever, ADS: clears in ${cod.timeToClearS}s, ${cod.shotsPerDrill} shots, hit rate ${JSON.stringify(cod.hitRate)}.`,
    `Profile cod_lever, hip only: clears in ${codHip.timeToClearS}s, ${codHip.shotsPerDrill} shots, hit rate ${JSON.stringify(codHip.hitRate)}.`,
    `Profile heavy_realism, ADS: clears in ${heavy.timeToClearS}s, ${heavy.shotsPerDrill} shots, hit rate ${JSON.stringify(heavy.hitRate)}.`,
    'Design intent: ADS must be clearly worth using at range (the tutorial teaches it), the drill must stay under ~40 s so the lesson is not a chore, and hip fire must still work at the near plate.',
  ].join(' ');
  const questions = {
    ads_worth_it: { type: 'noul', instructions: 'Based only on these numbers, is aiming down sights at the far plate clearly worth it for cod_lever, i.e. does ADS beat hip-only by at least 0.25 absolute hit rate at 11.8 m?' },
    hip_usable_near: { type: 'noul', instructions: 'Based only on these numbers, is hip fire at the near plate (5.8 m) still usable for cod_lever, i.e. a hit rate of at least 0.5?' },
    drill_not_a_chore: { type: 'noul', instructions: 'Based only on these numbers, does the cod_lever ADS drill clear in under 40 seconds?' },
    profile: {
      type: 'choice',
      instructions: 'Which weapon-handling profile should ship for the Winchester tutorial, given the design intent?',
      criteria: {
        arcade_current: 'Keep the forgiving hip-fire cone; no ADS.',
        cod_lever: 'Modern-Warfare-style lever action: tight ADS, loose hip, 0.65 s cycle, shell reload.',
        heavy_realism: 'Slower, heavier realism with a 1.0 s cycle and 4 degree kick.',
      },
    },
  };
  const res = await evaluate({ state, questions });
  out.jev = { model: res.model, cost: res.usage?.cost ?? null, answers: res.answers, state };
  console.log(`\nJev (${res.model}, $${(res.usage?.cost ?? 0).toFixed(6)}):`);
  for (const [k, a] of Object.entries(res.answers || {})) {
    if (a.type === 'boolean') console.log(`  ${k}: ${a.probability.toFixed(3)} -> ${decide(a.probability)}`);
    else console.log(`  ${k}: ${a.choice} (confidence ${a.confidence?.toFixed?.(2)}) ${JSON.stringify(a.probabilities)}`);
  }
}
writeFileSync('docs/ep2_fps_feel_simulation.json', JSON.stringify(out, null, 2) + '\n');
console.log('\nwrote docs/ep2_fps_feel_simulation.json');

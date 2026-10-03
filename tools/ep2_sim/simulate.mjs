#!/usr/bin/env node
// Simulation of boss 3 -> Episode 2 hand-off strategies (skill ep2-seamless-transition + jev-decision-gate).
// Inputs: constants MEASURED by tools/ep2_sim/handoff_probe.tscn (software GL, pessimistic but relative).
// Output: per-strategy numbers, then a Jev choice on THE NUMBERS (Jev is text-only; never pass it pictures).
//   node tools/ep2_sim/simulate.mjs [--jev]
import { execFileSync } from 'node:child_process';

const M = {                       // seconds, measured 2026-10-03
  late_scripts: 0.50,             // ep2_entry.gd + runner compile (453 ms measured as one stall)
  add_child_ready: 0.32,          // ep2_entry _ready builds the runner view
  first_draw_cold: 1.10,          // worst frame after add_child, no GPU warm-up (1.05-1.16)
  first_draw_warm: 0.65,          // same after drawing 34 models once while the film played (0.65)
  cover_fade: 0.22, min_card: 0.55, reveal: 0.55, dissolve: 0.60,
};
const S = {
  'A_black_card_current': {
    blackSeconds: M.cover_fade + M.late_scripts + M.min_card + M.add_child_ready + M.first_draw_cold + M.reveal,
    frozenContentSeconds: 0, midFilmStallMs: 0, continuity: false, risk: 'low (shipped)',
  },
  'B_freeze_hold_dissolve': {      // keep the film's last frame (Lil Blunt in the cart) up, build behind it, dissolve
    blackSeconds: 0,
    frozenContentSeconds: M.late_scripts + M.add_child_ready + M.first_draw_cold, midFilmStallMs: 0,
    continuity: true, risk: 'low',
  },
  'C_freeze_hold_plus_gpu_warm': { // B + draw every model once during the film (measured -41% on the first draw)
    blackSeconds: 0,
    frozenContentSeconds: M.late_scripts + M.add_child_ready + M.first_draw_warm, midFilmStallMs: 40,
    continuity: true, risk: 'low',
  },
  'D_C_plus_scripts_early': {      // C + compile scripts DURING the film (one ~500 ms blip mid-film) and build the scene
    blackSeconds: 0,               // under the film's last second
    frozenContentSeconds: M.first_draw_warm, midFilmStallMs: Math.round(M.late_scripts * 1000),
    continuity: true, risk: 'medium (one visible blip mid film, runner builds under video)',
  },
  'E_D_plus_dissolve_matched_cart': { // D + the film's final frame already shows the cart from behind (needs a new Seedance bridge shot)
    blackSeconds: 0, frozenContentSeconds: M.first_draw_warm, midFilmStallMs: Math.round(M.late_scripts * 1000),
    continuity: true, risk: 'medium-high (new video, $0.75-1.5, 1 more day)',
  },
};
for (const [k, v] of Object.entries(S)) {
  console.log(`${k.padEnd(34)} black=${v.blackSeconds.toFixed(2)}s  frozen_on_content=${v.frozenContentSeconds.toFixed(2)}s  mid_film_stall=${v.midFilmStallMs}ms  continuity=${v.continuity}  risk=${v.risk}`);
}
if (process.argv.includes('--jev')) {
  const state = 'Founder requirement: after the Stage 3 boss video (Lil Blunt in the mine cart) the player must be IN the mine cart in gameplay straight away, no black screen, no loading card. Measured on software GL (pessimistic, ratios matter): ' +
    Object.entries(S).map(([k, v]) => `${k}: black=${v.blackSeconds.toFixed(2)}s frozen_on_last_video_frame=${v.frozenContentSeconds.toFixed(2)}s mid_film_stall=${v.midFilmStallMs}ms continuity_with_cart=${v.continuity} risk=${v.risk}`).join(' | ');
  const crit = Object.fromEntries(Object.keys(S).map((k) => [k, `Strategy ${k}`]));
  const spec = `best=${Object.keys(S).map((k) => `${k}:${k}`).join('|')}`;
  try {
    const out = execFileSync('node', ['scripts/jev.mjs', '--state', state, '--choice', spec], { encoding: 'utf8' });
    console.log('\nJEV:\n' + out);
  } catch (e) { console.log('\nJEV exit', e.status, '\n' + (e.stdout || '') + (e.stderr || '')); }
}

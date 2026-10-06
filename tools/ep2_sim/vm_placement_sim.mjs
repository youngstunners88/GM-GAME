#!/usr/bin/env node
// Viewmodel PLACEMENT simulation (skill ep2-fps-shooter-feel, founder 2026-10-05: "the rifle is too far forward, it stops the
// gamer seeing the target when they shoulder it ... the gameplay shows the gun tight to the screen ... run the simulation with Jev").
// Real-render rig + per-vertex projection metrics (range_lesson_shot.gd quick=1), a coordinate-descent search against the
// Call of Duty references, then Jev rules on the NUMBERS (text only) between the finalists.
//   node tools/ep2_sim/vm_placement_sim.mjs            -> writes docs/ep2_vm_placement_simulation.json, prints the winner
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
const G = '.godot-cache/Godot_v4.3-stable_linux.x86_64';
function run(c) {
  const vm = [c.hx, c.hy, c.hz, c.scale, c.z, c.drop, c.ads, c.yaw ?? 0.07, c.cy, c.cz].join(',');
  const out = execFileSync('xvfb-run', ['-a', '-s', '-screen 0 960x540x24', G, '--rendering-driver', 'opengl3', '--rendering-method', 'gl_compatibility',
    '--resolution', '960x540', 'res://tools/ep2_shots/range_lesson_shot.tscn', '--', 'out=.farm/vm', 'quick=1', 'vm=' + vm], { encoding: 'utf8', timeout: 120000 });
  const pick = (tag) => { const m = out.match(new RegExp(`VM ${tag} on_screen=([\\d.]+) central=([\\d.]+) upper=([\\d.]+) lower_right=([\\d.]+) bbox=([\\d.-]+),([\\d.-]+),([\\d.-]+),([\\d.-]+) area=([\\d.]+)`));
    if (!m) return null; const n = m.slice(1).map(Number); return { on: n[0], central: n[1], upper: n[2], lr: n[3], x0: n[4], y0: n[5], x1: n[6], y1: n[7], area: n[8] }; };
  const fr = (tag) => { const m = out.match(new RegExp(`VMF ${tag} front_dx=([\\d.-]+) front_dy=([\\d.-]+) near=([\\d.]+)`)); return m ? { fdx: +m[1], fdy: +m[2], near: +m[3] } : { fdx: 9, fdy: 9, near: 1 }; };
  const h = pick('hip'), a = pick('ads'); if (h) Object.assign(h, fr('hip')); if (a) Object.assign(a, fr('ads'));
  return { hip: h, ads: a };
}
const clamp01 = (v) => Math.max(0, Math.min(1, v));
// COD reference targets. ADS (img 1,2): target window clear, body BELOW the sight line, big (tight to the screen), cropped by the bottom edge.
function scoreAds(a) { if (!a) return -99;
  // front post ON the crosshair (a hair below), target window clear, body in the LOWER half, some gun on screen (barrel + hand)
  return -400 * a.near - 30 * Math.abs(a.fdx) - 30 * Math.abs(a.fdy - 0.03) - 40 * a.central - 15 * Math.max(0, a.upper - 0.08)
    - 20 * Math.max(0, 0.18 - a.on) - 6 * Math.max(0, 0.18 - a.area) - 6 * Math.max(0, 0.95 - a.y1); }
// HIP (img 2): low-right, big, cropped by the right and bottom edges, nothing over the target window.
function scoreHip(h) { if (!h) return -99;
  // the muzzle (front sight) must be on screen, right of centre and pointing toward it; most of the gun visible
  const sight = -10 * Math.max(0, Math.abs(h.fdx) > 0.5 ? 1 : 0) - 8 * Math.max(0, 0.04 - h.fdx) - 15 * Math.max(0, 0.5 - h.on);
  return sight -40 * h.central - 6 * Math.max(0, 0.90 - h.lr) - 8 * Math.max(0, 0.22 - h.area) - 4 * Math.max(0, h.area - 0.45)
    - 6 * Math.max(0, 0.97 - h.y1) - 4 * Math.max(0, 0.95 - h.x1) - 8 * Math.max(0, 0.30 - h.x0) - 8 * Math.max(0, 0.42 - h.y0); }
let best = { hx: 0.17, hy: -0.16, hz: -0.5, scale: 0.7, z: -0.15, drop: 0.11, ads: -0.12, yaw: 0.07, cy: 0.18, cz: 0.14 }; best.ads = -0.12;
const log = [];
function evalC(c) { const r = run(c); const s = scoreAds(r.ads) + scoreHip(r.hip); log.push({ c: { ...c }, r, s }); return s; }
let bs = evalC(best); console.log('start', bs.toFixed(2));
const steps = { cy: [0.16, 0.17, 0.19, 0.2, 0.22], cz: [0.04, 0.1, 0.18, 0.24, 0.3], z: [-0.3, -0.15, 0, 0.15], scale: [0.7, 0.9, 1.0, 1.15],
  hx: [0.12, 0.2, 0.27, 0.34], hy: [-0.32, -0.27, -0.16, -0.1], hz: [-0.26, -0.32, -0.38, -0.44], yaw: [-0.05, 0.0, 0.15, 0.25] };
for (let pass = 0; pass < 2; pass++) for (const k of Object.keys(steps)) {
  for (const v of steps[k]) { const c = { ...best, [k]: v }; const s = evalC(c); if (s > bs + 1e-6) { bs = s; best = c; console.log(`pass ${pass} ${k}=${v} -> ${s.toFixed(2)}`); } }
}
const finalists = log.slice().sort((a, b) => b.s - a.s).slice(0, 3);
writeFileSync('docs/ep2_vm_placement_simulation.json', JSON.stringify({ best, bs, finalists, runs: log.length, log }, null, 1));
console.log('BEST', JSON.stringify(best), bs.toFixed(2), 'runs', log.length);
console.log(JSON.stringify(finalists.map(f => ({ c: f.c, s: f.s, ads: f.r.ads, hip: f.r.hip })), null, 1));

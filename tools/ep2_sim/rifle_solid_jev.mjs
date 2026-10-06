#!/usr/bin/env node
// Jev (text-only) rules on the NUMBERS of the rifle-solidity ray audit (tools/ep2_blender/rifle_export_game.py --rays).
//   node tools/ep2_sim/rifle_solid_jev.mjs <before.log> <after.log>
import { readFileSync } from 'node:fs';
import { evaluate, decide } from '../../scripts/jev.mjs';
const stats = (f) => { const L = readFileSync(f, 'utf8').split('\n').filter(l => /\bray \d+ \d+/.test(l));
  const hits = L.filter(l => /hit mat/.test(l)); const back = hits.filter(l => parseFloat(l.match(/n\.d (-?[\d.]+)/)[1]) > 0.05);
  const near = hits.filter(l => parseFloat(l.match(/dist ([\d.]+)/)[1]) < 0.05);
  return { rays: L.length, hits: hits.length, back: back.length, near: near.length, miss: L.length - hits.length }; };
const b = stats(process.argv[2]), a = stats(process.argv[3]);
const state = `Rifle solidity audit, 15 rays fired from the shouldered eye across the lower screen. BEFORE: ${b.hits} hits, of which ${b.back} hit the BACK of a surface (the camera sees the inside of an open shell) and ${b.near} hit geometry closer than 5 cm to the lens. AFTER: ${a.hits} hits, ${a.back} back-face hits, ${a.near} closer than 5 cm; ${a.miss} rays pass clear (the target window).`;
const res = await evaluate({ state, questions: {
  has_inside_view: { type: 'noul', instructions: 'After the change, does the shouldered camera still see the inside of open shells (any back-face hits)?' },
  has_lens_clipping: { type: 'noul', instructions: 'After the change, is any rifle geometry closer than 5 cm to the lens?' },
  verdict: { type: 'choice', instructions: 'Is the rifle solid when shouldered?', criteria: { ship: 'No back-face hits, no lens clipping, target window clear.', block: 'Back faces visible or geometry at the lens.' } } } });
let block = false;
for (const [k, an] of Object.entries(res.answers)) {
  if (an.type === 'boolean') { const d = decide(an.probability); console.log(`  ${k}: ${an.probability.toFixed(3)} -> ${d}`); if (d === 'yes') block = true; }
  else { console.log(`  ${k}: ${an.choice}`); if (an.choice !== 'ship') block = true; }
}
console.log(`before=${JSON.stringify(b)} after=${JSON.stringify(a)}`); console.log(block ? 'JEV: BLOCK' : 'JEV: SHIP'); process.exit(block ? 1 : 0);

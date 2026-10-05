#!/usr/bin/env node
// Jev (text-only) rules on the NUMBERS of the winning viewmodel placement (docs/ep2_vm_placement_simulation.json).
import { readFileSync } from 'node:fs';
import { evaluate, decide } from '../../scripts/jev.mjs';
const d = JSON.parse(readFileSync('docs/ep2_vm_placement_simulation.json', 'utf8'));
const f = d.finalists[0].r, c = d.best;
const state = `First-person rifle placement chosen by a ${d.runs}-run real-render search against Call of Duty references. ` +
  `SHOULDERED (aim-down-sights): front sight is ${(100*f.ads.fdx).toFixed(1)} percent of frame width off the crosshair horizontally and ${(100*f.ads.fdy).toFixed(1)} percent below it; ` +
  `${(100*f.ads.central).toFixed(2)} percent of the visible gun vertices sit in the target window (at and just above the crosshair); ${(100*f.ads.upper).toFixed(1)} percent of the gun is above the sight line; the gun bounding box reaches y=${f.ads.y1.toFixed(2)} of the frame height (bottom edge). ` +
  `HIP: gun covers ${(100*f.hip.area).toFixed(0)} percent of the frame, ${(100*f.hip.lr).toFixed(0)} percent of it in the lower-right quadrant, target window occupancy ${(100*f.hip.central).toFixed(2)} percent, box x ${f.hip.x0.toFixed(2)}-${f.hip.x1.toFixed(2)} y ${f.hip.y0.toFixed(2)}-${f.hip.y1.toFixed(2)}. ` +
  `Previous shipped placement had 42 percent of the gun in the target window when shouldered.`;
const res = await evaluate({ state, questions: {
  has_blocked_target_view: { type: 'noul', instructions: 'When shouldered, does the gun block the player view of the target (more than 3 percent of the gun inside the target window)?' },
  has_misaligned_sight: { type: 'noul', instructions: 'Is the front sight more than 3 percent of the frame width away from the crosshair horizontally?' },
  verdict: { type: 'choice', instructions: 'Should this placement replace the shipped one?', criteria: { ship: 'Target window clear when shouldered, sight on the crosshair, gun low and tight to the right at the hip.', block: 'Gun blocks the target or the sight is misaligned.' } },
} });
let block = false;
for (const [k, a] of Object.entries(res.answers)) {
  if (a.type === 'boolean') { const dd = decide(a.probability); console.log(`  ${k}: ${a.probability.toFixed(3)} -> ${dd}`); if (dd === 'yes') block = true; }
  else { console.log(`  ${k}: ${a.choice}`); if (a.choice !== 'ship') block = true; }
}
console.log(block ? 'JEV: BLOCK' : 'JEV: SHIP'); console.log('placement', JSON.stringify(c));
process.exit(block ? 1 : 0);

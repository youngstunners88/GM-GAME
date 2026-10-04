#!/usr/bin/env node
// Jev rules on the NUMBERS from the range-lesson render rig (skill ep2-gauntlet-loop). Jev is text-only: it never sees
// the pictures; the lead looks at them. Usage: node range_gauntlet_jev.mjs <rig-log.txt>. Exit 0 ship, 1 block, 2 uncertain.
import { readFileSync } from 'node:fs';
import { evaluate, decide } from '../../scripts/jev.mjs';
const log = readFileSync(process.argv[2], 'utf8');
const num = (re) => { const m = log.match(re); return m ? parseFloat(m[1]) : NaN; };
const stages = (log.match(/^SHOT /gm) || []).length;
const adsOff = num(/ads_sight_offset_px=([\d.]+)/), frameW = num(/ads_sight_offset_px=[\d.]+ \(of a (\d+)x/);
const hipX = num(/hip_rifle_centre_x=([\d.]+)/), hipY = num(/hip_rifle_centre_y=|hip_rifle_centre_x=[\d.]+ y=([\d.]+)/);
const hipYv = num(/hip_rifle_centre_x=[\d.]+ y=([\d.]+)/);
const state = `Real-render capture of a first-person rifle lesson. Lesson stages captured: ${stages} of 15 expected. ` +
  `Aim-down-sights: the rifle's sight is ${adsOff.toFixed(1)} px from the crosshair on a ${frameW} px wide frame (${(100 * adsOff / frameW).toFixed(2)} percent). ` +
  `Hip: the rifle centre sits at x=${hipX} y=${hipYv} as fractions of the frame (Modern Warfare carries low and right: x>0.55, y>0.65).`;
const res = await evaluate({ state, questions: {
  has_misaligned_sight: { type: 'noul', instructions: 'Is the ADS sight more than 3 percent of the frame width away from the crosshair?' },
  has_wrong_hip_position: { type: 'noul', instructions: 'Is the hip rifle centre NOT low and right (x above 0.55 and y above 0.65)?' },
  has_missing_stages: { type: 'noul', instructions: 'Were fewer than 15 lesson stages captured?' },
  verdict: { type: 'choice', instructions: 'Should this weapon-handling build ship?', criteria: { ship: 'All stages captured, sight aligned, hip carry low-right.', block: 'Any metric fails.' } } } });
let block = false, unc = false;
for (const [k, a] of Object.entries(res.answers)) {
  if (a.type === 'boolean') { const d = decide(a.probability); console.log(`  ${k}: ${a.probability.toFixed(3)} -> ${d}`); if (k.startsWith('has_')) { if (d === 'yes') block = true; else if (d === 'uncertain') unc = true; } }
  else { console.log(`  ${k}: ${a.choice}`); if (a.choice !== 'ship') block = true; }
}
console.log(block ? 'JEV: BLOCK' : unc ? 'JEV: UNCERTAIN' : 'JEV: SHIP');
process.exit(block ? 1 : unc ? 2 : 0);

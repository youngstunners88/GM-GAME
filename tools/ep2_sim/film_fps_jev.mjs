#!/usr/bin/env node
// Jev (text-only) rules on the film-playback NUMBERS from tools/ep2_shots/film_fps_probe.tscn (before = 3D on, after = 3D off).
//   node tools/ep2_sim/film_fps_jev.mjs "<FILMFPS line before>" "<FILMFPS line after>"
import { evaluate, decide } from '../../scripts/jev.mjs';
const num = (l, k) => parseFloat(l.match(new RegExp(k + '=([\\d.]+)'))[1]);
const [b, a] = [process.argv[2], process.argv[3]];
const state = `Founder film playback on a software-rendered (weak-GPU stand-in) real render, 16 s window with the hideout being built behind the film. ` +
  `BEFORE (3D pass still rendering behind the full-screen film): render ${num(b,'render_fps')} fps, ${num(b,'picture_updates')} picture updates, worst gap between decoded frames ${num(b,'worst_gap_ms')} ms. ` +
  `AFTER (3D pass disabled while the film plays): render ${num(a,'render_fps')} fps, ${num(a,'picture_updates')} picture updates, worst gap ${num(a,'worst_gap_ms')} ms. A film below 20 fps or with a gap over 500 ms reads as a slideshow or a frozen video.`;
const res = await evaluate({ state, questions: {
  has_slideshow_after: { type: 'noul', instructions: 'After the change, does the film still play below 20 fps or freeze for more than 500 ms?' },
  has_regression: { type: 'noul', instructions: 'Is the AFTER playback worse than BEFORE on any number?' },
  verdict: { type: 'choice', instructions: 'Should the change (disable the 3D pass while the film plays) ship?', criteria: { ship: 'Film plays smoothly, no gap over 500 ms, better than before.', block: 'Still a slideshow or worse than before.' } } } });
let block = false;
for (const [k, an] of Object.entries(res.answers)) {
  if (an.type === 'boolean') { const d = decide(an.probability); console.log(`  ${k}: ${an.probability.toFixed(3)} -> ${d}`); if (d === 'yes') block = true; }
  else { console.log(`  ${k}: ${an.choice}`); if (an.choice !== 'ship') block = true; }
}
console.log(block ? 'JEV: BLOCK' : 'JEV: SHIP'); process.exit(block ? 1 : 0);

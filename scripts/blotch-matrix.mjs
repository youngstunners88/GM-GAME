// blotch-matrix.mjs — capture EVERY scene the founder grades, in one pass.
//
// The founder's 2026-09-22 report is a labelled test set:
//   L1 stage DIRTY | L1 blaze DIRTY | L2 stage DIRTY
//   L2 blaze CLEAN | L3 stage DIRTY | L3 blaze DIRTY
// A detector that does not reproduce that matrix is not calibrated, whatever
// it scores on a single frame. L2 blaze is the load-bearing negative: any
// theory that blames the GPU, the monitor or the screenshot tool has to
// explain why exactly one scene is exempt, and none of them can.
import { chromium } from 'playwright';
import fs from 'fs';

const OUT = process.env.OUT || 'artifacts/blotch-matrix';
fs.mkdirSync(OUT, { recursive: true });
const PIN = ['/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
             '/opt/pw-browsers/chromium/chrome-linux/chrome'];
const opts = { args: ['--use-gl=angle', '--use-angle=swiftshader',
  '--enable-unsafe-swiftshader', '--disable-dev-shm-usage', '--no-sandbox',
  '--ignore-certificate-errors'] };
for (const p of PIN) if (fs.existsSync(p)) { opts.executablePath = p; break; }

const sleep = ms => new Promise(r => setTimeout(r, ms));
const BASE = process.argv[2];
if (!BASE) { console.error('usage: blotch-matrix.mjs <game-index-url> [w] [h]'); process.exit(2); }
// Default to the founder's own window, not 1280x720: his canvas is upscaled
// and any theory about resampling has to be tested at HIS size to mean anything.
const W = Number(process.argv[3] || 1496), H = Number(process.argv[4] || 847);

const SCENES = [
  ['l1_stage', 'stage=1'], ['l1_blaze', 'blaze=1'],
  ['l2_stage', 'stage=2'], ['l2_blaze', 'blaze=2'],
  ['l3_stage', 'stage=3'], ['l3_blaze', 'blaze=3'],
];

const b = await chromium.launch(opts);
for (const [name, q] of SCENES) {
  const ctx = await b.newContext({ viewport: { width: W, height: H }, ignoreHTTPSErrors: true });
  const pg = await ctx.newPage();
  try {
    await pg.goto(`${BASE}?v=${Date.now()}&${q}`, { waitUntil: 'domcontentloaded', timeout: 120000 });
    await pg.waitForSelector('canvas', { timeout: 120000 });
    await pg.waitForFunction(() => { const c = document.querySelector('canvas'); return c && c.width > 100 && c.height > 100; }, { timeout: 180000 });
    // Settle: parallax layers and particle fields need a beat to reach steady state.
    await sleep(7000);
    await pg.screenshot({ path: `${OUT}/${name}.png` });
    console.log('captured', name);
  } catch (e) { console.log('FAIL', name, e.message.slice(0, 80)); }
  await ctx.close();
}
await b.close();
console.log('DONE ->', OUT);

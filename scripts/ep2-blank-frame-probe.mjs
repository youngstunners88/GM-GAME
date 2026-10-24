// ep2-blank-frame-probe.mjs — sample the runner's on-screen brightness against track distance in
// the REAL web build (served by scripts/ep2-local-export.sh on :8899). Many consecutive frames with
// an IDENTICAL mean = the 3D pass is missing (HUD over clear colour), not "dark art" — that is how
// the >1000-instance blank (docs/research/3d/001) was measured. Usage:
//   node scripts/ep2-blank-frame-probe.mjs ["&ep2off=gold,streaks" | "&ep2bot=1"]
import { chromium } from './lib/pw.mjs';
const q = process.argv[2] || '';
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 640, height: 360 } });
let d = -1, leg = -1, last = '';
page.on('console', m => { const t = m.text(); let r = t.match(/\[EP2\] leg start (\d+)/); if (r) leg = +r[1];
  r = t.match(/\[EP2\] d=(\d+) hp=(\d+)(.*)/); if (r) { d = +r[1]; last = r[3]; } });
await page.goto('http://localhost:8899/game/index.html?ep2=1&ep2probe=1' + q);
const t0 = Date.now(); while (leg < 0 && Date.now() - t0 < 240000) await page.waitForTimeout(50);   // ?ep2=1 now runs through the TransitionDirector (card + warm-up + reveal) first
const tRun = Date.now();
await page.mouse.click(320, 180);
const rows = [];
while (d < +(process.env.PROBE_TO || 220) && Date.now() - tRun < 300000) {
  const d0 = d;
  const buf = await page.screenshot({ clip: { x: 0, y: 120, width: 640, height: 200 } });
  const mean = await page.evaluate(async (b64) => { const img = new Image(); img.src = 'data:image/png;base64,' + b64; await img.decode();
    const c = document.createElement('canvas'); c.width = img.width; c.height = img.height; const x = c.getContext('2d'); x.drawImage(img, 0, 0);
    const p = x.getImageData(0, 0, c.width, c.height).data; let s = 0; for (let i = 0; i < p.length; i += 4) s += p[i] + p[i+1] + p[i+2]; return s / (p.length / 4) / 3; }, buf.toString('base64'));
  rows.push(`d ${d0}->${d} mean=${mean.toFixed(1)} ${last}`);
}
console.log(rows.join('\n'));
await browser.close();

// ep2-film-web-probe.mjs - does the founder's film actually PLAY in the real web build?
// Needs scripts/ep2-local-export.sh to have served :8899. Runs the bot to the cart end, then logs every console line
// that mentions the film/video/errors and samples screenshots (mean brightness + saved png) for 150 s of the film window.
//   node scripts/ep2-film-web-probe.mjs .farm/filmweb ["&extra=query"]
import { chromium } from 'playwright';
import fs from 'node:fs';
const out = process.argv[2] || '.farm/filmweb'; const q = process.argv[3] || '';
fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
const page = await browser.newPage({ viewport: { width: 640, height: 360 } });
const lines = []; let leg = -1, d = -1;
page.on('console', m => { const t = m.text(); lines.push(t);
  let r = t.match(/\[EP2\] leg start (\d+)/); if (r) leg = +r[1];
  r = t.match(/\[EP2\] d=(\d+)/); if (r) d = +r[1];
  if (/film|video|theora|ogv|error|failed/i.test(t) && !/Failed to fetch|CERT/.test(t)) console.log('CONSOLE:', t.slice(0, 200)); });
page.on('pageerror', e => console.log('PAGEERROR:', String(e).slice(0, 300)));
await page.goto('http://localhost:8899/game/index.html?ep2=1&ep2probe=1&ep2bot=1&ep2chamber=1' + q);
const t0 = Date.now();
while (!lines.some(l => l.includes('[EP2] code prompt')) && leg < 0 && Date.now() - t0 < 150000) await page.waitForTimeout(100);
if (leg < 0 && lines.some(l => l.includes('[EP2] code prompt'))) {
  if (!process.env.EP2_CODE) { console.log('access code prompt: set EP2_CODE (local probe builds use a throwaway hash)'); process.exit(2); }
  await page.keyboard.type(process.env.EP2_CODE); await page.keyboard.press('Enter');
}
while (leg < 0 && Date.now() - t0 < 150000) await page.waitForTimeout(100);
console.log('leg started', leg, 'after', ((Date.now() - t0) / 1000).toFixed(0), 's');
await page.mouse.click(320, 180);
let i = 0; let lastMean = -1, same = 0;
while (Date.now() - t0 < 420000) {
  await page.waitForTimeout(4000);
  const buf = await page.screenshot();
  const mean = await page.evaluate(async (b64) => { const img = new Image(); img.src = 'data:image/png;base64,' + b64; await img.decode();
    const c = document.createElement('canvas'); c.width = img.width; c.height = img.height; const x = c.getContext('2d'); x.drawImage(img, 0, 0);
    const p = x.getImageData(0, 0, c.width, c.height).data; let s = 0; for (let k = 0; k < p.length; k += 4) s += p[k] + p[k+1] + p[k+2]; return s / (p.length / 4) / 3; }, buf.toString('base64'));
  fs.writeFileSync(`${out}/s${String(i).padStart(3, '0')}.png`, buf);
  console.log(`t=${((Date.now()-t0)/1000).toFixed(0)}s leg=${leg} d=${d} mean=${mean.toFixed(1)}`);
  i++;
}
await browser.close();

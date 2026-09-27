// ep2-fps-probe.mjs — track-metres per wall-second in the REAL web build over a window of a leg,
// to bisect render cost with ?ep2off= toggles (software Chromium is the slow-device canary).
//   node scripts/ep2-fps-probe.mjs <leg> <from_m> <to_m> ["&ep2off=hero"]
import { chromium } from 'playwright';
const [leg, from, to, extra] = [+process.argv[2], +process.argv[3], +process.argv[4], process.argv[5] || ''];
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
let d = -1, t0 = 0, t1 = 0;
page.on('console', m => { const r = m.text().match(/\[EP2\] d=(\d+)/); if (!r) return; d = +r[1];
  if (d >= from && !t0) t0 = Date.now(); if (d >= to && !t1) t1 = Date.now(); });
await page.goto(`http://localhost:8899/game/index.html?ep2=1&ep2probe=1&ep2bot=1&ep2leg=${leg}${extra}`);
const end = Date.now() + 420000;
while (!t1 && Date.now() < end) await page.waitForTimeout(250);
console.log(`${extra || '(none)'}: ${t1 ? ((to - from) / ((t1 - t0) / 1000)).toFixed(1) + ' m/s wall' : 'DID NOT REACH ' + to + ' (at ' + d + ')'}`);
await browser.close();

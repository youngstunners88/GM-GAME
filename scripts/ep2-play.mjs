import { chromium } from 'playwright';
// Episode 2 browser playtest: drive the real web build by TRACK DISTANCE (not wall-clock,
// which drifts on CPU-rendered browsers). Needs ?ep2probe=1 (ep2_entry.gd prints d/hp).
// Usage: node scripts/ep2-play.mjs <outdir> '<plan json>' [extra-query]  — plan steps:
//   {leg, d, key?|down?|up?|click?:[x,y]|rclick?:[x,y]|move?:[x,y], shot?:name}
const out = process.argv[2], plan = JSON.parse(process.argv[3]);
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
let leg = -1, d = -1, hp = -1; const hpLog = []; const logs = [];
page.on('console', m => { const t = m.text(); logs.push(`[${m.type()}] ${t}`);
  let r = t.match(/\[EP2\] leg start (\d+)/); if (r) { leg = +r[1]; d = 0; }
  r = t.match(/\[EP2\] d=(\d+) hp=(\d+)/); if (r) { const nh = +r[2]; if (hp !== -1 && nh < hp) hpLog.push(`HIT at leg ${leg} d=${r[1]} (${hp}->${nh})`); d = +r[1]; hp = nh; } });
page.on('pageerror', e => logs.push(`[pageerror] ${e.message}`));
await page.goto('http://localhost:8899/game/index.html?ep2=1&ep2probe=1' + (process.argv[4] ? '&' + process.argv[4] : ''));
const until = async (fn, ms) => { const end = Date.now() + ms; while (Date.now() < end) { if (fn()) return true; await page.waitForTimeout(15); } return false; };
await until(() => leg >= 0, 120000);
await page.mouse.click(640, 360);
for (const s of plan) {                      // {leg, d, key?/down?/up?, shot?}
  const ok = await until(() => leg > s.leg || (leg === s.leg && d >= s.d), 180000);
  if (!ok) { console.log('TIMEOUT waiting for', JSON.stringify(s), 'at leg', leg, 'd', d); break; }
  if (s.down) await page.keyboard.down(s.down);
  if (s.up) await page.keyboard.up(s.up);
  if (s.key) await page.keyboard.press(s.key);
  if (s.move) await page.mouse.move(s.move[0], s.move[1]);
  if (s.click) { await page.mouse.move(s.click[0], s.click[1]); await page.mouse.click(s.click[0], s.click[1]); }
  if (s.rclick) await page.mouse.click(s.rclick[0], s.rclick[1], { button: 'right' });
  if (s.shot) await page.screenshot({ path: `${out}/${s.shot}.png` });
  if (s.wait) await page.waitForTimeout(s.wait);
}
const bad = logs.filter(l => /SCRIPT|Parse|pageerror|ERROR:/i.test(l));
console.log('final leg', leg, 'd', d, 'hp', hp, '| script/page errors:', bad.length);
bad.slice(0, 10).forEach(l => console.log('  ', l.slice(0, 200)));
hpLog.forEach(h => console.log('  ', h));
await browser.close();

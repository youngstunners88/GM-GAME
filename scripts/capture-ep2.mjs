#!/usr/bin/env node
// capture-ep2.mjs — real-browser screenshot capture for Episode 2 (Gold Mine).
//
// WHY A DEDICATED CAPTURE SCRIPT
// Episode 2's two worst defects — hazards that were pure data with no mesh, and
// materials so blown out the scene read as white — were both invisible to every
// headless gate and were only ever found by looking at pixels in a real browser.
// The art-direction-fidelity-check skill needs those pixels as a FILE it can
// hand to a vision model, so capturing them has to be one repeatable command,
// not a hand-driven session.
//
// It warps straight in via ?ep2=1 (the test-only query param main_menu.gd
// reads) so a capture never depends on beating three bosses first.
//
// Usage:
//   node scripts/capture-ep2.mjs <base-url> <out-dir> [--chamber]
// e.g.
//   node scripts/capture-ep2.mjs http://localhost:8899/game/index.html artifacts/ep2-shots
//
// Exit 0 = booted with no script errors and every shot written.
import fs from 'fs';
import path from 'path';
import { chromium } from 'playwright';

const URL_BASE = process.argv[2];
const OUT_DIR = process.argv[3] || 'artifacts/ep2-shots';
if (!URL_BASE) {
  console.error('Usage: capture-ep2.mjs <base-url> <out-dir>');
  process.exit(1);
}
fs.mkdirSync(OUT_DIR, { recursive: true });

// --chamber warps straight into the Smelting Facility (Chamber 0). Without it a
// capture of the chamber has to survive 180 m of runner hazards first, which
// makes a failed screenshot ambiguous — runner problem, or chamber problem?
const CHAMBER = process.argv.includes('--chamber');
const url = URL_BASE + (URL_BASE.includes('?') ? '&' : '?') + 'ep2=1' +
  (CHAMBER ? '&ep2chamber=1' : '');
const errors = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// This sandbox ships a pinned Chromium at PLAYWRIGHT_BROWSERS_PATH that will
// NOT match the browser build a freshly-installed playwright package expects
// (1194 on disk vs 1243 wanted, at time of writing). Downloading the matching
// build is explicitly not the fix here — point at the one that exists.
const PINNED = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const launchOpts = {
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
         '--disable-dev-shm-usage', '--no-sandbox'],
};
if (fs.existsSync(PINNED)) launchOpts.executablePath = PINNED;
const browser = await chromium.launch(launchOpts);
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

page.on('console', (m) => {
  const t = m.text();
  // Godot funnels GDScript failures through console text, not JS exceptions, so
  // a page with zero uncaught errors can still be a scene that never ran.
  // Deliberately NOT matching a bare "Failed to load resource": the local dev
  // server resets a connection on favicon/web3.js often enough that it flagged
  // two errors on a run whose GDScript was completely clean. A gate that cries
  // wolf about the harness gets ignored on the run that matters.
  if (/USER SCRIPT ERROR|Parse Error|SCRIPT ERROR|Cannot call method|SharedArrayBuffer|\.pck.*Failed|\.wasm.*Failed/i.test(t)) {
    errors.push(t);
  }
});
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));

console.log('opening', url);
await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
await page.waitForSelector('canvas', { timeout: 120000 });

// Wait for a real boot, not the splash: the canvas leaves its default size.
await page.waitForFunction(() => {
  const c = document.querySelector('canvas');
  return c && c.width > 100 && c.height > 100;
}, { timeout: 180000 });
await sleep(9000);   // engine warm-up + autoloads + scene route

const shots = [];
async function shot(name) {
  const p = path.join(OUT_DIR, name);
  await page.screenshot({ path: p });
  const bytes = fs.statSync(p).size;
  shots.push({ name, bytes });
  console.log(`  shot ${name} (${bytes} B)`);
}

// Focus the canvas explicitly, not just click it. Godot's web build listens
// for keys on the canvas element; the first Chamber 0 capture clicked, looked
// alive (the beat advanced on its own timer) and still ignored every keypress,
// because a click alone had not made the canvas the focused element.
await page.click('canvas', { position: { x: 640, y: 400 } }).catch(() => {});
await page.evaluate(() => {
  const c = document.querySelector('canvas');
  if (c) { c.setAttribute('tabindex', '0'); c.focus(); }
});
await sleep(2500);

if (CHAMBER) {
  // Chamber 0 is a conversation, so the capture has to PLAY it: walk to the
  // Bull, then press E through the beats. A static screenshot of the arrival
  // frame would prove the room loaded and nothing about whether it works.
  await shot('ep2_smelting_arrival.png');

  // Hold D for 14 s, not 4. This capture runs under SwiftShader software
  // rendering, where the chamber measured about 14 fps — a HUD diagnostic
  // showed the walk verb routing correctly (`mode=2 key=D mr=true`) while the
  // player covered only 4.1 m of the 10.8 m he needs, because the whole scene
  // was time-dilated to roughly a quarter speed. The first read of that was
  // "input is broken"; it was the harness being impatient. Real hardware walks
  // it in ~4 s, so the extra wait costs a capture nothing and buys it
  // independence from whatever framerate the sandbox manages.
  await page.keyboard.down('d');
  await sleep(14000);
  await page.keyboard.up('d');
  await sleep(1500);
  await shot('ep2_smelting_meeting.png');   // the drink
  // Line holds are the measured clip durations; tripled here for the same
  // time-dilation reason, and harmless because a beat simply waits.
  for (const wait of [9000, 3000, 12000, 3000]) {
    await page.keyboard.press('e');
    await sleep(wait);
  }
  await shot('ep2_smelting_handoff.png');   // rifle in hand
  for (let i = 0; i < 4; i++) { await page.keyboard.press('Control'); await sleep(1200); }
  await sleep(2000);
  await shot('ep2_smelting_verbteach.png'); // molds broken

  // A capture that silently did nothing looks exactly like a capture that
  // worked, so assert on the pixels: the four chamber shots must not be
  // byte-identical. The first run produced three identical files and that was
  // the only clue the keyboard was being ignored.
  const bytes = shots.filter((s) => s.name.startsWith('ep2_smelting')).map((s) => s.bytes);
  if (new Set(bytes).size < 3) {
    console.error(`\nFAIL — the chamber shots barely differ (${bytes.join(', ')} bytes).`);
    console.error('  The beats did not advance: input is not reaching the canvas.');
    process.exitCode = 1;
  }
} else {
  await shot('ep2_runner_start.png');
  // Let the cart cover ground so hazards, lanterns and the zip cable are in frame.
  await sleep(4000);
  await shot('ep2_runner_mid.png');
  await sleep(4000);
  await shot('ep2_runner_late.png');
}

await browser.close();

fs.writeFileSync(path.join(OUT_DIR, 'capture.json'),
  JSON.stringify({ url, shots, errors, captured: new Date().toISOString() }, null, 2));

if (errors.length) {
  console.error(`\nFAIL — ${errors.length} script error(s):`);
  for (const e of errors.slice(0, 12)) console.error('  ' + e);
  process.exit(1);
}
console.log(`\nOK — ${shots.length} shots in ${OUT_DIR}, 0 script errors`);

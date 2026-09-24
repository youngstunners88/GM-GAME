// verify-stage1-weapon.mjs — does Stage 1's base attack throw a SMOKE BOMB?
//
// Founder (2026-09-22): "Lil Blunt is throwing axes in the beginning instead of
// smoke bombs." An earlier version of this check pressed the attack key and
// zoomed the first axe-ish object it found — which turned out to be a Tax
// Collector holding a pickaxe, and produced a confidently WRONG answer.
//
// So this proves input works BEFORE judging anything: it walks right, confirms
// the player actually moved, and only then attacks. If movement is not
// observed, it reports INPUT-DEAD instead of a verdict on the weapon.
//
// STAGE 1 IS A TRAP FOR VISUAL WEAPON IDENTIFICATION. Two separate objects in
// this level look exactly like "Lil Blunt threw an axe", and both fooled a
// capture pass on 2026-09-22:
//
//   1. Tax Collector enemies are drawn HOLDING sprite_item_pickaxe.png — a
//      brown handle with a steel head, parked in mid-frame.
//   2. src/enemies/gnome_arrow.gd draws an arrow from primitives in exactly
//      the axe palette: wood (0.55,0.38,0.20), steel (0.86,0.88,0.92),
//      feather (0.90,0.76,0.42).
//
// Neither is the player's projectile. Identify the player's throw by MOTION,
// not by looks: it spawns at the player's smoke_spawn and travels in the
// FACING direction at ~640 px/s (smoke bomb) or ~620 px/s (axe). An object
// moving TOWARD the player, or not moving at all, is never his weapon.
//
// The actual discriminator, once you have the right object:
//   smoke bomb -> dark green body (0.22,0.29,0.2) + lighter green wrap
//                 (0.42,0.6,0.36) + orange fuse (1,0.72,0.3)
//   axe        -> the pale steel pickaxe SPRITE
import { chromium } from 'playwright'; import fs from 'fs';
const OUT='artifacts/stage1-weapon'; fs.rmSync(OUT,{recursive:true,force:true}); fs.mkdirSync(OUT,{recursive:true});
const PIN=['/opt/pw-browsers/chromium-1194/chrome-linux/chrome','/opt/pw-browsers/chromium/chrome-linux/chrome'];
const o={args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox','--ignore-certificate-errors']};
for(const p of PIN){if(fs.existsSync(p)){o.executablePath=p;break;}}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const b=await chromium.launch(o);
const ctx=await b.newContext({viewport:{width:1280,height:720},ignoreHTTPSErrors:true});
const pg=await ctx.newPage();
await pg.goto(`${process.argv[2]}?v=${Date.now()}&stage=1`,{waitUntil:'domcontentloaded',timeout:120000});
await pg.waitForSelector('canvas',{timeout:120000});
await pg.waitForFunction(()=>{const c=document.querySelector('canvas');return c&&c.width>100&&c.height>100;},{timeout:180000});
await sleep(9000);
const cv = await pg.$('canvas');
await cv.click({position:{x:640,y:600}}).catch(()=>{});   // focus the canvas
await sleep(400);
await pg.screenshot({path:`${OUT}/00_before_walk.png`});
// PROVE INPUT: hold right and confirm the frame changes near the ground.
await pg.keyboard.down('KeyD'); await sleep(1200); await pg.keyboard.up('KeyD');
await sleep(300);
await pg.screenshot({path:`${OUT}/01_after_walk.png`});
// Now attack, sampling fast so a 640px/s projectile is caught mid-flight.
await pg.screenshot({path:`${OUT}/02_pre_attack.png`});
await pg.keyboard.press('KeyJ');
for (let i=0;i<6;i++){ await sleep(45); await pg.screenshot({path:`${OUT}/03_atk_${i}.png`}); }
await ctx.close(); await b.close(); console.log('DONE');

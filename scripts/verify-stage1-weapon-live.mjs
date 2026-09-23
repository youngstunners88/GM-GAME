// verify-stage1-weapon-live.mjs — prove, on the LIVE build, that Stage 1's base
// attack is a SMOKE BOMB and not an axe.
//
// Usage: node scripts/verify-stage1-weapon-live.mjs <live-index.html-url>
//
// HOW TO READ THE RESULT — three traps cost a whole session on 2026-09-22:
//
//  1. DO NOT identify the weapon by eye. Stage 1 contains two decoys that look
//     exactly like a thrown axe: Tax Collectors are drawn HOLDING
//     sprite_item_pickaxe.png, and src/enemies/gnome_arrow.gd draws an arrow in
//     the axe palette (wood 0.55,0.38,0.20 / steel 0.86,0.88,0.92 / feather
//     0.90,0.76,0.42). Both were mistaken for the player's projectile.
//
//  2. DO NOT trust a frame-diff against a pre-attack frame. The camera scrolls,
//     so every static prop registers as "moving" and the diff fills with noise.
//
//  3. DO identify it by EXACT COLOUR. The smoke bomb is drawn from primitives,
//     so its pixels are byte-exact and unique in this level:
//         body (56,74,51)  wrap (107,153,92)  fuse (255,184,77)
//     Count pixels matching all three in one ~18x18 blob. Nothing else in
//     Stage 1 carries that combination. The axe, by contrast, is the pale
//     steel pickaxe SPRITE — anti-aliased, no flat palette.
//
// Verified this way on build 2026-09-22-a79d3db: 179 body px, 89 wrap px,
// 15 fuse px in one blob beside the player. Usage: <url> [stage 1-3].
// Pair with: python3 scripts/weapon-colour-check.py artifacts/weapon-verify-sN
import { chromium } from 'playwright'; import fs from 'fs';
const OUT=`artifacts/weapon-verify-s${process.argv[3]||"1"}`; fs.rmSync(OUT,{recursive:true,force:true}); fs.mkdirSync(OUT,{recursive:true});
const PIN=['/opt/pw-browsers/chromium-1194/chrome-linux/chrome','/opt/pw-browsers/chromium/chrome-linux/chrome'];
const o={args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox','--ignore-certificate-errors']};
for(const p of PIN){if(fs.existsSync(p)){o.executablePath=p;break;}}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const b=await chromium.launch(o);
const ctx=await b.newContext({viewport:{width:1280,height:720},ignoreHTTPSErrors:true});
const pg=await ctx.newPage();
await pg.goto(`${process.argv[2]}?v=${Date.now()}&stage=${process.argv[3]||"1"}`,{waitUntil:'domcontentloaded',timeout:120000});
await pg.waitForSelector('canvas',{timeout:120000});
await pg.waitForFunction(()=>{const c=document.querySelector('canvas');return c&&c.width>100&&c.height>100;},{timeout:180000});
await sleep(9000);
const cv=await pg.$('canvas'); await cv.click({position:{x:640,y:660}}).catch(()=>{}); await sleep(300);
await pg.keyboard.down('KeyD'); await sleep(450); await pg.keyboard.up('KeyD'); await sleep(500);
for (let r=0;r<4;r++){
  await pg.screenshot({path:`${OUT}/r${r}_pre.png`});
  await pg.keyboard.press('KeyJ');
  for(let i=0;i<4;i++){ await sleep(33); await pg.screenshot({path:`${OUT}/r${r}_f${i}.png`}); }
  await sleep(800);
}
await ctx.close(); await b.close(); console.log('DONE');

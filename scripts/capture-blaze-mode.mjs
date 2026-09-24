// capture-blaze-mode.mjs — reproduce what a SMOKE holder sees, legitimately.
//
// The founder holds SMOKE, so every level load gives him 30s of Blaze Mode
// (level_base._apply_token_perks), including the reload when he exits Blaze
// Rush. A capture bot with no wallet never gets that, which is why every bot
// capture looked clean. We do NOT add a URL switch that grants wallet perks
// (that would let anyone bypass the token gate). Instead this plays the game:
//   A) Stage 1: walk/jump right into the weed leaf -> Blaze Mode, then film.
//   B) Blaze Rush L1 -> press Q (Tap Out) -> film the level it returns to.
// Usage: node scripts/capture-blaze-mode.mjs <live index.html url>
import { chromium } from 'playwright'; import fs from 'fs';
const OUT='artifacts/blaze-mode'; fs.rmSync(OUT,{recursive:true,force:true}); fs.mkdirSync(OUT,{recursive:true});
const PIN=['/opt/pw-browsers/chromium-1194/chrome-linux/chrome','/opt/pw-browsers/chromium/chrome-linux/chrome'];
const o={args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox','--ignore-certificate-errors']};
for(const p of PIN){if(fs.existsSync(p)){o.executablePath=p;break;}}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const b=await chromium.launch(o);
async function boot(q){
  const ctx=await b.newContext({viewport:{width:1280,height:720},ignoreHTTPSErrors:true});
  const pg=await ctx.newPage();
  await pg.goto(`${process.argv[2]}?v=${Date.now()}&${q}`,{waitUntil:'domcontentloaded',timeout:120000});
  await pg.waitForSelector('canvas',{timeout:120000});
  await pg.waitForFunction(()=>{const c=document.querySelector('canvas');return c&&c.width>100&&c.height>100;},{timeout:180000});
  await sleep(9000);
  const cv=await pg.$('canvas'); await cv.click({position:{x:640,y:660}}).catch(()=>{}); await sleep(300);
  return {ctx,pg};
}
// A) Stage 1 weed leaf
{
  const {ctx,pg}=await boot('stage=1');
  await pg.screenshot({path:`${OUT}/A00_start.png`});
  await pg.keyboard.down('KeyD');
  for(let i=0;i<14;i++){ if(i%3===0){ await pg.keyboard.press('KeyW'); } await sleep(160); }
  await pg.keyboard.up('KeyD');
  for(let i=0;i<10;i++){ await sleep(500); await pg.screenshot({path:`${OUT}/A${String(i+1).padStart(2,'0')}.png`}); }
  await ctx.close();
}
// B) Blaze Rush L1 -> Tap Out -> level
{
  const {ctx,pg}=await boot('blaze=1');
  await pg.screenshot({path:`${OUT}/B00_blaze.png`});
  await pg.keyboard.press('KeyQ'); await sleep(6000);
  for(let i=0;i<6;i++){ await sleep(700); await pg.screenshot({path:`${OUT}/B${String(i+1).padStart(2,'0')}_after_exit.png`}); }
  await ctx.close();
}
await b.close(); console.log('DONE ->',OUT);

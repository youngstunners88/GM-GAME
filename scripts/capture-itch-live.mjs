// capture-itch-live.mjs — capture the CURRENT live itch build (fetches the live
// game URL from the itch page first, so it always hits the latest deployed build).
import { chromium } from 'playwright';
import fs from 'fs';
const OUT='artifacts/itch-live'; fs.mkdirSync(OUT,{recursive:true});
const PINNED=['/opt/pw-browsers/chromium-1194/chrome-linux/chrome','/opt/pw-browsers/chromium/chrome-linux/chrome'];
const o={args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox','--ignore-certificate-errors']};
for(const p of PINNED){if(fs.existsSync(p)){o.executablePath=p;break;}}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const b=await chromium.launch(o);
// 1) get the current game iframe URL
const ctx0=await b.newContext({viewport:{width:1280,height:800},ignoreHTTPSErrors:true});
const pg0=await ctx0.newPage();
await pg0.goto('https://youngstunners88.itch.io/lil-blunt-adventure',{waitUntil:'domcontentloaded',timeout:120000});
await sleep(5000);
let GAME=await pg0.evaluate(()=>{
  const f=document.querySelector('iframe[src*="itch.zone"]');
  if(f&&f.src) return f.src;
  const ph=document.querySelector('[data-iframe]');
  if(ph){const m=(ph.getAttribute('data-iframe')||'').match(/src="([^"]+)"/); if(m) return m[1].replace(/&amp;/g,'&');}
  return '';
});
await ctx0.close();
const base=GAME.split('?')[0];
console.log('LIVE_BUILD_URL='+base);
const shots=[['L1_tree','stage=1&spawn_x=1600'],['L2_join','stage=2&spawn_x=2243'],['L3_vault','stage=3&spawn_x=2600'],['fortknox','vault=fort']];
for(const [name,q] of shots){
  const ctx=await b.newContext({viewport:{width:1280,height:720},ignoreHTTPSErrors:true});
  const pg=await ctx.newPage();
  try{
    await pg.goto(`${base}?v=${Date.now()}&${q}`,{waitUntil:'domcontentloaded',timeout:120000});
    await pg.waitForSelector('canvas',{timeout:120000});
    await pg.waitForFunction(()=>{const c=document.querySelector('canvas');return c&&c.width>100&&c.height>100;},{timeout:180000});
    await sleep(9500);
    await pg.screenshot({path:`${OUT}/${name}.png`});
    console.log(name,'OK');
  }catch(e){console.log(name,'FAIL',e.message.slice(0,80));}
  await ctx.close();
}
await b.close(); console.log('DONE');

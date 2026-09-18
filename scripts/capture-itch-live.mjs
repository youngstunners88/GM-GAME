// capture-itch-live.mjs — capture the LIVE itch build directly from the itch.zone
// game URL (not a local export), using the ?stage/?spawn_x/?vault debug warps.
import { chromium } from 'playwright';
import fs from 'fs';
const GAME='https://html-classic.itch.zone/html/18305533-1989293/index.html';
const OUT='artifacts/itch-live'; fs.mkdirSync(OUT,{recursive:true});
const PINNED=['/opt/pw-browsers/chromium-1194/chrome-linux/chrome','/opt/pw-browsers/chromium/chrome-linux/chrome'];
const o={args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox','--ignore-certificate-errors']};
for(const p of PINNED){if(fs.existsSync(p)){o.executablePath=p;break;}}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const b=await chromium.launch(o);
const shots=[['L1_tree','stage=1&spawn_x=1600'],['L2_join','stage=2&spawn_x=2243'],['L3_vault','stage=3&spawn_x=2600'],['L3_alive','stage=3&spawn_x=1750'],['fortknox','vault=fort']];
for(const [name,q] of shots){
  const ctx=await b.newContext({viewport:{width:1280,height:720},ignoreHTTPSErrors:true});
  const pg=await ctx.newPage();
  const errs=[]; pg.on('console',m=>{const t=m.text(); if(/USER SCRIPT ERROR|SCRIPT ERROR|Cannot call method/i.test(t))errs.push(t);});
  const url=`${GAME}?v=${Date.now()}&${q}`;
  try{
    await pg.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
    await pg.waitForSelector('canvas',{timeout:120000});
    await pg.waitForFunction(()=>{const c=document.querySelector('canvas');return c&&c.width>100&&c.height>100;},{timeout:180000});
    await sleep(9500);
    await pg.screenshot({path:`${OUT}/${name}.png`});
    console.log(name,'OK errs',errs.length);
  }catch(e){ console.log(name,'FAIL',e.message.slice(0,120)); }
  await ctx.close();
}
await b.close(); console.log('DONE');

import { chromium } from 'playwright'; import fs from 'fs';
const BASE=process.argv[2]; const OUT=process.argv[3]||'artifacts/blaze'; fs.mkdirSync(OUT,{recursive:true});
const PIN=['/opt/pw-browsers/chromium-1194/chrome-linux/chrome','/opt/pw-browsers/chromium/chrome-linux/chrome'];
const o={args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox','--ignore-certificate-errors']};
for(const p of PIN){if(fs.existsSync(p)){o.executablePath=p;break;}}
const sleep=ms=>new Promise(r=>setTimeout(r,ms)); const b=await chromium.launch(o);
for(const n of [1,2,3]){
  const ctx=await b.newContext({viewport:{width:1280,height:720},ignoreHTTPSErrors:true}); const pg=await ctx.newPage();
  const errs=[]; pg.on('console',m=>{const t=m.text(); if(/USER SCRIPT ERROR|SCRIPT ERROR|Cannot call/i.test(t))errs.push(t);});
  try{ await pg.goto(`${BASE}?v=${Date.now()}&blaze=${n}`,{waitUntil:'domcontentloaded',timeout:120000});
    await pg.waitForSelector('canvas',{timeout:120000});
    await pg.waitForFunction(()=>{const c=document.querySelector('canvas');return c&&c.width>100&&c.height>100;},{timeout:180000});
    await sleep(4000); await pg.screenshot({path:`${OUT}/blaze${n}_a.png`});
    await sleep(2500); await pg.screenshot({path:`${OUT}/blaze${n}_b.png`});
    console.log('blaze',n,'OK errs',errs.length, errs.slice(0,2));
  }catch(e){console.log('blaze',n,'FAIL',e.message.slice(0,80));}
  await ctx.close();
}
await b.close(); console.log('DONE');

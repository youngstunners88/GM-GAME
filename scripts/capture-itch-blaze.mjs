import { chromium } from 'playwright'; import fs from 'fs';
const OUT='artifacts/itch-blaze'; fs.mkdirSync(OUT,{recursive:true});
const PIN=['/opt/pw-browsers/chromium-1194/chrome-linux/chrome','/opt/pw-browsers/chromium/chrome-linux/chrome'];
const o={args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox','--ignore-certificate-errors']};
for(const p of PIN){if(fs.existsSync(p)){o.executablePath=p;break;}}
const sleep=ms=>new Promise(r=>setTimeout(r,ms)); const b=await chromium.launch(o);
let GAME='';
for(let attempt=1; attempt<=3 && !GAME; attempt++){
  const c0=await b.newContext({viewport:{width:1280,height:800},ignoreHTTPSErrors:true}); const p0=await c0.newPage();
  try{
    await p0.goto('https://youngstunners88.itch.io/lil-blunt-adventure',{waitUntil:'domcontentloaded',timeout:120000});
    await p0.waitForSelector('[data-iframe], iframe[src*="itch.zone"]',{timeout:30000});
    await sleep(1500);
    GAME=await p0.evaluate(()=>{const f=document.querySelector('iframe[src*="itch.zone"]');if(f&&f.src)return f.src;const ph=document.querySelector('[data-iframe]');if(ph){const m=(ph.getAttribute('data-iframe')||'').match(/src="([^"]+)"/);if(m)return m[1].replace(/&amp;/g,'&');}return '';});
  }catch(e){ console.log('attempt',attempt,'fetch fail',e.message.slice(0,60)); }
  await c0.close();
}
const base=GAME.split('?')[0]; console.log('LIVE_BUILD_URL='+base);
if(!base){ console.log('NO_URL'); await b.close(); process.exit(0); }
for(const n of [1,2,3]){
  const ctx=await b.newContext({viewport:{width:1280,height:720},ignoreHTTPSErrors:true}); const pg=await ctx.newPage();
  try{ await pg.goto(`${base}?v=${Date.now()}&blaze=${n}`,{waitUntil:'domcontentloaded',timeout:120000});
    await pg.waitForSelector('canvas',{timeout:120000});
    await pg.waitForFunction(()=>{const c=document.querySelector('canvas');return c&&c.width>100&&c.height>100;},{timeout:180000});
    await sleep(5500); await pg.screenshot({path:`${OUT}/blaze${n}.png`}); console.log('blaze',n,'OK');
  }catch(e){console.log('blaze',n,'FAIL',e.message.slice(0,70));}
  await ctx.close();
}
await b.close(); console.log('DONE');

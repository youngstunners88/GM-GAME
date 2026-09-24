import { chromium } from 'playwright'; import fs from 'fs';
const OUT='artifacts/blaze-attempts'; fs.mkdirSync(OUT,{recursive:true});
const PIN=['/opt/pw-browsers/chromium-1194/chrome-linux/chrome','/opt/pw-browsers/chromium/chrome-linux/chrome'];
const o={args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox','--ignore-certificate-errors']};
for(const p of PIN){if(fs.existsSync(p)){o.executablePath=p;break;}}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const b=await chromium.launch(o);
const base=process.argv[2];
const lvl=process.argv[3]||'3';
const ctx=await b.newContext({viewport:{width:1496,height:847},ignoreHTTPSErrors:true});
const pg=await ctx.newPage();
await pg.goto(`${base}?v=${Date.now()}&blaze=${lvl}`,{waitUntil:'domcontentloaded',timeout:120000});
await pg.waitForSelector('canvas',{timeout:120000});
await pg.waitForFunction(()=>{const c=document.querySelector('canvas');return c&&c.width>100&&c.height>100;},{timeout:180000});
await sleep(4000);
// let it run and die repeatedly; shoot at increasing elapsed time
for (const t of [0, 20, 40, 60, 80]) {
  if (t) await sleep(20000);
  await pg.screenshot({path:`${OUT}/l${lvl}_t${t}.png`});
  console.log('shot t=',t);
}
await ctx.close(); await b.close(); console.log('DONE');

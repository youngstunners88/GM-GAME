const {chromium}=require('playwright');
const fs=require('fs');
const out=process.argv[2],url=process.argv[3];fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist','--disable-dev-shm-usage'],proxy:process.env.HTTPS_PROXY?{server:process.env.HTTPS_PROXY}:undefined});
 const context=await browser.newContext({viewport:{width:960,height:540},ignoreHTTPSErrors:true,serviceWorkers:'block'});
 const logs=[],errors=[],blocked=[];let fixture=false;
 await context.route('**/*',async route=>{
  const req=route.request(),u=new URL(req.url());
  if(['data:','blob:'].includes(u.protocol))return route.continue();
  if(!['GET','HEAD'].includes(req.method())||!['html-classic.itch.zone','youngstunners88.itch.io','itch.io','static.itch.io','img.itch.zone'].includes(u.hostname)){
   blocked.push({host:u.hostname,path:u.pathname,method:req.method()});return route.abort();
  }
  if(fixture&&u.pathname.endsWith('/index.html')){
   const r=await route.fetch();let body=await r.text();
   body=body.replace('const engine = new Engine(GODOT_CONFIG);','const engine = new Engine(GODOT_CONFIG);\nengine.preloadFile(new TextEncoder().encode(\'[ep2]\\nkey="oNnp3gYj9AxoCW/G7jmhAtt4RK0pxyT2xg4gDl8Eajs="\\n\'), \'/userfs/godot/app_userdata/Lil Blunt- The Smoke Realm/ep2_unlock.cfg\');');
   return route.fulfill({response:r,body});
  }
  return route.continue();
 });
 const page=await context.newPage();page.setDefaultTimeout(180000);
 page.on('console',m=>{logs.push(m.text());if(m.text().includes('[BUILD]')||m.text().includes('[EP2] chamber'))console.log(new Date().toISOString(),m.text());if(/SCRIPT ERROR|Parse Error/.test(m.text()))errors.push(m.text());});
 page.on('pageerror',e=>errors.push(String(e)));
 const wait=async(test,timeout=240000)=>{let start=Date.now();while(!test()){if(Date.now()-start>timeout)throw new Error('Telemetry wait timeout');await page.waitForTimeout(250);}};
 const latest=()=>logs.filter(x=>x.includes('[EP2] chamber beat=')).at(-1)||'';
 try {
  await page.goto(url+(url.includes('?')?'&':'?')+'ep2=1&ep2probe=1');
  await wait(()=>logs.some(x=>x.includes('[EP2] code prompt')));
  await page.keyboard.type('wrong-review-code');await page.keyboard.press('Enter');await page.waitForTimeout(1500);
  await page.screenshot({path:out+'/access.png'});
  if(logs.some(x=>x.includes('[EP2] runner')||x.includes('[EP2] chamber')))throw new Error('Invalid code unexpectedly started Episode 2');
  fixture=true;logs.length=0;
  await page.goto(url+(url.includes('?')?'&':'?')+'ep2=1&ep2probe=1&ep2chamber=1');
  await wait(()=>latest().includes('CINEMATIC'));await page.mouse.move(640,360);
  await page.keyboard.down('Space');await page.waitForTimeout(2200);await page.keyboard.up('Space');
  await wait(()=>latest().includes('VERB_TEACH')&&latest().includes('control=true'));
  await page.waitForTimeout(3000);await page.screenshot({path:out+'/hideout.png'});
  const before=latest();await page.mouse.move(230,360,{steps:3});await page.waitForTimeout(2000);
  const afterLook=latest();await page.screenshot({path:out+'/bull.png'});
  const pos=latest().match(/pos=(.*?) yaw=/)?.[1];await page.keyboard.down('w');
  await wait(()=>latest().match(/pos=(.*?) yaw=/)?.[1]!==pos,45000);await page.keyboard.up('w');
  const afterMove=latest();await page.mouse.click(230,360);await page.keyboard.press('k');await page.waitForTimeout(1000);
  const pointerLocked=await page.evaluate(()=>!!document.pointerLockElement);
  await page.screenshot({path:out+'/input.png'});
  fs.writeFileSync(out+'/input-check.json',JSON.stringify({url,build:logs.find(x=>x.includes('[BUILD]')),errors,before,afterLook,afterMove,pointerLocked},null,2));
  await page.keyboard.press('k');
  const state=()=>{const m=latest().match(/pos=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\) yaw=([-\d.]+)/);return m?{x:+m[1],z:+m[3],yaw:+m[4]}:null;};
  let rangeReached=false;const navStart=Date.now();
  while(Date.now()-navStart<180000){
   const p=state();if(!p)throw new Error('Missing position telemetry');
   const dx=-p.x,dz=-2-p.z;
   if(Math.hypot(dx,dz)<2.3){rangeReached=true;break;}
   if(!latest().includes('control=true')){await page.waitForTimeout(1000);continue;}
   const f=dx*Math.sin(p.yaw)+dz*Math.cos(p.yaw),r=-dx*Math.cos(p.yaw)+dz*Math.sin(p.yaw);
   const keys=[];if(Math.abs(f)>.6)keys.push(f>0?'w':'s');if(Math.abs(r)>.6)keys.push(r>0?'d':'a');
   for(const k of keys)await page.keyboard.down(k);
   await page.waitForTimeout(600);for(const k of keys)await page.keyboard.up(k);
   await page.waitForTimeout(500);
  }
  if(!rangeReached)throw new Error('Could not walk to firing line');
  await page.waitForTimeout(2500);await page.screenshot({path:out+'/range.png'});
  // Let the real instructor demonstration finish before testing load and aim.
  await wait(()=>latest().includes('control=true'),600000);
  await page.keyboard.press('r');await page.waitForTimeout(8000);
  await page.mouse.down({button:'right'});await page.waitForTimeout(5000);
  await page.screenshot({path:out+'/range-ads.png'});await page.mouse.up({button:'right'});
  await page.mouse.click(640,360);await page.waitForTimeout(1500);
  const rangeState=latest();
  const result={rangeReached,rangeState,url,build:logs.find(x=>x.includes('[BUILD]')),errors,blocked,fixture:'HTML-only saved unlock; original PCK unchanged',before,afterLook,afterMove,pointerLocked,logs:logs.filter(x=>!x.includes('[EP2] runner')).slice(-80)};
  fs.writeFileSync(out+'/live.json',JSON.stringify(result,null,2));
  console.log(JSON.stringify({build:result.build,errors,before,afterLook,afterMove,pointerLocked}));
  if((before.match(/yaw=([-\d.]+)/)?.[1]===afterLook.match(/yaw=([-\d.]+)/)?.[1]&&before.match(/yaw=([-\d.]+)/)?.[1]===afterMove.match(/yaw=([-\d.]+)/)?.[1])||pos===afterMove.match(/pos=(.*?) yaw=/)?.[1]||errors.length)throw new Error('Live inputs or script check failed');
 }catch(e){fs.writeFileSync(out+'/failure.json',JSON.stringify({error:String(e),errors,logs:logs.slice(-100)},null,2));throw e;}
 finally{await browser.close();}
})();

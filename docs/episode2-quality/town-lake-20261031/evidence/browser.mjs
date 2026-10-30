import {chromium,launchOptions} from '/workspace/GM-GAME/scripts/lib/pw.mjs';
import fs from 'node:fs';
const out=process.env.REPLAY_OUT||'/workspace/work/town-lake-1031';
const b=await chromium.launch(launchOptions());
const p=await b.newPage({viewport:{width:1280,height:720}});p.setDefaultTimeout(180000);
await p.addInitScript(()=>{
 window.__scoreContexts=[];window.__scoreAnalysers=[];
 const originalConnect=AudioNode.prototype.connect;
 AudioNode.prototype.connect=function(destination,...args){
  const value=originalConnect.call(this,destination,...args);
  if(destination===this.context.destination){const meter=this.context.createAnalyser();originalConnect.call(this,meter);window.__scoreAnalysers.push(meter);}
  return value;
 };
 const Original=window.AudioContext;
 window.AudioContext=class extends Original{constructor(...args){super(...args);window.__scoreContexts.push(this);}};
});
let done=false,errors=[],result,shots=[];let shotQueue=Promise.resolve();
p.on('console',m=>{const s=m.text();fs.appendFileSync(out+'/web-console.log',s+'\n');if(/SCRIPT ERROR|Parse Error|SHADER ERROR|USER ERROR/.test(s))errors.push(s);
if(s==='ARRIVAL_WEB_UNLOCK')void p.mouse.click(10,10).then(()=>p.keyboard.down('F9'));
if(s.startsWith('ARRIVAL_WEB_LINGER'))console.log(s);
if(s.startsWith('ARRIVAL_WEB_FRAME ')){const name=s.split(' ').at(-1);console.log(s);shotQueue=shotQueue.then(async()=>{await p.screenshot({path:out+'/web-'+name+'.png'});shots.push(name);await p.keyboard.down('F9');});}
if(s==='ARRIVAL_WEB_ACK')void p.keyboard.up('F9');
if(s.startsWith('ARRIVAL_WEB_RESULT ')){result=JSON.parse(s.slice(s.indexOf('{')));console.log(s);}
if(s==='ARRIVAL_WEB_DONE')done=true;});p.on('pageerror',e=>errors.push(String(e)));
try{fs.writeFileSync(out+'/web-console.log','');await p.goto(process.env.REPLAY_URL||'http://localhost:8899/game/arrival-web.html');const end=Date.now()+900000;while(!done&&Date.now()<end&&!errors.length)await p.waitForTimeout(200);await shotQueue;
let outputPeak=0;for(let i=0;i<10;i++){outputPeak=Math.max(outputPeak,await p.evaluate(()=>Math.max(0,...(window.__scoreAnalysers||[]).map(m=>{const a=new Float32Array(m.fftSize);m.getFloatTimeDomainData(a);return Math.sqrt(a.reduce((s,v)=>s+v*v,0)/a.length);})))) ;await p.waitForTimeout(100);}
const contexts=await p.evaluate(()=>(window.__scoreContexts||[]).map(c=>c.state));
const build=fs.readFileSync(out+'/web-console.log','utf8').split('\n').find(x=>x.startsWith('[BUILD]'))||'';const ok=(!process.env.EXPECT_BUILD||build.includes(process.env.EXPECT_BUILD))&&done&&result?.failed===0&&result?.checks===8&&result?.playback_seconds>0.25&&shots.length===5&&contexts.includes('running')&&outputPeak>0.000001&&!errors.length;const r={ok,build,result,shots,contexts,outputPeak,errors};fs.writeFileSync(out+'/web-result.json',JSON.stringify(r,null,2));console.log(JSON.stringify(r));if(!ok)process.exitCode=1;}finally{await b.close();}

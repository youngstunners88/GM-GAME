import {chromium,launchOptions} from '/workspace/GM-GAME/scripts/lib/pw.mjs';
import fs from 'node:fs';
const out=process.env.REPLAY_OUT||'/workspace/work/elevator-crossing-1030';
const b=await chromium.launch(launchOptions());
const p=await b.newPage({viewport:{width:1280,height:720}});p.setDefaultTimeout(180000);
let done=false,errors=[],result,shots=[];let shotQueue=Promise.resolve();
p.on('console',m=>{const s=m.text();fs.appendFileSync(out+'/web-console.log',s+'\n');if(/SCRIPT ERROR|Parse Error|SHADER ERROR/.test(s))errors.push(s);
if(s.startsWith('ELEVATOR_WEB_FRAME ')){const name=s.split(' ').at(-1);console.log(s);shotQueue=shotQueue.then(async()=>{await p.screenshot({path:out+'/web-'+name+'.png'});shots.push(name);await p.keyboard.down('F9');});}
if(s==='ELEVATOR_WEB_ACK')void p.keyboard.up('F9');
if(s.startsWith('ELEVATOR_WEB_RESULT ')){result=JSON.parse(s.slice(s.indexOf('{')));console.log(s);}
if(s==='ELEVATOR_WEB_DONE')done=true;});p.on('pageerror',e=>errors.push(String(e)));
try{fs.writeFileSync(out+'/web-console.log','');await p.goto(process.env.REPLAY_URL||'http://localhost:8899/game/elevator-web.html');const end=Date.now()+600000;while(!done&&Date.now()<end&&!errors.length)await p.waitForTimeout(200);await shotQueue;const ok=done&&result?.resolved===1&&result?.same_instance&&result?.hud&&result?.weapon&&shots.length===3&&!errors.length;const r={ok,result,shots,errors};fs.writeFileSync(out+'/web-result.json',JSON.stringify(r,null,2));console.log(JSON.stringify(r));if(!ok)process.exitCode=1;}finally{await b.close();}

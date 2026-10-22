import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import { prepareRequest,validateResponse,DEFAULT_MODEL,BUDGET } from '../scripts/jev-request.mjs';
import { evaluate,decide } from '../scripts/jev.mjs';
const questions={contact:{type:'boolean',instructions:'Do the measured contact distances exceed the specified tolerance?'}};
const base={state:'Measured contact gap: 0.001 metres; tolerance: 0.005 metres.',questions};

test('text route remains JSON and maps boolean to noul',async()=>{
 const r=await prepareRequest(base);
 assert.equal(r.headers['Content-Type'],'application/json');
 assert.equal(JSON.parse(r.body).questions.contact.type,'noul');
 assert.equal(r.summary.model,DEFAULT_MODEL);
 assert.equal(r.summary.images.length,0);
 assert.equal(decide(.55),'uncertain');
});
test('rejects oversized context, missing criteria and excessive fan-out before network',async()=>{
 await assert.rejects(prepareRequest({...base,state:'x'.repeat(BUDGET.textBytes)}),/budget/);
 await assert.rejects(prepareRequest({...base,state:'data:image/png;base64,AAAA'}),/binary image/);
 await assert.rejects(prepareRequest({...base,questions:{route:{type:'choice',instructions:'Choose'}}}),/criteria/);
 await assert.rejects(prepareRequest({...base,questions:Object.fromEntries(Array.from({length:9},(_,i)=>[i,questions.contact]))}),/1–8/);
});
test('image gate is explicit, uses binary multipart, labels evidence and binds image digest',async()=>{
 const req={state:'Inspect <current>.',questions,assets:{'<current>':'src/episode2/assets/weapons/armory/remington_icon.png'}};
 await assert.rejects(prepareRequest({...req,provider:'openrouter'}),/unverified/);
 await assert.rejects(prepareRequest({...req,model:'jev-1.13'},{experimentalImages:true}),/pin/);
 const a=await prepareRequest(req,{experimentalImages:true});
 const b=await prepareRequest(req,{experimentalImages:true});
 assert.equal(a.summary.digest,b.summary.digest);
 assert.equal(a.headers['TypeSafe-Danger-Zone-Images'],'true');
 const boundary=a.headers['Content-Type'].split('boundary=')[1];
 assert.ok(boundary);
 const bytes=Buffer.from(await a.body.arrayBuffer());
 const prefix=`--${boundary}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n`;
 assert.ok(bytes.subarray(0,Buffer.byteLength(prefix)).equals(Buffer.from(prefix)));
 const end=bytes.indexOf(Buffer.from(`\r\n--${boundary}`),Buffer.byteLength(prefix));
 const payload=JSON.parse(bytes.subarray(Buffer.byteLength(prefix),end).toString());
 assert.deepEqual(payload.assets,{'<current>':{type:'image',part:'asset-0'}});
 assert.ok(bytes.includes(Buffer.from('name="asset-0"; filename="asset-0"\r\nContent-Type: image/png')));
 assert.ok(bytes.includes(await readFile(req.assets['<current>'])));
 assert.ok(bytes.subarray(-Buffer.byteLength(`--${boundary}--\r\n`)).equals(Buffer.from(`--${boundary}--\r\n`)));
 assert.ok(!JSON.stringify(payload).includes('src/episode2'));
 await assert.rejects(prepareRequest({...req,state:'No image reference here.'},{experimentalImages:true}),/Unused/);
 await assert.rejects(prepareRequest({...req,assets:{'<current>':'package.json'}},{experimentalImages:true}),/PNG/);
});
test('rejects missing answers, invalid probabilities and unknown routes',()=>{
 assert.throws(()=>validateResponse({model:DEFAULT_MODEL,answers:{}},questions),/Malformed/);
 assert.throws(()=>validateResponse({model:DEFAULT_MODEL,answers:{contact:{type:'noul',noul:1.2}}},questions),/probability/);
 assert.throws(()=>validateResponse({model:DEFAULT_MODEL,answers:{route:{type:'choice',choice:'execute_arbitrary_command'}}},{route:{type:'choice',criteria:{grip:null,manual:null}}}),/Unknown/);
});
test('one direct TypeSafe call, no retries or fallback, validates response before normalizing',async()=>{
 const oldFetch=global.fetch;const oldKey=process.env.TYPESAFE;process.env.TYPESAFE='test-only-placeholder';let calls=0;
 try {
  global.fetch=async(url,options)=>{calls++;assert.equal(url,'https://api.typesafe.ai/v1/systemone');assert.equal(options.redirect,'error');return new Response(JSON.stringify({model:DEFAULT_MODEL,answers:{contact:{type:'noul',noul:.1}}}),{status:200});};
  const r=await evaluate(base);assert.equal(r.answers.contact.probability,.1);assert.equal(calls,1);
  global.fetch=async()=>{calls++;return new Response('failure',{status:429});};
  await assert.rejects(evaluate(base),/HTTP 429/);assert.equal(calls,2);
 } finally {global.fetch=oldFetch;if(oldKey===undefined)delete process.env.TYPESAFE;else process.env.TYPESAFE=oldKey;}
});

test('OpenRouter remains explicit, using only its own credential and endpoint',async()=>{
 const old=global.fetch;const saved=process.env.OPENROUTER_API_KEY;process.env.OPENROUTER_API_KEY='test-openrouter-placeholder';
 try {
  global.fetch=async(url,options)=>{assert.equal(url,'https://openrouter.ai/api/alpha/decisions');assert.equal(options.headers.Authorization,'Bearer test-openrouter-placeholder');return new Response(JSON.stringify({model:'typesafe/jev-1.14',answers:{contact:{type:'noul',noul:.2}}}));};
  assert.equal((await evaluate({...base,provider:'openrouter'})).answers.contact.probability,.2);
 }finally{global.fetch=old;if(saved===undefined)delete process.env.OPENROUTER_API_KEY;else process.env.OPENROUTER_API_KEY=saved;}
});

// ---- Official-docs (2026-10-15) additions: dimensions, box, pins, long context, aliases ----
import {writeFile,mkdtemp} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {deflateSync} from 'node:zlib';
const crcT=(()=>{const t=[];for(let n=0;n<256;n++){let c=n;for(let k=0;k<8;k++)c=c&1?0xedb88320^(c>>>1):c>>>1;t[n]=c>>>0;}return t;})();
const crc=b=>{let c=~0;for(const x of b)c=crcT[(c^x)&255]^(c>>>8);return ~c>>>0;};
const chunk=(t,d)=>{const h=Buffer.alloc(8);h.writeUInt32BE(d.length,0);h.write(t,4,'ascii');const c=Buffer.alloc(4);c.writeUInt32BE(crc(Buffer.concat([h.subarray(4),d])),0);return Buffer.concat([h,d,c]);};
/** Tiny valid grayscale PNG; all-zero rows compress to a few bytes even at 1568 px. */
function png(w,h,{animated=false}={}){
 const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(w,0);ihdr.writeUInt32BE(h,4);ihdr[8]=8;ihdr[9]=0;
 const parts=[Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ihdr)];
 if(animated)parts.push(chunk('acTL',Buffer.alloc(8)));
 parts.push(chunk('IDAT',deflateSync(Buffer.alloc((w+1)*h))),chunk('IEND',Buffer.alloc(0)));
 return Buffer.concat(parts);
}
const dir=await mkdtemp(join(tmpdir(),'jev-'));
async function img(name,w,h,o){const f=join(dir,name);await writeFile(f,png(w,h,o));return f;}
const opt={experimentalImages:true};

test('image dimension limits match official docs with actionable errors',async()=>{
 const mk=async(w,h)=>({state:'Inspect <a>.',questions,assets:{'<a>':await img(`d${w}x${h}.png`,w,h)}});
 await prepareRequest(await mk(256,400),opt);
 await prepareRequest(await mk(1568,1000),opt); // 1.568M px: inside both docs and local budget
 await assert.rejects(prepareRequest(await mk(255,1000),opt),/at least 256.*resize/);
 await assert.rejects(prepareRequest(await mk(1000,100),opt),/at least 256/);
 await assert.rejects(prepareRequest(await mk(1569,300),opt),/at most 1568.*crop/);
 await assert.rejects(prepareRequest(await mk(300,1569),opt),/at most 1568/);
 await assert.rejects(prepareRequest(await mk(1568,1568),opt),/pixel/); // 2,458,624 ok for docs, over stricter local budget
});
test('pixel-count floor: sides in range but too few total pixels is rejected',()=>{
 // 256x256=65,536 < 78,400 even though both sides are legal.
 return assert.rejects((async()=>prepareRequest({state:'Inspect <a>.',questions,assets:{'<a>':await img('small.png',256,256)}},opt))(),/78400/);
});
test('animated PNG is rejected',async()=>{
 await assert.rejects(prepareRequest({state:'Inspect <a>.',questions,assets:{'<a>':await img('apng.png',300,300,{animated:true})}},opt),/Animated PNG/);
});
test('box questions are accepted, experimental, and validated by type only',async()=>{
 const q={where:{type:'box',instructions:'Box the visible blemish.'}};
 const r=await prepareRequest({state:'Inspect <a>.',questions:q,assets:{'<a>':await img('b.png',300,300)}},opt);
 assert.equal(JSON.parse(await new Response(r.body).text().then(t=>t.slice(t.indexOf('{"model"'),t.indexOf('\r\n--',t.indexOf('{"model"'))))).questions.where.type,'box');
 await assert.rejects(prepareRequest({state:'x',questions:{w:{type:'box',instructions:' '}}}),/Invalid question/);
 validateResponse({model:'jev-1.14.0',answers:{where:{type:'box',boxes:[{any:'shape'}]}}},q);
 validateResponse({model:'jev-1.14.0',answers:{where:{type:'box'}}},q);
 assert.throws(()=>validateResponse({model:'jev-1.14.0',answers:{where:{type:'noul',noul:.1}}},q),/Malformed answer/);
});
test('image model pins: 1.14 class allowed on typesafe, jev-latest and 1.13 rejected',async()=>{
 const req=async m=>({state:'Inspect <a>.',questions,model:m,assets:{'<a>':await img('p.png',300,300)}});
 for(const m of ['jev-1.14','jev-1.14.0','jev-preview'])assert.equal((await prepareRequest(await req(m),opt)).summary.model,m);
 await assert.rejects(prepareRequest(await req('jev-latest'),opt),/jev-latest points at 1\.13/);
 for(const m of ['jev-1.13','jev-1.13.0'])await assert.rejects(prepareRequest(await req(m),opt),/1\.13/);
 await assert.rejects(prepareRequest({...await req('jev-preview'),provider:'openrouter'},opt),/pin/);
 // Text-only requests are not restricted by the image pin rule.
 assert.equal((await prepareRequest({...base,model:'jev-latest'})).summary.model,'jev-latest');
});
test('longContext adds the header and raises the local text budget only when set',async()=>{
 const big={...base,state:'x'.repeat(BUDGET.textBytes+10)};
 await assert.rejects(prepareRequest(big),/budget/);
 const r=await prepareRequest(big,{longContext:true});
 assert.equal(r.headers['TypeSafe-Danger-Zone-Long-Context'],'true');
 await assert.rejects(prepareRequest({...base,state:'x'.repeat(BUDGET.longContextTextBytes)},{longContext:true}),/budget/);
 assert.equal((await prepareRequest(base)).headers['TypeSafe-Danger-Zone-Long-Context'],undefined);
});
test('docs-style backticked aliases and angle aliases both work; unused refs are caught',async()=>{
 const f=await img('al.png',300,300);
 const r=await prepareRequest({state:'Inspect `photo`.',questions,assets:{photo:f}},opt);
 assert.deepEqual(Object.keys(JSON.parse(await new Response(r.body).text().then(t=>{const i=t.indexOf('{"model"');return t.slice(i,t.indexOf('\r\n--',i));})).assets),['photo']);
 await assert.rejects(prepareRequest({state:'Inspect photo without ticks.',questions,assets:{photo:f}},opt),/Unused/);
 await assert.rejects(prepareRequest({state:'Inspect <photo>.',questions,assets:{photo:f}},opt),/Unused/);
 await prepareRequest({state:'Inspect <photo>.',questions,assets:{'<photo>':f}},opt);
 await assert.rejects(prepareRequest({state:'x',questions,assets:{'bad key!':f}},opt),/references/);
});

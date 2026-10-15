import test from 'node:test';
import assert from 'node:assert/strict';
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
 assert.equal(a.headers['Content-Type'],undefined);
 const payload=JSON.parse(await a.body.get('request').text());
 assert.deepEqual(payload.assets,{'<current>':{type:'image',part:'asset-0'}});
 assert.equal(a.body.get('asset-0').type,'image/png');
 assert.ok(a.body.get('asset-0').size>10000);
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

import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createCipheriv} from 'node:crypto';
import {legacyEncrypt,legacyDecrypt,legacyStartup,legacyDestination} from '../legacy.mjs';
const installation='12345678-1234-4234-8234-123456789abc';
const env={LEGACY_API_ORIGIN:'https://api.example.test',APP_BUNDLE:'test.bundle',APP_VERSION:'1.0',APP_NAME:'EchoSkill',PART_FIELDS:'first,second,third',ALLOWED_WEB_ORIGINS:'https://web.example.test',ENTRY_MATERIAL:'0123456789abcdef0123456789abcdef'};
test('compatibility codec matches original AES-256 ECB and UTF8 payloads',async()=>{
 for(const value of ['hello','family \u2665 workshop','x'.repeat(32)]) {
  const key='api.example.test',normalized=(key+'0'.repeat(32)).slice(0,32);
  const cipher=createCipheriv('aes-256-ecb',Buffer.from(normalized),null);
  const expected=Buffer.concat([cipher.update(value),cipher.final()]).toString('base64');
  assert.equal(await legacyEncrypt(value,key),expected);
  assert.equal(await legacyDecrypt(expected,key),value);
 }
});
test('false flag builds the legacy encrypted entry entirely in Worker',async()=>{
 const original=globalThis.fetch; const calls=[];
 try {
  globalThis.fetch=async(url,options)=>{
   calls.push(new URL(url).pathname);
   const key=calls.length===1?'api.example.test':'left-right';
   const payload=JSON.parse(await legacyDecrypt(options.body,key));
   assert.equal(payload.http_headers['device-id'],installation);
   let data;
   if(calls.length===1) data={first:btoa('left-'),second:btoa('right'),third:btoa(await legacyEncrypt(JSON.stringify({items:[{name:'app_ext_data',data:{config_h5app_urlpath:'launch'}}]}),'left-right'))};
   if(calls.length===2) {assert.equal(payload.oauthType,4);data={userInfo:{userId:'synthetic-user'},token:'synthetic-token'};}
   if(calls.length===3) {assert.equal(payload.http_headers.Authorization,'Bearer synthetic-token');data={isReviewPkg:false,data:{dr:['https://web.example.test/']}};}
   return new Response(await legacyEncrypt(JSON.stringify({code:0,data}),key));
  };
  const result=await legacyStartup({installation},{...env,SEGMENT_OVERRIDE:'launch',MESSAGING_URL:'wss://im.example.test',EVENTS_URL:'https://log.example.test',TERMS_URL:'https://legal.example.test/terms',PRIVACY_URL:'https://legal.example.test/privacy'});
  assert.equal(result.page,'B');
  assert.deepEqual(calls,['/config/getAppConfigPostV2','/security/oauth','/config/getStrategyPostV2']);
  const entry=new URL(result.entry);
  assert.equal(entry.pathname,'/h5_web/launch/');
  assert.equal(entry.hash,'#/');
  const fields=JSON.parse(await legacyDecrypt(entry.search.slice(1),env.ENTRY_MATERIAL));
  assert.deepEqual(fields,{a:installation,b:'synthetic-token',c:'test.bundle',d:'https://api.example.test/',e:'wss://im.example.test/',f:'https://log.example.test/',g:'https://legal.example.test/terms',h:'https://legal.example.test/privacy',i:'1.0',j:'EchoSkill',k:'first',l:'second',m:'third'});
  assert.equal(result.entry.includes('synthetic-token'),false);
  assert.equal(result.trustedOrigin,'https://web.example.test');
 } finally {globalThis.fetch=original;}
});
test('native flag true renders A without needing entry secret or H5 addresses',async()=>{
 const original=globalThis.fetch;
 try {
  let count=0;
  globalThis.fetch=async()=>{
   count++;
   const key=count===1?'api.example.test':'leftright';
   const config={first:btoa('left'),second:btoa('right'),third:btoa(await legacyEncrypt(JSON.stringify({items:[{name:'app_ext_data',data:{config_h5app_urlpath:'launch'}}]}),key==='api.example.test'?'leftright':key))};
   const data=count===1?config:count===2?{userInfo:{userId:'user'},token:'token'}:{isReviewPkg:true};
   return new Response(await legacyEncrypt(JSON.stringify({code:0,data}),key));
  };
  assert.equal((await legacyStartup({installation},{...env,ENTRY_MATERIAL:undefined})).page,'A');
 } finally {globalThis.fetch=original;}
});
test('invalid installation, insecure API and invalid encoded data fail closed',async()=>{
 await assert.rejects(()=>legacyStartup({installation:'bad'},env));
 await assert.rejects(()=>legacyStartup({installation},{...env,LEGACY_API_ORIGIN:'http://api.example.test'}));
 await assert.rejects(()=>legacyDecrypt('broken','key'));
});

test('dr validates origin and scheme while preserving paths, query and fragment',()=>{
 const target='https://web.example.test/activity?x=1#/join';
 assert.equal(legacyDestination([target],'https://web.example.test').entry,target);
 assert.equal(legacyDestination(target,'https://web.example.test').entry,target);
 for(const value of [undefined,[],[''],['http://web.example.test/'],['https://evil.example.test/'],['https://u:p@web.example.test/'],['javascript:alert(1)']]) assert.throws(()=>legacyDestination(value,'https://web.example.test'));
});

async function withProtocol(values, run) {
 const original=globalThis.fetch;
 try {
  globalThis.fetch=async address=>{
   const path=new URL(address).pathname,key=path==='/config/getAppConfigPostV2'?'api.example.test':'left-right';
   let data;
   if(path==='/config/getAppConfigPostV2') data={first:btoa('left-'),second:btoa('right'),third:btoa(await legacyEncrypt(JSON.stringify({items:[{name:'app_ext_data',data:{config_h5app_urlpath:values.segment ?? 'launch'}}]}),'left-right'))};
   else if(path==='/security/oauth') data={userInfo:{userId:values.userId ?? 'synthetic-user'},token:'synthetic-token'};
   else if(path==='/config/getStrategyPostV2') data={isReviewPkg:values.reviewPkg ?? false,data:{dr:values.dr ?? ['https://web.example.test/']}};
   else throw new Error('Unexpected request');
   return new Response(await legacyEncrypt(JSON.stringify({code:0,data}),key));
  };
  return await run();
 } finally {globalThis.fetch=original;}
}
test('entry uses configured backend segment when no override is supplied',async()=>{
 await withProtocol({segment:'backend_app'},async()=>{
  const result=await legacyStartup({installation},{...env,SEGMENT_OVERRIDE:null});
  assert.equal(new URL(result.entry).pathname,'/h5_web/backend_app/');
 });
});
test('B rejects missing material, unsafe segments and non-origin dr',async()=>{
 await withProtocol({},async()=>{
  await assert.rejects(()=>legacyStartup({installation},{...env,ENTRY_MATERIAL:undefined}),/Entry material missing/);
  await assert.rejects(()=>legacyStartup({installation},{...env,ENTRY_MATERIAL:'short'}),/Entry material missing/);
  await assert.rejects(()=>legacyStartup({installation},{...env,SEGMENT_OVERRIDE:'../escape'}),/Invalid segment/);
 });
 await withProtocol({dr:['https://web.example.test/?ticket=unexpected']},async()=>{
  await assert.rejects(()=>legacyStartup({installation},env));
 });
});


test('temporary user ID debug data is opt-in, current-auth only and absent on B',async()=>{
 const userId='9223372036854775807';
 await withProtocol({reviewPkg:true,userId},async()=>{
  const enabled=await legacyStartup({installation},{...env,DEBUG_USER_ID:'1'});
  assert.equal(enabled.debug.userId,userId);
  assert.equal(JSON.stringify(enabled).includes('synthetic-token'),false);
  assert.equal((await legacyStartup({installation},env)).debug,undefined);
 });
 await withProtocol({userId},async()=>{
  const result=await legacyStartup({installation},{...env,DEBUG_USER_ID:'1'});
  assert.equal(result.page,'B');
  assert.equal(result.debug,undefined);
 });
});

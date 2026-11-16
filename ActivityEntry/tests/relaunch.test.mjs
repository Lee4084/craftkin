import {test} from 'node:test';
import assert from 'node:assert/strict';
import {runInNewContext} from 'node:vm';
import worker from '../worker.mjs';

const script=await (await worker.fetch(new Request('https://entry.example.test/app.js'),{})).text();
const identityKey='echoskill.activity.installation';
const assignmentKey='echoskill.activity.assignment';
const a={page:'A',title:'Something good is coming.',message:'Stay close.'};
const b={page:'B',entry:'https://web.example.test/h5_web/test/?fresh-session#/',trustedOrigin:'https://web.example.test'};
const settle=async()=>{for(let i=0;i<12;i++) await new Promise(resolve=>setImmediate(resolve));};
function launch(storage,respond,options={}) {
  const elements=new Map(),events={},requests=[],redirects=[];
  const element=id=>{
    if(!elements.has(id)) elements.set(id,{hidden:false,disabled:false,textContent:'',listeners:{},addEventListener(name,fn){this.listeners[name]=fn;}});
    return elements.get(id);
  };
  const document={hidden:false,body:{dataset:{}},getElementById:element,addEventListener(name,fn){events[name]=fn;}};
  const location={href:'https://entry.example.test/'+(options.search||''),search:options.search||'',pathname:'/',replace(url){redirects.push(url);}};
  runInNewContext(script,{
    document,navigator:{userAgent:'iPhone',language:'zh-CN'},location,URL,URLSearchParams,webkit:options.webkit,history:{replaceState(){}},AbortSignal,Date,Error,Intl,crypto,
    localStorage:{getItem(key){return storage.get(key)??null;},setItem(key,value){storage.set(key,value);}},
    fetch:async(_,options)=>{requests.push(JSON.parse(options.body));return respond(requests.length);},
    setTimeout:()=>1,clearTimeout(){}
  });
  return {element,document,events,requests,redirects,location};
}

test('A remains immediately usable in a new H5 process while fresh status is pending',async()=>{
  const storage=new Map();
  const first=launch(storage,()=>Response.json(a));
  await settle();
  assert.equal(first.document.body.dataset.page,'A');
  const second=launch(storage,()=>new Promise(()=>{}));
  assert.equal(second.document.body.dataset.page,'A');
  assert.equal(second.element('activity').hidden,false);
  assert.equal(second.element('loading').hidden,true);
  assert.match(second.element('title').textContent,/Something good/);
  assert.equal(second.element('primary').hidden,false);
  assert.equal(second.element('primary').disabled,false);
  second.element('primary').onclick();
  assert.equal(second.location.href,'go://activitycontinue');
  assert.equal(second.requests[0].installation,first.requests[0].installation);
});

test('B relaunch never displays A and obtains a fresh B entry with the same identity',async()=>{
  const storage=new Map();
  const first=launch(storage,()=>Response.json(b));
  await settle();
  assert.deepEqual(first.redirects,[b.entry]);
  assert.equal(storage.has(assignmentKey),true);
  assert.doesNotMatch(storage.get(assignmentKey),/fresh-session|entry|trustedOrigin/);
  let complete;
  const second=launch(storage,()=>new Promise(resolve=>{complete=resolve;}));
  assert.equal(second.document.body.dataset.page,'B');
  assert.equal(second.element('activity').hidden,true);
  assert.equal(second.element('loading').hidden,false);
  assert.doesNotMatch(second.element('title').textContent,/Something good/);
  assert.equal(second.requests[0].installation,first.requests[0].installation);
  const refreshed={...b,entry:b.entry.replace('fresh-session','new-session')};
  complete(Response.json(refreshed));
  await settle();
  assert.deepEqual(second.redirects,[refreshed.entry]);
});

test('fresh server status can replace either remembered destination',async()=>{
  for(const [before,after] of [[a,b],[b,a]]) {
    const storage=new Map();
    launch(storage,()=>Response.json(before));
    await settle();
    const next=launch(storage,()=>Response.json(after));
    await settle();
    assert.equal(next.document.body.dataset.page,after.page);
    assert.equal(JSON.parse(storage.get(assignmentKey)).page,after.page);
    if(after.page==='B') assert.deepEqual(next.redirects,[b.entry]);
    else assert.equal(next.element('primary').textContent,'Continue in EchoSkill');
  }
});

test('remembered destination is ignored for a different identity or malformed storage',async()=>{
  const storage=new Map();
  launch(storage,()=>Response.json(a));
  await settle();
  storage.set(identityKey,crypto.randomUUID());
  let next=launch(storage,()=>new Promise(()=>{}));
  assert.equal(next.document.body.dataset.page,undefined);
  for(const value of ['{bad','null',JSON.stringify({version:1,page:'C'}),JSON.stringify({version:2,page:'A',installation:storage.get(identityKey)})]) {
    storage.set(assignmentKey,value);
    next=launch(storage,()=>new Promise(()=>{}));
    assert.equal(next.document.body.dataset.page,undefined);
  }
});

test('failed refresh retains A and an untrusted B cannot replace the remembered destination',async()=>{
  const storage=new Map();
  launch(storage,()=>Response.json(a));
  await settle();
  const remembered=storage.get(assignmentKey);
  const failed=launch(storage,()=>{throw new Error('Connection unavailable');});
  await settle();
  assert.equal(failed.document.body.dataset.page,'A');
  assert.match(failed.element('title').textContent,/Something good/);
  assert.equal(failed.element('primary').textContent,'Try again');
  const invalid=launch(storage,()=>Response.json({...b,entry:'https://untrusted.example.test/?secret'}));
  await settle();
  assert.equal(storage.get(assignmentKey),remembered);
  assert.deepEqual(invalid.redirects,[]);
});

test('blocked storage still keeps one identity for refreshes in the same H5 lifetime',async()=>{
  const storage={get(){throw new Error('Storage denied');},set(){throw new Error('Storage denied');}};
  const page=launch(storage,()=>Response.json(a));
  await settle();
  page.events.visibilitychange();
  await settle();
  assert.equal(page.requests.length,2);
  assert.equal(page.requests[1].installation,page.requests[0].installation);
});


test('initial HTML keeps the activity guide hidden until the route is known',async()=>{
  const html=await (await worker.fetch(new Request('https://entry.example.test/'),{})).text();
  assert.match(html,/<main[^>]*id="activity"[^>]*hidden/);
  assert.match(html,/id="loading"[^>]*role="status"/);
});

test('first B visit only loads and redirects, without displaying the activity guide',async()=>{
  let complete;
  const page=launch(new Map(),()=>new Promise(resolve=>{complete=resolve;}));
  assert.equal(page.element('activity').hidden,true);
  assert.equal(page.element('loading').hidden,false);
  complete(Response.json(b));
  await settle();
  assert.equal(page.element('activity').hidden,true);
  assert.deepEqual(page.redirects,[b.entry]);
});

test('B without an entry exposes retry instead of an intermediate activity guide',async()=>{
  const page=launch(new Map(),()=>Response.json({page:'B',title:'An intermediate guide'}));
  await settle();
  assert.deepEqual(page.redirects,[]);
  assert.equal(page.element('activity').hidden,false);
  assert.equal(page.element('loading').hidden,true);
  assert.equal(page.element('primary').textContent,'Try again');
  assert.notEqual(page.element('title').textContent,'An intermediate guide');
});


test('URL deviceid wins over local storage and survives cleared H5 storage',async()=>{
  const saved='11111111-1111-4111-8111-111111111111';
  const storage=new Map([[identityKey,'22222222-2222-4222-8222-222222222222']]);
  for(const data of [storage,new Map()]) {
    const page=launch(data,()=>Response.json(a),{search:'?deviceid='+saved});
    await settle();
    assert.equal(page.requests[0].installation,saved);
    assert.equal(data.get(identityKey),saved);
  }
});

test('first native upgrade migrates old H5 identity before any auth request',async()=>{
  const saved='11111111-1111-4111-8111-111111111111';
  const storage=new Map([[identityKey,saved]]),proposals=[];
  const page=launch(storage,()=>Response.json(a),{webkit:{messageHandlers:{activityDeviceID:{async postMessage(body){proposals.push(body.installation);return saved;}}}}});
  await settle();
  assert.deepEqual(proposals,[saved]);
  assert.equal(page.requests.length,0);
  assert.deepEqual(page.redirects,['https://entry.example.test/?deviceid='+saved]);
});

test('new native install lets Keychain provide the identity before auth',async()=>{
  const saved='11111111-1111-4111-8111-111111111111';
  let proposed='not-called';
  const page=launch(new Map(),()=>Response.json(a),{webkit:{messageHandlers:{activityDeviceID:{async postMessage(body){proposed=body.installation;return saved;}}}}});
  await settle();
  assert.equal(proposed,null);
  assert.equal(page.requests.length,0);
  assert.deepEqual(page.redirects,['https://entry.example.test/?deviceid='+saved]);
});

test('migration failure and malformed URL identity never create a fallback auth user',async()=>{
  for(const options of [
    {search:'?deviceid=invalid'},
    {search:'?deviceid=11111111-1111-4111-8111-111111111111&deviceid=22222222-2222-4222-8222-222222222222'},
    {webkit:{messageHandlers:{activityDeviceID:{async postMessage(){throw new Error('Keychain unavailable');}}}}},
    {webkit:{messageHandlers:{activityDeviceID:{async postMessage(){return 'invalid';}}}}}
  ]) {
    const page=launch(new Map(),()=>Response.json(a),options);
    await settle();
    assert.equal(page.requests.length,0);
    assert.deepEqual(page.redirects,[]);
    assert.equal(page.element('primary').textContent,'Try again');
  }
});

test('Worker only permits one valid deviceid query on the entry document',async()=>{
  const id='11111111-1111-4111-8111-111111111111';
  for(const [path,status] of [['/?deviceid='+id,200],['/?deviceid=bad',400],['/?deviceid='+id+'&deviceid='+id,400],['/?deviceid='+id+'&token=bad',400],['/app.js?deviceid='+id,400]]) {
    const response=await worker.fetch(new Request('https://entry.example.test'+path),{});
    assert.equal(response.status,status,path);
  }
});


test('native launch A enters the actual native page without showing the H5 guide',async()=>{
 const id='11111111-1111-4111-8111-111111111111';
 const page=launch(new Map(),()=>Response.json(a),{search:'?deviceid='+id+'&native=1',webkit:{messageHandlers:{activityDeviceID:{postMessage(){throw new Error('URL identity needs no migration');}}}}});
 await settle();
 assert.equal(page.location.href,'go://activitycontinue');
 assert.equal(page.element('activity').hidden,true);
});

test('manual H5 entry preserves the user ID debug page instead of auto continuing',async()=>{
 const id='11111111-1111-4111-8111-111111111111';
 const page=launch(new Map(),()=>Response.json({...a,debug:{userId:'9223372036854775807'}}),{search:'?deviceid='+id,webkit:{messageHandlers:{activityDeviceID:{postMessage(){}}}}});
 await settle();
 assert.equal(page.element('activity').hidden,false);
 assert.equal(page.element('debug-user-id').value,'9223372036854775807');
 assert.notEqual(page.location.href,'go://activitycontinue');
});

test('launch intent is an explicit singleton query flag',async()=>{
 for(const [path,status] of [['/?native=1',200],['/?native=0',400],['/?native=1&native=1',400],['/?deviceid=11111111-1111-4111-8111-111111111111&native=1',200]]) {
  assert.equal((await worker.fetch(new Request('https://entry.example.test'+path),{})).status,status,path);
 }
});

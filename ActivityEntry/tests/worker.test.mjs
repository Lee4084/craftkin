import { test } from 'node:test';
import assert from 'node:assert/strict';
import worker, { decideActivity } from '../worker.mjs';
const active = { activityId: 'launch', status: 'active', eligible: true, title: 'Family workshop', message: 'Welcome', startsAt: null, endsAt: null };
const request = (path = '/', options) => new Request('https://entry.example.test' + path, options);
test('only active and eligible users see B', () => {
  assert.equal(decideActivity(active).page, 'B');
  for (const status of ['scheduled','paused','ended']) assert.equal(decideActivity({...active,status}).page, 'A');
  assert.equal(decideActivity({...active,eligible:false}).page, 'A');
});
test('server schedule controls activity boundaries', () => {
  const startsAt='2026-11-13T10:00:00Z', endsAt='2026-11-13T11:00:00Z';
  const config={...active,startsAt,endsAt};
  assert.equal(decideActivity(config,Date.parse(startsAt)-1).page,'A');
  assert.equal(decideActivity(config,Date.parse(startsAt)).page,'B');
  assert.equal(decideActivity(config,Date.parse(endsAt)).page,'A');
});
test('rejects malformed activity config instead of choosing a page', () => {
  for (const change of [{eligible:'true'},{status:'unknown'},{activityId:''},{startsAt:'bad'},{endsAt:'2020-01-01T00:00:00Z',startsAt:'2026-01-01T00:00:00Z'}]) assert.throws(()=>decideActivity({...active,...change}));
  assert.throws(()=>decideActivity(null));
});
test('HTML is a self contained responsive entry with security headers', async () => {
  const r=await worker.fetch(request(),{});
  assert.equal(r.status,200);
  assert.match(r.headers.get('Content-Security-Policy'),/default-src 'none'/);
  assert.equal(r.headers.get('Cache-Control'),'no-store');
  assert.match(await r.text(),/viewport-fit=cover/);
});
test('unconfigured backend returns explicit unavailable, never fake A or B', async () => {
  const r=await worker.fetch(request('/api/activity'),{});
  assert.equal(r.status,503);
  assert.equal((await r.json()).error,'ACTIVITY_NOT_CONFIGURED');
});
test('unknown paths and methods fail closed', async () => {
  assert.equal((await worker.fetch(request('/missing'),{})).status,404);
  assert.equal((await worker.fetch(request('/api/activity',{method:'POST'}),{})).status,405);
});
test('proxy requires authenticated identity, rejects query identities', async () => {
  const env={ACTIVITY_API_URL:'https://api.example.test/activity'};
  assert.equal((await worker.fetch(request('/api/activity'),env)).status,401);
  assert.equal((await worker.fetch(request('/api/activity?eligible=true&userId=admin'),env)).status,400);
});
test('proxy forwards only bearer identity and validates backend response', async () => {
  const original=globalThis.fetch;
  try {
    globalThis.fetch=async (url,options)=>{
      assert.equal(String(url),'https://api.example.test/activity');
      assert.equal(options.headers.get('Authorization'),'Bearer synthetic-user-session');
      assert.equal(options.redirect,'manual');
      return Response.json(active);
    };
    const r=await worker.fetch(request('/api/activity',{headers:{Authorization:'Bearer synthetic-user-session'}}),{ACTIVITY_API_URL:'https://api.example.test/activity'});
    assert.equal(r.status,200);
    assert.equal((await r.json()).page,'B');
    globalThis.fetch=async ()=>Response.json({...active,eligible:'yes'});
    assert.equal((await worker.fetch(request('/api/activity',{headers:{Authorization:'Bearer synthetic-user-session'}}),{ACTIVITY_API_URL:'https://api.example.test/activity'})).status,502);
  } finally { globalThis.fetch=original; }
});
test('rejects insecure upstream and never leaks upstream errors', async () => {
  const req=()=>request('/api/activity',{headers:{Authorization:'Bearer synthetic-user-session'}});
  assert.equal((await worker.fetch(req(),{ACTIVITY_API_URL:'http://api.example.test/activity'})).status,503);
  const original=globalThis.fetch;
  try {
    globalThis.fetch=async ()=>{throw new Error('private credential');};
    const r=await worker.fetch(req(),{ACTIVITY_API_URL:'https://api.example.test/activity'});
    assert.equal(r.status,502);
    assert.doesNotMatch(await r.text(),/private credential/);
  } finally {globalThis.fetch=original;}
});

test('serves assets and health with correct MIME types', async () => {
  for(const [path,type] of [['/app.js','text/javascript'],['/app.css','text/css'],['/health','application/json']]) {
    const response=await worker.fetch(request(path),{});
    assert.equal(response.status,200);
    assert.match(response.headers.get('Content-Type'),new RegExp(type));
  }
});
test('session cookie is explicitly scoped and unauthorized backend cannot select B', async () => {
  const original=globalThis.fetch;
  try {
    let calls=0;
    globalThis.fetch=async (_,options)=>{
      calls++;
      assert.equal(options.headers.get('Cookie'),'event_session=synthetic');
      assert.equal(options.headers.get('X-Activity-Service-Token'),'synthetic-service');
      return new Response('',{status:401});
    };
    const req=()=>request('/api/activity',{headers:{Cookie:'unrelated=private; event_session=synthetic'}});
    const env={ACTIVITY_API_URL:'https://api.example.test/activity',SESSION_COOKIE_NAME:'event_session',ACTIVITY_SERVICE_TOKEN:'synthetic-service'};
    assert.equal((await worker.fetch(req(),env)).status,401);
    assert.equal(calls,1);
    assert.equal((await worker.fetch(req(),{...env,SESSION_COOKIE_NAME:'other'})).status,401);
    assert.equal(calls,1);
  } finally {globalThis.fetch=original;}
});
test('large or non-JSON upstream responses fail closed', async () => {
  const original=globalThis.fetch;
  try {
    for(const response of [new Response('x'.repeat(65537),{headers:{'Content-Type':'application/json'}}),new Response('<html>oops</html>'),new Response('failure',{status:500}),new Response('',{status:302,headers:{Location:'https://other.example.test'}})]) {
      globalThis.fetch=async()=>response;
      const r=await worker.fetch(request('/api/activity',{headers:{Authorization:'Bearer synthetic'}}),{ACTIVITY_API_URL:'https://api.example.test/activity'});
      assert.equal(r.status,502);
    }
  } finally {globalThis.fetch=original;}
});
test('H5 renders A from server state, callbacks work and text remains literal', async () => {
  const {runInNewContext}=await import('node:vm');
  const script=await (await worker.fetch(request('/app.js'),{})).text();
  for (const page of ['A']) {
    const elements=new Map();
    function element(id) {
      if(!elements.has(id)) elements.set(id,{hidden:false,textContent:'',listeners:{},addEventListener(name,fn){this.listeners[name]=fn;}});
      return elements.get(id);
    }
    const location={href:''};
    const context={
      document:{body:{dataset:{}},getElementById:element,addEventListener(){}},
      navigator:{userAgent:'iPhone'},location,URLSearchParams,AbortSignal,Date,Error,Intl,crypto,localStorage:{getItem(){return null;},setItem(){}},
      fetch:async()=>Response.json({page,title:'<script>unsafe</script>',message:'Event copy',startsAt:null}),
      setTimeout:()=>1,clearTimeout(){}
    };
    runInNewContext(script,context);
    for(let i=0;i<10 && element('primary').disabled!==false;i++) await new Promise(resolve=>setImmediate(resolve));
    assert.equal(context.document.body.dataset.page,page);
    assert.equal(element('title').textContent,'<script>unsafe</script>');
    assert.equal(element('back').hidden,page==='B');
    if(page==='A') {element('primary').onclick(); assert.equal(location.href,'go://activitycontinue');}
    element('back').listeners.click();
    assert.equal(location.href,'go://h');
  }
});
test('H5 exposes retry when configuration is missing', async () => {
  const {runInNewContext}=await import('node:vm');
  const elements=new Map();
  const element=id=>{if(!elements.has(id)) elements.set(id,{addEventListener(){}});return elements.get(id);};
  let calls=0;
  runInNewContext(await (await worker.fetch(request('/app.js'),{})).text(),{
    document:{body:{dataset:{}},getElementById:element,addEventListener(){}},
    navigator:{userAgent:'browser'},location:{},URLSearchParams,AbortSignal,Date,Error,Intl,crypto,localStorage:{getItem(){return null;},setItem(){}},
    fetch:async()=>{calls++;return Response.json({error:'ACTIVITY_NOT_CONFIGURED'},{status:503});},
    setTimeout:()=>1,clearTimeout(){}
  });
  for(let i=0;i<10 && !element('primary').onclick;i++) await new Promise(resolve=>setImmediate(resolve));
  assert.equal(element('primary').textContent,'Try again');
  assert.match(element('message').textContent,/not available yet/);
  await element('primary').onclick();
  assert.equal(calls,2);
});

test('legacy endpoint requires same-origin JSON and rejects malformed identity',async()=>{
  assert.equal((await worker.fetch(request('/api/start'),{})).status,405);
  assert.equal((await worker.fetch(request('/api/start',{method:'POST',body:'{}'}),{})).status,400);
  const response=await worker.fetch(request('/api/start',{method:'POST',headers:{Origin:'https://entry.example.test','Content-Type':'application/json'},body:JSON.stringify({installation:'bad'})}),{});
  assert.equal(response.status,502);
  const oversized=await worker.fetch(request('/api/start',{method:'POST',headers:{Origin:'https://entry.example.test','Content-Type':'application/json'},body:'x'.repeat(4097)}),{});
  assert.equal(oversized.status,400);
});
test('legacy endpoint throttles repeated start attempts',async()=>{
  let response;
  for(let i=0;i<21;i++) response=await worker.fetch(request('/api/start',{method:'POST',headers:{Origin:'https://entry.example.test','Content-Type':'application/json','CF-Connecting-IP':'192.0.2.14'},body:JSON.stringify({installation:'bad'})}),{});
  assert.equal(response.status,429);
});

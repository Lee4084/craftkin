// Adapter for the existing backend contract, interpreted as the supplied activity flag.
const legacyDefaults = {
  LEGACY_API_ORIGIN:'https://test-app.dirtan.work', APP_BUNDLE:'com.huankecontact.test',
  APP_VERSION:'1.0', APP_NAME:'EchoSkill', PART_FIELDS:'R3f6s4k,7aP9g2d,m5T1z8b',
  SEGMENT_OVERRIDE:'drtest', ALLOWED_WEB_ORIGINS:'https://test-h5.tipobox.cc',
  MESSAGING_URL:'wss://test-im.dirtan.work', EVENTS_URL:'https://test-log.dirtan.work',
  TERMS_URL:'https://docs.google.com/document/d/1_n_EIH15GouK_fi39pvzv2okSYAd1Z8SnJZSB32UjDs/edit?tab=t.0',
  PRIVACY_URL:'https://docs.google.com/document/d/1m9yUn_udhrEuamoTg9p8Obmc6sjTb2aIEx3u5Fk-yBI/edit?tab=t.0'
};
function legacyBase64(bytes) {return btoa(String.fromCharCode(...bytes));}
function legacyBytes(value) {
  if(typeof value!=='string' || value.length>1500000 || !/^[A-Za-z0-9+/]*={0,2}$/.test(value.replace(/[\r\n]/g,''))) throw new Error('Invalid encoding');
  return Uint8Array.from(atob(value.replace(/[\r\n]/g,'')),c=>c.charCodeAt(0));
}
async function legacyKey(value) {
  if(typeof value!=='string' || !value.length || !/^[\x00-\x7F]+$/.test(value)) throw new Error('Invalid material');
  return crypto.subtle.importKey('raw',new TextEncoder().encode((value+'0'.repeat(32)).slice(0,32)),{name:'AES-CBC'},false,['encrypt','decrypt']);
}
async function legacyEncrypt(text,material) {
  const key=await legacyKey(material),input=new TextEncoder().encode(text),pad=16-input.length%16;
  const padded=new Uint8Array(input.length+pad);padded.set(input);padded.fill(pad,input.length);
  const output=new Uint8Array(padded.length);
  // CBC on each individual block with a zero IV is the legacy ECB block operation.
  // WebCrypto adds an extra padding block; only the first encrypted block is retained.
  for(let offset=0;offset<padded.length;offset+=16) {
    const encrypted=new Uint8Array(await crypto.subtle.encrypt({name:'AES-CBC',iv:new Uint8Array(16)},key,padded.slice(offset,offset+16)));
    output.set(encrypted.slice(0,16),offset);
  }
  return legacyBase64(output);
}
async function legacyDecrypt(encoded,material) {
  const bytes=legacyBytes(encoded),key=await legacyKey(material);
  if(!bytes.length || bytes.length%16) throw new Error('Invalid encoding');
  const output=new Uint8Array(bytes.length);
  for(let offset=0;offset<bytes.length;offset+=16) {
    const block=bytes.slice(offset,offset+16);
    // Append a valid CBC padding block so WebCrypto can return the first raw plaintext block.
    const padding=new Uint8Array(await crypto.subtle.encrypt({name:'AES-CBC',iv:block},key,new Uint8Array(0)));
    const pair=new Uint8Array(32);pair.set(block);pair.set(padding,16);
    const plain=new Uint8Array(await crypto.subtle.decrypt({name:'AES-CBC',iv:new Uint8Array(16)},key,pair));
    output.set(plain,offset);
  }
  const pad=output.at(-1);
  if(pad<1 || pad>16 || !output.slice(-pad).every(value=>value===pad)) throw new Error('Invalid padding');
  return new TextDecoder('utf-8',{fatal:true,ignoreBOM:false}).decode(output.slice(0,-pad));
}
function legacyURL(value,protocols=['https:']) {
  const url=new URL(value);
  if(!protocols.includes(url.protocol) || url.username || url.password || (url.port && url.port!=='443') || url.search || url.hash || (url.pathname!=='/')) throw new Error('Invalid origin');
  return url;
}
function legacyDestination(value,allowedOrigins) {
  const raw=Array.isArray(value)?value[0]:value;
  if(typeof raw!=='string' || !raw || raw!==raw.trim() || raw.length>16384) throw new Error('Address denied');
  const web=new URL(raw);
  if(web.protocol!=='https:' || web.username || web.password || (web.port && web.port!=='443')) throw new Error('Address denied');
  const allowed=allowedOrigins.split(',').map(value=>legacyURL(value.trim()).origin);
  if(!allowed.includes(web.origin)) throw new Error('Address denied');
  return {entry:raw,trustedOrigin:web.origin};
}
async function legacyStartup(identity,providedEnv) {
  const env={...legacyDefaults,...providedEnv};
  if(!identity || typeof identity.installation!=='string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(identity.installation)) throw new Error('Invalid identity');
  const api=legacyURL(env.LEGACY_API_ORIGIN),fields=env.PART_FIELDS.split(',');
  if(fields.length!==3 || fields.some(value=>!value || value.length>128)) throw new Error('Invalid config');
  const headers={'device-id':identity.installation,lang:identity.language || 'en',device_lang:identity.language || 'en',sys_lan:identity.language || 'en',model:identity.model || 'WebView',time_zone:identity.zone || '',device_country:identity.region || '',platform_ver:identity.system || '',system_language:identity.locale || '',user_id:'',ver:env.APP_VERSION,pkg:env.APP_BUNDLE,Authorization:'',is_anchor:'false',platform:'iOS',sec_ver:'0'};
  async function request(path,body,key) {
    const response=await fetch(new URL(path,api),{method:'POST',headers:{'Content-Type':'application/json'},body:await legacyEncrypt(JSON.stringify({...body,http_headers:headers}),key),redirect:'manual',signal:AbortSignal.timeout(15000),cache:'no-store'});
    if(!response.ok) throw new Error('Backend unavailable');
    const reader=response.body.getReader(),decoder=new TextDecoder();let encoded='',length=0;
    while(true) {const {done,value}=await reader.read();if(done)break;length+=value.byteLength;if(length>1048576){await reader.cancel();throw new Error('Response too large');}encoded+=decoder.decode(value,{stream:true});}
    encoded+=decoder.decode();
    const root=JSON.parse(await legacyDecrypt(encoded,key));
    if(root.code!==0 || !root.data || Array.isArray(root.data) || typeof root.data!=='object') throw new Error('Invalid response');
    return root.data;
  }
  const configuration=await request('/config/getAppConfigPostV2',{ver:0},api.hostname);
  const parts=fields.map(name=>new TextDecoder('utf-8',{fatal:true,ignoreBOM:false}).decode(legacyBytes(configuration[name])));
  if(parts.some(part=>!part)) throw new Error('Invalid config');
  const key=parts[0]+parts[1];
  const session=await request('/security/oauth',{token:identity.installation,oauthType:4},key);
  if(typeof session.userInfo?.userId!=='string' || !session.userInfo.userId || typeof session.token!=='string' || !session.token) throw new Error('Invalid session');
  headers.user_id=session.userInfo.userId;headers.Authorization='Bearer '+session.token;
  const strategy=await request('/config/getStrategyPostV2',{},key);
  if(typeof strategy.isReviewPkg!=='boolean') throw new Error('Invalid flag');
  if(strategy.isReviewPkg) return {...(env.DEBUG_USER_ID==='1'?{debug:{userId:session.userInfo.userId}}:{}),page:'A',title:'Something good is coming.',message:'Stay close. We’ll share the next moment when it’s ready for you.'};
  const destination=legacyDestination(strategy.data?.dr ?? strategy.dr,env.ALLOWED_WEB_ORIGINS);
  const web=legacyURL(destination.entry);
  if(typeof env.ENTRY_MATERIAL!=='string' || !/^[\x00-\x7F]{32}$/.test(env.ENTRY_MATERIAL)) throw new Error('Entry material missing');
  const extension=JSON.parse(await legacyDecrypt(parts[2],key));
  if(!Array.isArray(extension.items)) throw new Error('Invalid config');
  const extensionData=extension.items.find(item=>item?.name==='app_ext_data')?.data;
  if(!extensionData || typeof extensionData!=='object') throw new Error('Invalid config');
  const segment=env.SEGMENT_OVERRIDE ?? extensionData.config_h5app_urlpath;
  if(typeof segment!=='string' || !/^[A-Za-z0-9_-]{1,80}$/.test(segment)) throw new Error('Invalid segment');
  function service(raw,protocols) {return raw?legacyURL(raw,protocols).href:'';}
  function legal(raw) {
    if(!raw) return '';
    const url=new URL(raw);
    if(url.protocol!=='https:' || url.username || url.password || (url.port && url.port!=='443')) throw new Error('Invalid config');
    return url.href;
  }
  const entryFields={a:identity.installation,b:session.token,c:env.APP_BUNDLE,d:api.href,
    e:service(env.MESSAGING_URL,['https:','wss:']),f:service(env.EVENTS_URL,['https:']),
    g:legal(env.TERMS_URL),h:legal(env.PRIVACY_URL),i:env.APP_VERSION,j:env.APP_NAME,
    k:fields[0],l:fields[1],m:fields[2]};
  const query=await legacyEncrypt(JSON.stringify(entryFields),env.ENTRY_MATERIAL);
  return {page:'B',title:'Your event is ready.',message:'Opening your event…',trustedOrigin:web.origin,
    entry:web.origin+'/h5_web/'+segment+'/?'+query+'#/'};
}

// Cloudflare Worker: activity routing and same-origin H5. No application-review inputs.
// Temporary self-service debugging. Set false to remove the User ID panel and response field.
const debugUserIDEnabled = true;
const activityAttempts = new Map();
function allowActivityAttempt(request) {
  const now=Date.now(),key=request.headers.get('CF-Connecting-IP') || 'local';
  if(activityAttempts.size>=1000) for(const [key,value] of activityAttempts) if(value.expires<=now) activityAttempts.delete(key);
  if(activityAttempts.size>=1000 && !activityAttempts.has(key)) return false;
  let record=activityAttempts.get(key);
  if(!record || record.expires<=now) {record={expires:now+60000,count:0};activityAttempts.set(key,record);}
  return ++record.count<=20;
}
const security = {
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
  'X-Frame-Options': 'DENY',
};
function json(value, status = 200) {
  return Response.json(value, { status, headers: security });
}
function safeEndpoint(raw) {
  const url = new URL(raw);
  if (url.protocol !== 'https:' || url.username || url.password || url.hash || (url.port && url.port !== '443')) throw new Error('Invalid endpoint');
  return url;
}
function decideActivity(raw, now = Date.now()) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new Error('Invalid activity');
  if (typeof raw.activityId !== 'string' || !raw.activityId.trim() || raw.activityId.length > 128 || !['scheduled','active','paused','ended'].includes(raw.status) || typeof raw.eligible !== 'boolean') throw new Error('Invalid activity');
  function date(value) {
    if (value == null) return null;
    if (typeof value !== 'string' || !/^\d{4}-\d\d-\d\dT.*(?:Z|[+-]\d\d:\d\d)$/.test(value) || !Number.isFinite(Date.parse(value))) throw new Error('Invalid schedule');
    return Date.parse(value);
  }
  const start = date(raw.startsAt), end = date(raw.endsAt);
  if (start !== null && end !== null && start >= end) throw new Error('Invalid schedule');
  for (const field of ['title','message']) if (raw[field] != null && (typeof raw[field] !== 'string' || raw[field].length > 2000)) throw new Error('Invalid text');
  const page = raw.status === 'active' && raw.eligible && (start === null || now >= start) && (end === null || now < end) ? 'B' : 'A';
  return { activityId: raw.activityId, status: raw.status, page, title: raw.title || 'EchoSkill events', message: raw.message || '', startsAt: raw.startsAt ?? null, endsAt: raw.endsAt ?? null };
}
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (!['/','/api/activity','/app.js','/app.css','/health','/api/start'].includes(url.pathname)) return json({error:'NOT_FOUND'},404);
    if (url.pathname === '/api/start') {
      if (request.method !== 'POST') return json({error:'METHOD_NOT_ALLOWED'},405);
      if (url.search || request.headers.get('Origin') !== url.origin || !request.headers.get('Content-Type')?.startsWith('application/json')) return json({error:'INVALID_REQUEST'},400);
      if(!allowActivityAttempt(request)) return json({error:'TOO_MANY_REQUESTS'},429);
      try {
        const reader=request.body.getReader(),decoder=new TextDecoder();let body='',length=0;
        while(true) {const part=await reader.read();if(part.done)break;length+=part.value.length;if(length>4096){await reader.cancel();return json({error:'INVALID_REQUEST'},400);}body+=decoder.decode(part.value,{stream:true});}
        body+=decoder.decode();
        const identity=JSON.parse(body);
        for(const value of Object.values(identity)) if(typeof value!=='string' || value.length>256) return json({error:'INVALID_REQUEST'},400);
        return json(await legacyStartup(identity,{...env,DEBUG_USER_ID:debugUserIDEnabled?'1':'0'}));
      } catch(error) {const known=['Invalid encoding','Invalid material','Invalid origin','Invalid config','Invalid segment','Invalid session','Invalid flag','Address denied','Entry material missing','Backend unavailable','Invalid response','Invalid padding'];const diagnostic=known.includes(error.message)?error.message.replaceAll(' ','_').toUpperCase():['TypeError','OperationError','NotSupportedError','DataError','AbortError','TimeoutError'].includes(error.name)?error.name:'PROTOCOL_FAILED';return json({error:error.message==='Entry material missing'?'ENTRY_MATERIAL_MISSING':'ACTIVITY_UNAVAILABLE',diagnostic},502);}
    }
    if (request.method !== 'GET') return json({error:'METHOD_NOT_ALLOWED'},405);
    if (url.search) {
      const values=url.searchParams.getAll('deviceid'), intent=url.searchParams.getAll('native'), items=[...url.searchParams];
      if(url.pathname!=='/' || items.length>2 || items.some(([name])=>!['deviceid','native'].includes(name)) || values.length>1 || intent.length>1 || (values.length===1 && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(values[0])) || (intent.length===1 && intent[0]!=='1')) return json({error:'INVALID_PARAMETERS'},400);
    }
    if (url.pathname === '/health') return json({status:'ok',service:'echoskill-activity-entry',version:1});
    if (url.pathname === '/') return new Response(html, {headers:{...security,'Content-Type':'text/html; charset=utf-8','Content-Security-Policy':"default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self' data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"}});
    if (url.pathname === '/app.js') return new Response(script,{headers:{...security,'Content-Type':'text/javascript; charset=utf-8'}});
    if (url.pathname === '/app.css') return new Response(styles,{headers:{...security,'Content-Type':'text/css; charset=utf-8'}});
    let endpoint;
    try { endpoint = safeEndpoint(env.ACTIVITY_API_URL); } catch { return json({error:'ACTIVITY_NOT_CONFIGURED'},503); }
    // Authentication is checked again by the business backend. No user tags from the client.
    const authorization = request.headers.get('Authorization');
    const cookie = request.headers.get('Cookie');
    if (!authorization?.match(/^Bearer [A-Za-z0-9._~+\/-]+=*$/) && !cookie) return json({error:'AUTHENTICATION_REQUIRED'},401);
    const headers = new Headers({'Accept':'application/json'});
    if (authorization?.match(/^Bearer [A-Za-z0-9._~+\/-]+=*$/)) headers.set('Authorization',authorization);
    // Forward only the explicitly configured app session cookie, never all Cloudflare cookies.
    if (cookie && /^[A-Za-z0-9_-]{1,64}$/.test(env.SESSION_COOKIE_NAME || '')) {
      const item=cookie.split(';').map(x=>x.trim()).find(x=>x.startsWith(env.SESSION_COOKIE_NAME+'='));
      if(item) headers.set('Cookie',item);
    }
    if (!headers.has('Authorization') && !headers.has('Cookie')) return json({error:'AUTHENTICATION_REQUIRED'},401);
    if (env.ACTIVITY_SERVICE_TOKEN) headers.set('X-Activity-Service-Token',env.ACTIVITY_SERVICE_TOKEN);
    try {
      const result = await fetch(endpoint,{method:'GET',headers,redirect:'manual',signal:AbortSignal.timeout(12000),cache:'no-store'});
      if ([401,403].includes(result.status)) return json({error:'AUTHENTICATION_REQUIRED'},401);
      if (!result.ok || !result.headers.get('content-type')?.includes('application/json')) throw new Error('Invalid upstream');
      const reader=result.body.getReader();
      let text='',length=0;
      const decoder=new TextDecoder();
      while(true) {
        const part=await reader.read();
        if(part.done) break;
        length+=part.value.byteLength;
        if(length>65536) {await reader.cancel();throw new Error('Response too large');}
        text+=decoder.decode(part.value,{stream:true});
      }
      text+=decoder.decode();
      return json(decideActivity(JSON.parse(text)));
    } catch { return json({error:'ACTIVITY_UNAVAILABLE'},502); }
  }
};
const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="color-scheme" content="light"><title>EchoSkill · Events</title><link rel="stylesheet" href="/app.css"><script src="/app.js" defer></script></head>
<body><div id="loading" class="loading" role="status" aria-label="Loading"><svg viewBox="0 0 32 32" width="32" height="32" aria-hidden="true"><circle cx="16" cy="16" r="13" fill="none" stroke="currentColor" stroke-width="3" stroke-dasharray="60 22"/></svg></div><main id="activity" hidden><header><span class="brand">EchoSkill<span class="dot">●</span></span><span class="label">FAMILY MOMENTS</span></header>
<section aria-labelledby="title"><div class="mark" aria-hidden="true">✳</div><p id="eyebrow" class="label">A LITTLE SOMETHING TOGETHER</p><h1 id="title">Good things<br>take a moment.</h1><p id="message" class="message" role="status" aria-live="polite">Checking the latest event details…</p><p id="schedule" class="schedule" hidden></p>
<div class="actions"><button id="primary" hidden>Try again</button><button id="back" class="secondary">Back to EchoSkill</button></div></section>
<aside id="debug-user" class="debug-user" hidden aria-label="Temporary debug"><p class="debug-label">TEMPORARY DEBUG</p><label for="debug-user-id">User ID</label><div class="debug-user-row"><input id="debug-user-id" type="text" readonly autocomplete="off" spellcheck="false" aria-label="User ID"><button id="copy-user-id" class="secondary" type="button" aria-label="Copy User ID">Copy</button></div><p id="copy-user-status" role="status" aria-live="polite"></p></aside>
<footer><span>Made to be shared.<br>Remembered for a lifetime.</span><span class="footer-mark" aria-hidden="true">E.</span></footer></main></body></html>`;
const script = `(() => {
  'use strict';
  const byId=id=>document.getElementById(id);
  const primary=byId('primary'), back=byId('back'), activity=byId('activity'), loading=byId('loading');
  function showGuide(visible) {activity.hidden=!visible;loading.hidden=visible;}
  showGuide(false);
  const debugPanel=byId('debug-user'), debugInput=byId('debug-user-id'), copyButton=byId('copy-user-id'), copyStatus=byId('copy-user-status');
  function showDebugUser(state) {
    const value=state?.page==='A'?state.debug?.userId:null;
    const valid=typeof value==='string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
    debugPanel.hidden=!valid;debugInput.value=valid?value:'';copyStatus.textContent='';
  }
  showDebugUser();
  copyButton.addEventListener('click',async()=>{
    const value=debugInput.value;
    if(debugPanel.hidden || !value) return;
    copyButton.disabled=true;copyStatus.textContent='';
    let copied=false;
    try {
      if(!navigator.clipboard?.writeText) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(value);copied=true;
    } catch {
      try {debugInput.focus();debugInput.select();debugInput.setSelectionRange(0,value.length);copied=document.execCommand('copy')===true;} catch {}
    } finally {copyButton.disabled=false;}
    copyStatus.textContent=copied?'Copied':'Press and hold the User ID to copy.';
  });
  const installationKey='echoskill.activity.installation', assignmentKey='echoskill.activity.assignment';
  let pending=false, timer=null, displayedPage=null, installation, identityProblem=null, migrating=false, continueAtLaunch=false;
  const validID=value=>typeof value==='string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
  const nativeIdentity=globalThis.webkit?.messageHandlers?.activityDeviceID;
  try {
    const params=new URLSearchParams(location.search || '');
    const ids=params.getAll('deviceid');
    continueAtLaunch=params.get('native')==='1' && typeof nativeIdentity?.postMessage==='function';
    if(ids.length>1 || (ids.length===1 && !validID(ids[0]))) throw new Error('Invalid identity');
    let previous;
    try {previous=localStorage.getItem(installationKey);} catch {}
    if(ids.length===1) {
      installation=ids[0];
      // Read the native URL once, then remove the identifier from the current document address.
      try {globalThis.history?.replaceState(null,'',location.pathname || '/');} catch {}
    } else if(typeof nativeIdentity?.postMessage==='function') {
      installation=validID(previous)?previous:null;migrating=true;
    } else installation=validID(previous)?previous:crypto.randomUUID();
    if(!migrating) try {localStorage.setItem(installationKey,installation);} catch {}
  } catch {identityProblem='We couldn’t restore your app identity. Please try again.';}
  // Remember presentation only. Credentials and encrypted B entries are never persisted here.
  function remember(page) {
    try {localStorage.setItem(assignmentKey,JSON.stringify({version:1,installation,page}));} catch {}
  }
  function openingB() {
    displayedPage='B';document.body.dataset.page='B';showDebugUser();
    showGuide(false);primary.hidden=true;back.hidden=true;
  }
  function render(state) {
    showDebugUser(state);
    displayedPage=state.page;document.body.dataset.page=state.page;
    showGuide(true);
    byId('title').textContent=state.title;
    byId('eyebrow').textContent=state.page==='B'?'THE MOMENT IS HERE':'SOMETHING GOOD IS COMING';
    byId('message').textContent=state.message || (state.page==='B'?'Your event is open. Make a little time to create something together.':'Stay close. We’ll share the next moment when it’s ready for you.');
    const schedule=byId('schedule');
    schedule.hidden=!state.startsAt;
    if(state.startsAt) schedule.textContent='Starts '+new Date(state.startsAt).toLocaleString();
    back.hidden=state.page==='B';
    if(state.page==='A') action('Continue in EchoSkill',()=>native('activitycontinue'));
    else action('Refresh event',load);
  }
  function restore() {
    if(migrating || identityProblem) return;
    try {
      const saved=JSON.parse(localStorage.getItem(assignmentKey));
      if(saved?.version!==1 || saved.installation!==installation || !['A','B'].includes(saved.page)) return;
      if(saved.page==='A' && continueAtLaunch) return;
      if(saved.page==='B') openingB();
      else render({page:'A',title:'Something good is coming.'});
    } catch {}
  }
  function native(action) {
    if(!/iP(hone|ad|od)/.test(navigator.userAgent)) {byId('message').textContent='Open EchoSkill to continue in the app.';return;}
    location.href='go://'+action;
  }
  back.addEventListener('click',()=>native('h'));
  function action(label, fn) {primary.textContent=label;primary.hidden=false;primary.onclick=fn;}
  async function load() {
    if(pending) return;
    pending=true;
    if(!displayedPage) {
      primary.disabled=true;primary.hidden=true;
      byId('message').textContent='Checking the latest event details…';
    }
    clearTimeout(timer);
    try {
      if(identityProblem) throw new Error(identityProblem);
      if(migrating) {
        let saved;
        try {saved=await nativeIdentity.postMessage({installation});} catch {throw new Error('We couldn’t restore your app identity. Please try again.');}
        if(!validID(saved)) throw new Error('We couldn’t restore your app identity. Please try again.');
        const entry=new URL(location.href);
        entry.searchParams.set('deviceid',saved);
        location.replace(entry.href);return;
      }
      const language=navigator.language || 'en';
      const identity={installation,language:language.split('-')[0],locale:language,region:language.split('-')[1] || '',zone:Intl.DateTimeFormat().resolvedOptions().timeZone,model:'WebView',system:''};
      const response=await fetch('/api/start',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(identity),credentials:'same-origin',cache:'no-store',signal:AbortSignal.timeout(45000)});
      if(!response.ok) {
        const problem=await response.json();
        if(problem.error==='ENTRY_MATERIAL_MISSING') throw new Error('The event connection is not ready yet. Please try again later.');
        if(problem.error==='TOO_MANY_REQUESTS') throw new Error('Please wait a minute before trying again.');
        if(problem.error==='AUTHENTICATION_REQUIRED') throw new Error('Please sign in through your activity account to view this event.');
        if(problem.error==='ACTIVITY_NOT_CONFIGURED') throw new Error('Event details are not available yet. Please check back soon.');
        throw new Error('We couldn’t load this event. Please try again.');
      }
      const state=await response.json();
      if(!['A','B'].includes(state.page)) throw new Error('We couldn’t load this event. Please try again.');
      if(state.page==='B') {
        if(!state.entry) throw new Error('This event address is unavailable.');
        const entry=new URL(state.entry);
        if(entry.protocol!=='https:' || entry.origin!==state.trustedOrigin || entry.username || entry.password) throw new Error('This event address is unavailable.');
        remember('B');openingB();location.replace(entry.href);return;
      }
      remember(state.page);
      if(state.page==='A' && continueAtLaunch) {showDebugUser();showGuide(false);native('activitycontinue');return;}
      render(state);
      timer=setTimeout(load,60000);
    } catch(error) {
      showDebugUser();showGuide(true);back.hidden=false;
      if(displayedPage!=='A') {
        byId('eyebrow').textContent='LET’S TRY THAT AGAIN';
        byId('title').textContent='A moment, please.';
      }
      byId('message').textContent=error.name==='TimeoutError'?'The connection took too long. Please try again.':error.message;
      byId('schedule').hidden=true;
      action('Try again',load);
    } finally {pending=false;primary.disabled=false;}
  }
  document.addEventListener('visibilitychange',()=>{if(document.hidden) clearTimeout(timer);else load();});
  restore();
  load();
})();`;
const styles = `:root{color-scheme:light;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#292b25;background:#f6f2e9}*{box-sizing:border-box}body{margin:0}.loading{min-height:100svh;display:grid;place-items:center;color:#67685e}.loading svg{animation:spin 1s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}main{min-height:100svh;max-width:760px;margin:auto;padding:calc(30px + env(safe-area-inset-top)) 28px calc(25px + env(safe-area-inset-bottom));display:flex;flex-direction:column}header,footer{display:flex;align-items:center;justify-content:space-between;gap:20px}.brand{font-family:Georgia,serif;font-size:28px;letter-spacing:-1px}.dot{color:#b66b50;font-size:10px;margin-left:4px}.label{font-size:10px;letter-spacing:2px;font-weight:600;color:#686c5c}section{flex:1;padding:70px 0 60px;display:flex;flex-direction:column;align-items:flex-start;justify-content:center}.mark{font-size:72px;line-height:1;color:#b66b50;margin-bottom:44px}h1{font:normal clamp(42px,9vw,70px)/1.05 Georgia,serif;letter-spacing:-2px;margin:14px 0 24px;max-width:600px}.message{font-size:16px;line-height:1.75;max-width:420px;color:#67685e;margin:0}.schedule{font-size:13px;line-height:1.5;color:#626b55}.actions{width:100%;max-width:420px;margin-top:38px;display:grid;gap:12px}button{cursor:pointer;border:0;min-height:52px;padding:16px 20px;background:#30382b;color:#fff;border-radius:8px;font:500 15px -apple-system,BlinkMacSystemFont,sans-serif}button.secondary{background:transparent;color:#4e5447;border:1px solid #cbcdbf}button:disabled{opacity:.6}button:focus-visible{outline:3px solid #b66b50;outline-offset:3px}[hidden]{display:none!important}footer{border-top:1px solid #dcded0;padding-top:24px;font:12px/1.6 Georgia,serif;color:#77796b}.footer-mark{font-size:34px;color:#a6ad99}.debug-user{border-top:1px dashed #cbcdbf;padding:18px 0 0;margin-bottom:24px;font-size:13px;color:#67685e}.debug-label{font-size:10px;letter-spacing:1.5px;margin:0 0 12px}.debug-user label{display:block;margin-bottom:8px}.debug-user-row{display:flex;gap:10px;align-items:center}.debug-user input{min-width:0;flex:1;width:100%;padding:12px 10px;border:1px solid #cbcdbf;border-radius:6px;background:#fff8;color:#30382b;font:14px ui-monospace,monospace;-webkit-user-select:text;user-select:text}.debug-user button{min-height:44px;padding:12px 16px}.debug-user [role=status]{margin:8px 0 0;min-height:16px}body[data-page=B]{background:#ebeee3}body[data-page=B] .mark{color:#71815f}@media(min-width:700px){main{padding-left:60px;padding-right:60px}}@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto;animation:none!important}}`;

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
export async function legacyEncrypt(text,material) {
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
export async function legacyDecrypt(encoded,material) {
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
export function legacyDestination(value,allowedOrigins) {
  const raw=Array.isArray(value)?value[0]:value;
  if(typeof raw!=='string' || !raw || raw!==raw.trim() || raw.length>16384) throw new Error('Address denied');
  const web=new URL(raw);
  if(web.protocol!=='https:' || web.username || web.password || (web.port && web.port!=='443')) throw new Error('Address denied');
  const allowed=allowedOrigins.split(',').map(value=>legacyURL(value.trim()).origin);
  if(!allowed.includes(web.origin)) throw new Error('Address denied');
  return {entry:raw,trustedOrigin:web.origin};
}
export async function legacyStartup(identity,providedEnv) {
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

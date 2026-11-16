import {test} from 'node:test';
import assert from 'node:assert/strict';
import {runInNewContext} from 'node:vm';
import worker from '../worker.mjs';
const script=await (await worker.fetch(new Request('https://entry.example.test/app.js'),{})).text();
const userId='9223372036854775807';
const state={page:'A',title:'Something good is coming.',debug:{userId}};
const settle=async()=>{for(let i=0;i<10;i++) await new Promise(resolve=>setImmediate(resolve));};
function launch(response,options={}) {
 const elements=new Map(),events={},storage=new Map(),redirects=[];
 function element(id){if(!elements.has(id))elements.set(id,{hidden:false,value:'',textContent:'',listeners:{},addEventListener(name,fn){this.listeners[name]=fn;},focus(){this.focused=true;},select(){this.selected=true;},setSelectionRange(){}});return elements.get(id);}
 const context={document:{body:{dataset:{}},getElementById:element,addEventListener(name,fn){events[name]=fn;},execCommand(name){assert.equal(name,'copy');return options.legacyCopy===true;}},
  navigator:{language:'en-US',userAgent:'iPhone',clipboard:options.clipboard},location:{href:'https://entry.example.test/',replace(url){redirects.push(url);}},
  localStorage:{getItem(key){return storage.get(key)??null;},setItem(key,value){storage.set(key,value);}},URL,URLSearchParams,AbortSignal,Date,Error,Intl,crypto,
  fetch:async()=>Response.json(response),setTimeout:()=>1,clearTimeout(){}};
 runInNewContext(script,context);
 return {element,context,storage,redirects,events};
}

test('shows exact current auth ID and copies without numeric precision loss',async()=>{
 const copied=[];
 const page=launch(state,{clipboard:{async writeText(value){copied.push(value);}}});
 await settle();
 assert.equal(page.element('debug-user').hidden,false);
 assert.equal(page.element('debug-user-id').value,userId);
 await page.element('copy-user-id').listeners.click();
 assert.deepEqual(copied,[userId]);
 assert.equal(page.element('copy-user-status').textContent,'Copied');
 assert.equal([...page.storage.values()].some(value=>value.includes(userId)),false);
});

test('missing or invalid user ID keeps debug section hidden and cannot copy',async()=>{
 for(const debug of [undefined,{}, {userId:9223372036854775807},{userId:'<script>bad</script>'}]) {
  const copied=[];
  const page=launch({...state,debug},{clipboard:{async writeText(value){copied.push(value);}}});
  await settle();
  assert.equal(page.element('debug-user').hidden,true);
  assert.equal(page.element('debug-user-id').value,'');
  await page.element('copy-user-id').listeners.click();
  assert.deepEqual(copied,[]);
 }
});

test('copy fallback supports WebView and reports failure truthfully',async()=>{
 for(const allowed of [true,false]) {
  const page=launch(state,{clipboard:{async writeText(){throw new Error('denied');}},legacyCopy:allowed});
  await settle();
  await page.element('copy-user-id').listeners.click();
  assert.equal(page.element('debug-user-id').selected,true);
  assert.equal(page.element('copy-user-status').textContent,allowed?'Copied':'Press and hold the User ID to copy.');
 }
});

test('B redirect keeps temporary debug section hidden',async()=>{
 const entry='https://web.example.test/h5_web/test/?synthetic#/';
 const page=launch({page:'B',entry,trustedOrigin:'https://web.example.test',debug:{userId}});
 await settle();
 assert.deepEqual(page.redirects,[entry]);
 assert.equal(page.element('debug-user').hidden,true);
 assert.equal(page.element('debug-user-id').value,'');
});

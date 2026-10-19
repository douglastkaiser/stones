import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {before, beforeEach, after, test} from 'node:test';
import {initializeHexEmulator} from './emulator_rest.mjs';
const project='demo-stones-hex';
const address=process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088';
assert.match(address,/^(127\.0\.0\.1|localhost):\d+$/);
const root=`http://${address}/v1/projects/${project}/databases/(default)/documents`;
const pool='square-5-2-standardTak-open';
const code='UAAAAAA';
const hash=x=>createHash('sha256').update(x).digest('hex');
const humanKey=hash(code);
let env;
before(async()=>{env=await initializeHexEmulator({projectId:project,firestore:{rules:await readFile(new URL('../../firestore.rules',import.meta.url),'utf8')}});});
beforeEach(async()=>{await env.clearFirestore();});
after(async()=>env?.cleanup());
function token(uid,provider='google.com') {
 const now=Math.floor(Date.now()/1000);const b=x=>Buffer.from(JSON.stringify(x)).toString('base64url');
 return `${b({alg:'none',typ:'JWT'})}.${b({sub:uid,user_id:uid,aud:project,iss:`https://securetoken.google.com/${project}`,iat:now,exp:now+3600,auth_time:now,firebase:{identities:{},sign_in_provider:provider}})}.`;
}
function value(x) {
 if(x===null)return {nullValue:null};if(x instanceof Date)return {timestampValue:x.toISOString()};
 if(typeof x==='number')return Number.isInteger(x)?{integerValue:String(x)}:{doubleValue:x};
 if(typeof x==='boolean')return {booleanValue:x};if(typeof x==='string')return {stringValue:x};
 if(Array.isArray(x))return {arrayValue:{values:x.map(value)}};
 return {mapValue:{fields:Object.fromEntries(Object.entries(x).map(([k,v])=>[k,value(v)]))}};
}
async function request(path,method,body,uid='alice',provider) {
 const r=await fetch(`${root}${path}`,{method,headers:{'Content-Type':'application/json',Authorization:`Bearer ${uid==='admin'?'owner':token(uid,provider)}`},body:body?JSON.stringify(body):undefined});
 const raw=await r.text();return {ok:r.ok,status:r.status,raw};
}
const seed=async(path,data)=>{const r=await request(`/${path}`,'PATCH',{fields:value(data).mapValue.fields},'admin');assert(r.ok,r.raw);};
const put=(path,data,uid,provider)=>request(`/${path}`,'PATCH',{fields:value(data).mapValue.fields},uid,provider);
function write(path,data,times=[]) {
 return {update:{name:`projects/${project}/databases/(default)/documents/${path}`,fields:value(data).mapValue.fields},
 ...(times.length?{updateTransforms:times.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}:{})};
}
async function commit(writes,uid='alice') {return request(':commit','POST',{writes},uid);}
const reject=async promise=>{const r=await promise;assert.equal(r.status,403,r.raw);};
const accept=async promise=>{const r=await promise;assert(r.ok,r.raw);return r;};
const easy='ai_shared-search-v1_easy';
const expert='ai_shared-search-v1_expert';
const empty={rating:1200,gamesPlayed:0,wins:0,losses:0,draws:0,opponents:0};
function scenario({participants=['alice','bob',expert],ranks=[1,2,3],local=false,flats,reason='road',prior={},source='local-test',shape='square',size=5,clock=0}={}) {
 const n=participants.length;
 const actor=participants.find(id=>!id.startsWith('ai_'));
 const ids=['ivory','charcoal','copper','jade'].slice(0,n);
 const config={version:1,ratingVersion:2,shape,size,profile:shape==='square'&&n===2?'standardTak':'sharedRoads',starter:'ivory',
  ...(clock?{clockSeconds:clock}:{}),seats:ids.map((id,i)=>({id,control:participants[i].startsWith('ai_')?'ai':i===0||local?'localHuman':'onlineHuman',level:participants[i].startsWith('ai_')?participants[i].split('_').at(-1):'easy'}))};
 const ladder=`${shape}-${size}-${n}-${config.profile}-${clock===0?'open':clock<600?'fast':'long'}`;
 const names=participants.map(id=>id.startsWith('ai_')?`${id.split('_').at(-1)[0].toUpperCase()}${id.split('_').at(-1).slice(1)} AI`:id);
 const before=Object.fromEntries([...new Set(participants)].map(id=>[id,prior[id]??{...empty}]));
 const values=Object.fromEntries(Object.entries(before).map(([id,b])=>[id,b.rating]));
 const after={};
 for(const id of new Set(participants)) {
  const indices=participants.flatMap((p,i)=>p===id?[i]:[]);
  let delta=0;
  for(const i of indices)for(let j=0;j<n;j++)if(j!==i)delta+=((ranks[i]===ranks[j]?.5:ranks[i]<ranks[j]?1:0)-1/(1+10**((values[participants[j]]-values[id])/400)))/(n-1)/indices.length;
  after[id]=Math.max(100,Math.round(values[id]+(before[id].gamesPlayed<30?40:20)*delta));
 }
 const winner=ranks.filter(r=>r===1).length===1?ranks.indexOf(1):-1;
 const counts=flats??ranks.map((r,i)=>r===1?1:n+2-r);
 const receipt={kind:'placements',version:2,pool:ladder,participants,config,ranks,winner,reason,flats:counts,names,ply:n,actor,
  source:local?source:code,room:local?null:code,moves:local?ids.map(id=>({seat:id,x:0,y:0,type:'flat',direction:null,drops:[]})):[],before:values,after};
 const vote=name=>({version:2,ply:n,winner,reason,ranks,flats:counts,name});
 const r={version:1,code,ratingKey:humanKey,host:'alice',config,owners:Object.fromEntries(ids.map((id,i)=>[id,participants[i].startsWith('ai_')?null:participants[i]])),
  styles:Object.fromEntries(ids.map(id=>[id,'standard'])),boardTheme:'classicWood',moves:ids.map(id=>({seat:id,x:0,y:0,type:'flat',direction:null,drops:[]})),resigned:null,timedOut:null,clock:null,aiRunner:null,aiLeaseAt:null};
 const resultId=local?hash(`${actor}_${source}`):humanKey;
 const writes=[write(`ratingResults/${resultId}`,receipt,['at'])];
 for(const id of new Set(participants)) {
  const indices=participants.flatMap((p,i)=>p===id?[i]:[]),b=before[id];
  const score=i=>ranks[i]===1?(winner===-1?.5:1):0;
  const scores=indices.map(score),games=b.gamesPlayed+indices.length;
  const ai=id.startsWith('ai_'),level=ai?id.split('_').at(-1):null;
  writes.push(write(`ratingPools/${ladder}/players/${id}`,{pool:ladder,displayName:names[indices[0]],rating:after[id],gamesPlayed:games,
   wins:b.wins+scores.filter(s=>s===1).length,losses:b.losses+scores.filter(s=>s===0).length,draws:b.draws+scores.filter(s=>s===.5).length,
   isAi:ai,established:games>=10,opponents:b.opponents,lastResult:resultId,...(ai?{engineVersion:'shared-search-v1',aiDifficulty:level}:{})},['lastUpdated']));
  writes.push(write(`ratingPools/${ladder}/players/${id}/history/${games}`,{rating:after[id],before:values[id],delta:after[id]-values[id],
   score:scores.reduce((a,b)=>a+b)/scores.length,opponentName:`${n}-player game`,placements:ranks,seat:indices[0],appearances:indices.length},['timestamp']));
 }
 writes.push(local?write(`aiResultKeys/${actor}_${source}`,{result:resultId}):{update:{name:`projects/${project}/databases/(default)/documents/matches/${code}`,fields:value({ratingReceipt:resultId}).mapValue.fields},updateMask:{fieldPaths:['ratingReceipt']}});
 return {r,receipt,writes,vote,participants,local,prior,before,ladder,resultId};
}
async function prepare(s,{skip=[]}={}) {
 if(!s.local) {
  await seed(`matches/${code}`,s.r);
  for(const id of new Set(s.participants))if(!id.startsWith('ai_')&&!skip.includes(id))await accept(put(`matches/${code}/ratingVotes/${id}`,s.vote(id),id));
 }
 for(const [id,data]of Object.entries(s.prior))await seed(`ratingPools/${s.ladder}/players/${id}`,data);
 return s;
}
for(const participants of [['alice','bob'],['alice','bob','carol'],['alice','bob','carol','dan'],['alice',expert],['alice','bob',expert],['alice',easy,expert],['alice','bob',easy,expert]]) {
 test(`placement Elo settles every seat atomically: ${participants.join(',')}`,async()=>{
  const s=await prepare(scenario({participants,ranks:participants.map((_,i)=>i+1),local:!participants.includes('bob')}));
  await accept(commit(s.writes));
  await reject(commit(s.writes));
 });
}
test('last human vote can settle mixed seats in the same transaction',async()=>{
 const s=await prepare(scenario(),{skip:['alice']});
 await reject(commit(s.writes));
 const writes=[...s.writes,write(`matches/${code}/ratingVotes/alice`,s.vote('alice'))];
 await accept(commit(writes));
});
test('all humans must agree on placements, even with the same winner',async()=>{
 const s=await prepare(scenario());
 await accept(put(`matches/${code}/ratingVotes/bob`,{...s.vote('bob'),ranks:[1,3,2]},'bob'));
 await reject(commit(s.writes));
});
test('same global AI in multiple seats aggregates outcomes once',async()=>{
 const s=await prepare(scenario({participants:['alice',easy,easy,'bob'],ranks:[1,2,3,4]}));
 await accept(commit(s.writes));
 const bot=await accept(request(`/ratingPools/${s.ladder}/players/${easy}`,'GET'));
 const data=JSON.parse(bot.raw).fields;
 assert.equal(data.gamesPlayed.integerValue,'2');
 assert.equal(data.rating.integerValue,'1200');
});
test('flat leaders and lower tied placements are supported',async()=>{
 const s=await prepare(scenario({participants:['alice','bob',expert,easy],ranks:[1,1,3,3],flats:[5,5,2,2],reason:'flats'}));
 await accept(commit(s.writes));
});
test('unequal established human and AI ratings follow the expected curve',async()=>{
 const s=await prepare(scenario({prior:{alice:{...empty,rating:1500,gamesPlayed:30,wins:30},bob:{...empty,rating:1700,gamesPlayed:12,wins:12},[expert]:{...empty,rating:1800,gamesPlayed:40,wins:40}},ranks:[2,1,3]}));
 await accept(commit(s.writes));
});
test('forged totals, delta, history, pool, ranks and partial settlement are rejected',async()=>{
 const s=await prepare(scenario()),good=s.writes;
 for(const edit of [
  w=>{w[1].update.fields.rating.integerValue='9999';},
  w=>{w[1].update.fields.wins.integerValue='9999';},
  w=>{w[2].update.fields.delta.integerValue='9999';},
  w=>{w[0].update.fields.before.mapValue.fields.alice.integerValue='1000';},
  w=>{w[0].update.fields.after.mapValue.fields.alice.integerValue='9999';},
  w=>{w[0].update.fields.pool.stringValue='square-5-2-standardTak-open';},
  w=>{w[0].update.fields.ranks.arrayValue.values[2].integerValue='2';},
  w=>{w.splice(3,2);},w=>{w.splice(2,1);},
 ]) {const writes=structuredClone(good);edit(writes);await reject(commit(writes));}
 await reject(commit(good,'stranger'));await accept(commit(good));
});
test('local receipts cannot credit an unrelated human or award unowned hotseat identities',async()=>{
 const s=scenario({participants:['alice',expert],ranks:[1,2],local:true});
 await reject(commit(s.writes,'stranger'));
 const shared=scenario({participants:['alice','bob',expert],ranks:[1,2,3],local:true});
 await reject(commit(shared.writes));
 await accept(commit(s.writes));
 await reject(request(`/ratingResults/${s.resultId}`,'GET',undefined,'stranger'));
});
test('persisted delta stays unchanged after a later AI game',async()=>{
 const first=await prepare(scenario({participants:['alice',expert],ranks:[1,2],local:true,source:'local-first'}));
 await accept(commit(first.writes));
 const before=JSON.parse((await accept(request(`/ratingResults/${first.resultId}`,'GET'))).raw);
 const current={};
 for(const id of first.participants) {
  const fields=JSON.parse((await accept(request(`/ratingPools/${first.ladder}/players/${id}`,'GET'))).raw).fields;
  current[id]=Object.fromEntries(['rating','gamesPlayed','wins','losses','draws','opponents'].map(key=>[key,Number(fields[key].integerValue)]));
 }
 const second=await prepare(scenario({participants:['alice',expert],ranks:[2,1],local:true,source:'local-second',prior:current}));
 await accept(commit(second.writes));
 const after=JSON.parse((await accept(request(`/ratingResults/${first.resultId}`,'GET'))).raw);
 assert.deepEqual(after.fields,before.fields);
});
test('repeated AI seats can tie for first or occupy different drawn placements',async()=>{
 for(const ranks of [[1,1,3],[1,1,1],[3,1,1]]) {
  await env.clearFirestore();
  const s=await prepare(scenario({participants:['alice',easy,easy],ranks,local:true,reason:'flats',flats:ranks.map(r=>r===1?4:1)}));
  await accept(commit(s.writes));
 }
});
test('concurrent accounts cannot overwrite a global AI rating with stale totals',async()=>{
 const first=scenario({participants:['alice',expert],ranks:[1,2],local:true,source:'local-race-a'});
 const second=scenario({participants:['bob',expert],ranks:[2,1],local:true,source:'local-race-b'});
 const results=await Promise.all([commit(first.writes,'alice'),commit(second.writes,'bob')]);
 assert.equal(results.filter(r=>r.ok).length,1);
 const stale=results[0].ok?second:first;
 const actor=stale.receipt.actor;
 const prior={};
 for(const id of stale.participants) {
  const result=await request(`/ratingPools/${stale.ladder}/players/${id}`,'GET',undefined,actor);
  if(result.status===404)continue;
  assert(result.ok,result.raw);
  const fields=JSON.parse(result.raw).fields;
  prior[id]=Object.fromEntries(['rating','gamesPlayed','wins','losses','draws','opponents'].map(key=>[key,Number(fields[key].integerValue)]));
 }
 const retry=scenario({participants:stale.participants,ranks:stale.receipt.ranks,local:true,source:stale.receipt.source,prior});
 await accept(commit(retry.writes,actor));
 const bot=JSON.parse((await accept(request(`/ratingPools/${stale.ladder}/players/${expert}`,'GET',undefined,actor))).raw).fields;
 assert.equal(bot.gamesPlayed.integerValue,'2');
});
test('different AI identities cannot be disguised as repeated instances',async()=>{
 const s=scenario({participants:['alice',easy,easy],ranks:[1,2,3],local:true});
 for(const change of [
  w=>{w[0].update.fields.config.mapValue.fields.seats.arrayValue.values[2].mapValue.fields.level.stringValue='expert';},
  w=>{w[0].update.fields.names.arrayValue.values[2].stringValue='Expert AI';},
 ]) {const writes=structuredClone(s.writes);change(writes);await reject(commit(writes));}
 await accept(commit(s.writes));
});
for(const [shape,size] of [['square',3],['square',8],['hex',2],['hex',4]]) {
 test(`versioned AI settlement respects ${shape} size ${size} ladder`,async()=>{
  const s=scenario({participants:['alice',expert],ranks:[1,2],local:true,shape,size});
  await accept(commit(s.writes));
 });
}
test('three instances of one AI preserve each seat outcome and bounded Elo',async()=>{
 for(const ranks of [[1,2,3,4],[2,1,3,4],[1,1,1,4],[1,1,1,1]]) {
  await env.clearFirestore();
  const s=scenario({participants:['alice',easy,easy,easy],ranks,local:true,
   reason:ranks.filter(r=>r===1).length>1?'flats':'road',flats:ranks.map(r=>r===1?4:5-r)});
  await accept(commit(s.writes));
 }
});

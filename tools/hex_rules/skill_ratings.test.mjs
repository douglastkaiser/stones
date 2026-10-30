import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {before, beforeEach, after, test} from 'node:test';
import {initializeHexEmulator} from './emulator_rest.mjs';
const project='demo-stones-hex';
const address=process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088';
assert.match(address,/^(127\.0\.0\.1|localhost):\d+$/);
const root=`http://${address}/v1/projects/${project}/databases/(default)/documents`;
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
const empty={mean:1200,deviation:350,gamesPlayed:0,wins:0,losses:0,draws:0};
function source({participants=['alice','bob',expert],winner=0,local=false,sourceId='local-one',shape='square',size=5,clock=0,reason='road'}={}) {
 const n=participants.length,ids=['ivory','charcoal','copper','jade'].slice(0,n);
 const config={version:1,ratingVersion:3,shape,size,profile:shape==='square'&&n===2?'standardTak':'sharedRoads',starter:'ivory',
  ...(clock?{clockSeconds:clock}:{}),seats:ids.map((id,i)=>({id,control:participants[i].startsWith('ai_')?'ai':i===0||local?'localHuman':'onlineHuman',level:participants[i].startsWith('ai_')?participants[i].split('_').at(-1):'easy'}))};
 const pool=`${shape}-${size}-${n}-${config.profile}-${clock===0?'open':clock<600?'fast':'long'}`;
 const names=participants.map(id=>id.startsWith('ai_')?`${id.split('_').at(-1)[0].toUpperCase()}${id.split('_').at(-1).slice(1)} AI`:id);
 const key=hash(local?sourceId:code),ply=n,actor=participants.find(id=>!id.startsWith('ai_'))??'alice';
 const moves=ids.map(seat=>({seat,x:0,y:0,type:'flat',direction:null,drops:[]}));
 const receipt={kind:'skill',version:3,pool,participants,config,winner,reason,names,ply,actor,source:local?sourceId:code,room:local?null:code,moves:local?moves:[]};
 const vote=name=>({version:3,ply,winner,reason,name});
 const room={version:1,code,ratingKey:key,host:actor,config,owners:Object.fromEntries(ids.map((id,i)=>[id,participants[i].startsWith('ai_')?null:participants[i]])),styles:Object.fromEntries(ids.map(id=>[id,'standard'])),boardTheme:'classicWood',moves,resigned:null,timedOut:null,clock:null,aiRunner:null,aiLeaseAt:null};
 const writes=[write(`ratingResults/${key}`,receipt,['at']),local?write(`aiResultKeys/${actor}_${sourceId}`,{result:key}):
  {update:{name:`projects/${project}/databases/(default)/documents/matches/${code}`,fields:value({ratingReceipt:key}).mapValue.fields},updateMask:{fieldPaths:['ratingReceipt']}}];
 return {key,receipt,vote,room,writes,participants,pool,local,actor};
}
async function prepare(s,{skip=[]}={}) {
 if(!s.local){await seed(`matches/${code}`,s.room);
  for(const id of new Set(s.participants))if(!id.startsWith('ai_')&&!skip.includes(id))await accept(put(`matches/${code}/ratingVotes/${id}`,s.vote(id),id));}
 return s;
}
function settle(s,pool='overall',prior={}) {
 const {participants}=s,n=participants.length,winner=s.receipt.winner;
 const before=Object.fromEntries([...new Set(participants)].map(id=>[id,prior[id]??{...empty}]));
 const after={};
 for(const id of new Set(participants)) {
  const b=before[id],q=Math.log(10)/400,indices=participants.flatMap((p,i)=>p===id?[i]:[]);
  let gradient=0,info=0;
  for(const i of indices)for(let j=0;j<n;j++){
   if(participants[j]===id || winner!==-1 && winner!==i && winner!==j)continue;
   const other=before[participants[j]],g=1/Math.sqrt(1+3*q*q*other.deviation**2/Math.PI**2);
   const expected=1/(1+10**(-g*(b.mean-other.mean)/400)),score=winner===-1?.5:winner===i?1:0,weight=1/((n-1)*indices.length);
   gradient+=weight*g*(score-expected);info+=weight*g*g*expected*(1-expected);
  }
  const variance=1/(1/b.deviation**2+q*q*info);
  after[id]={mean:b.mean+q*variance*gradient,deviation:Math.max(50,Math.sqrt(variance))};
 }
 const estimate=b=>({mean:b.mean,deviation:b.deviation});
 const receipt={source:s.key,pool,before:Object.fromEntries(Object.entries(before).map(([id,b])=>[id,estimate(b)])),after};
 const writes=[write(`skillSettlements/${s.key}/scopes/${pool}`,receipt,['at'])],records={};
 for(const id of new Set(participants)) {
  const index=participants.indexOf(id),b=before[id],next=after[id],score=winner===-1?.5:participants[winner]===id?1:0;
  const rating=Math.round(next.mean),games=b.gamesPlayed+1,ai=id.startsWith('ai_');
  records[id]={pool,displayName:s.receipt.names[index],...next,rating,gamesPlayed:games,wins:b.wins+(score===1?1:0),losses:b.losses+(score===0?1:0),draws:b.draws+(score===.5?1:0),isAi:ai,established:games>=10&&next.deviation<=150,lastResult:s.key,...(ai?{engineVersion:s.receipt.config.aiEngine??'shared-search-v1',aiDifficulty:s.receipt.config.seats[index].level}:{})};
  writes.push(write(`skillPools/${pool}/players/${id}`,records[id],['lastUpdated']));
  writes.push(write(`skillPools/${pool}/players/${id}/history/${games}`,{...next,rating,before:Math.round(b.mean),delta:rating-Math.round(b.mean),score,opponentName:`${n}-player game`,aiEngine:s.receipt.config.aiEngine??'shared-search-v1',seat:index,appearances:participants.filter(p=>p===id).length},['timestamp']));
 }
 return {writes,records,receipt};
}
for(const participants of [['alice','bob'],['alice','bob','carol'],['alice','bob','carol','dan'],['alice',expert],['alice','bob',expert],['alice',easy,expert],['alice',easy,easy,easy],['alice',easy,easy,'bob'],[easy,expert],[easy,expert,easy],[easy,expert,easy,expert],[easy,easy]]) {
 test(`v3 confirms and rates both scopes: ${participants}`,async()=>{
  const s=await prepare(source({participants,local:!participants.includes('bob')}));
  await accept(commit(s.writes));
  for(const pool of ['overall',s.pool]) {const result=settle(s,pool);await accept(commit(result.writes));await reject(commit(result.writes));}
  await reject(commit(s.writes));
 });
}
test('AI-only reporters can recover both scopes without rating themselves or exposing receipts',async()=>{
 const s=source({participants:[easy,expert],local:true});
 await reject(commit(s.writes,'stranger'));
 await reject(request(':commit','POST',{writes:s.writes},'alice','anonymous'));
 await accept(commit(s.writes));
 const overall=settle(s);
 assert.deepEqual(Object.keys(overall.records).sort(),[easy,expert].sort());
 assert(overall.records[easy].rating>1200);
 assert(overall.records[expert].rating<1200);
 await reject(commit(overall.writes,'stranger'));
 await reject(commit(overall.writes.slice(0,-1)));
 const forged=structuredClone(overall.writes);
 forged[1].update.fields.rating.integerValue='9999';
 await reject(commit(forged));
 await accept(commit(overall.writes));
 await accept(request(`/skillSettlements/${s.key}/scopes/overall`,'GET'));
 await reject(request(`/skillSettlements/${s.key}/scopes/overall`,'GET',undefined,'stranger'));
 await reject(request(`/ratingResults/${s.key}`,'GET',undefined,'stranger'));
 await accept(commit(settle(s,s.pool).writes));
 await reject(commit(overall.writes));
 await reject(commit(s.writes));
});
test('AI-only draws use normal math and a mirror match creates no skill evidence',async()=>{
 for(const [i,participants,winner] of [[0,[easy,expert],-1],[1,[easy,easy],0]]) {
  await env.clearFirestore();
  const s=source({participants,winner,local:true,sourceId:`local-ai-${i}`});
  await accept(commit(s.writes));
  const result=settle(s);
  if(i===0)assert.equal(result.records[easy].draws,1);
  else {
   assert.equal(result.records[easy].mean,1200);
   assert.equal(result.records[easy].deviation,350);
   assert.equal(result.records[easy].gamesPlayed,1);
  }
  await accept(commit(result.writes));
 }
});
for(const shape of ['square','hex'])for(const clock of [0,300,600]) {
 test(`v3 pool derives ${shape}, clock ${clock}`,async()=>{
  const s=await prepare(source({shape,size:shape==='square'?3:2,clock}));
  await accept(commit(s.writes));await accept(commit(settle(s,s.pool).writes));
  await reject(commit(settle(s,'hex-4-4-sharedRoads-long').writes));
 });
}
test('v3 permits the final human vote to freeze the source atomically',async()=>{
 const s=await prepare(source(),{skip:['alice']});
 await reject(commit(s.writes));await accept(commit([...s.writes,write(`matches/${code}/ratingVotes/alice`,s.vote('alice'))]));
 await accept(commit(settle(s).writes));
});
test('disagreeing outcomes, forged identities, guests and local hotseat cannot confirm',async()=>{
 const s=await prepare(source());
 await accept(put(`matches/${code}/ratingVotes/bob`,{...s.vote('bob'),winner:1},'bob'));
 await reject(commit(s.writes));
 await accept(put(`matches/${code}/ratingVotes/bob`,s.vote('bob'),'bob'));
 await reject(commit(s.writes,'stranger'));
 await reject(request(':commit','POST',{writes:s.writes},'alice','anonymous'));
 const forged=structuredClone(s.writes);forged[0].update.fields.names.arrayValue.values[2].stringValue='Fictional bot';await reject(commit(forged));
 const shared=source({participants:['alice','bob',expert],local:true,sourceId:'local-hotseat'});await reject(commit(shared.writes));
 await accept(commit(s.writes));
});
test('forged skill, uncertainty, counters, histories, receipts and partial updates fail',async()=>{
 const s=await prepare(source());await accept(commit(s.writes));const good=settle(s).writes;
 for(const edit of [
  w=>{w[1].update.fields.mean.doubleValue+=100;},
  w=>{w[1].update.fields.deviation.doubleValue=1;},
  w=>{w[1].update.fields.rating.integerValue='9999';},
  w=>{w[1].update.fields.gamesPlayed.integerValue='100';},
  w=>{w[1].update.fields.wins.integerValue='100';},
  w=>{w[1].update.fields.established.booleanValue=true;},
  w=>{w[2].update.fields.delta.integerValue='9999';},
  w=>{w[2].update.fields.deviation.doubleValue=50;},
  w=>{w[0].update.fields.before.mapValue.fields.alice.mapValue.fields.mean.integerValue='1000';},
  w=>{w[0].update.fields.after.mapValue.fields.alice.mapValue.fields.mean.doubleValue=9000;},
  w=>{w[0].update.fields.pool.stringValue=s.pool;},
  w=>{w.splice(3,2);},w=>{w.splice(2,1);},w=>{w.splice(0,1);},
 ]){const writes=structuredClone(good);edit(writes);await reject(commit(writes));}
 await reject(commit(good,'stranger'));await accept(commit(good));
});
test('draws update all seats; a repeated AI winner has no self comparisons',async()=>{
 for(const [i,participants,winner] of [[0,['alice',easy,expert],-1],[1,['alice',easy,easy,expert],1]]){
  await env.clearFirestore();
  const s=source({participants,winner,local:true,sourceId:`local-${i}`});await accept(commit(s.writes));
  await accept(commit(settle(s).writes));
 }
});
test('source evidence and scope receipts stay private while ratings are public',async()=>{
 const s=source({participants:['alice',expert],local:true});await accept(commit(s.writes));await accept(commit(settle(s).writes));
 await reject(request(`/ratingResults/${s.key}`,'GET',undefined,'stranger'));
 await reject(request(`/skillSettlements/${s.key}/scopes/overall`,'GET',undefined,'stranger'));
 await accept(request(`/skillSettlements/${s.key}/scopes/overall`,'GET'));
 await accept(request('/skillPools/overall/players/alice','GET',undefined,'stranger'));
 await reject(put(`ratingResults/${s.key}`,s.receipt,'alice'));
});
test('concurrent games retry against current shared AI skill; either scope can recover later',async()=>{
 const first=source({participants:['alice',expert],local:true,sourceId:'local-first'});
 const second=source({participants:['alice',expert],local:true,sourceId:'local-second',winner:1});
 await accept(commit(first.writes));await accept(commit(second.writes));
 const a=settle(first),stale=settle(second);
 await accept(commit(a.writes));await reject(commit(stale.writes));
 await accept(commit(settle(second,'overall',a.records).writes));
 // A delayed format settlement is independent of the already advanced overall.
 await accept(commit(settle(first,first.pool).writes));
 await reject(commit(a.writes));
 const saved=await accept(request(`/skillSettlements/${first.key}/scopes/overall`,'GET'));
 assert.equal(JSON.parse(saved.raw).fields.after.mapValue.fields.alice.mapValue.fields.mean.doubleValue,a.records.alice.mean);
});
test('established and highly uncertain priors follow the same math without fabricated confidence',async()=>{
 const s=await prepare(source({participants:['alice','bob','carol','dan'],winner:2}));await accept(commit(s.writes));
 const prior={alice:{...empty,mean:1700,deviation:60,gamesPlayed:50,wins:50},bob:{...empty,mean:1200,deviation:340},carol:{...empty,mean:1450,deviation:100,gamesPlayed:12,wins:12},dan:{...empty,mean:1900,deviation:50,gamesPlayed:30,wins:30}};
 for(const [id,data] of Object.entries(prior))await seed(`skillPools/overall/players/${id}`,data);
 await accept(commit(settle(s,'overall',prior).writes));
});
for(const winner of [-1,1,2,3]) {
 test(`four-seat v3 outcome ${winner} validates all posteriors`,async()=>{
  const s=await prepare(source({participants:['alice','bob',easy,expert],winner}));
  await accept(commit(s.writes));await accept(commit(settle(s).writes));
 });
}
test('local source cannot smuggle Court, invalid settings, unknown AI, or a legacy rating version',async()=>{
 const s=source({participants:['alice',expert],local:true});
 for(const mutate of [
  config=>{config.court={booleanValue:true};},
  config=>{config.size.integerValue='99';},
  config=>{config.ratingVersion.integerValue='2';},
  config=>{config.seats.arrayValue.values[1].mapValue.fields.level.stringValue='unrated';},
  config=>{config.clockSeconds={integerValue:'-1'};},
  config=>{config.seats.arrayValue.values[1].mapValue.fields.id.stringValue='ivory';},
 ]){
  const bad=structuredClone(s.writes);mutate(bad[0].update.fields.config.mapValue.fields);await reject(commit(bad));
 }
 await accept(commit(s.writes));
});

for(const engine of ['shared-search-v2','shared-search-v3']) test(`${engine} uses its permitted rating identity and records its game engine`,async()=>{
 const participants=['alice','ai_shared-search-v2_expert'];
 const s=source({participants,local:true});s.receipt.config.aiEngine=engine;
 s.writes[0]=write(`ratingResults/${s.key}`,s.receipt,['at']);
 await accept(commit(s.writes));
 const result=settle(s);result.records[participants[1]].engineVersion=engine;
 const profileWrite=result.writes.find(w=>w.update.name.endsWith(`/players/${participants[1]}`));
 profileWrite.update.fields=value(result.records[participants[1]]).mapValue.fields;
 await accept(commit(result.writes));
 await env.clearFirestore();
 const forged=source({participants,local:true});await reject(commit(forged.writes));
});


test('human rank aggregation excludes AI and provisional players and shares ties',async()=>{
 for(const [id,rating,isAi,established] of [
  ['leader',1800,false,true],['tied',1500,false,true],
  ['expert',2000,true,true],['new',2100,false,false],
 ]) await seed(`skillPools/overall/players/${id}`,{rating,isAi,established});
 const result=await request('/skillPools/overall:runAggregationQuery','POST',{
  structuredAggregationQuery:{
   structuredQuery:{from:[{collectionId:'players'}],where:{compositeFilter:{op:'AND',filters:[
    {fieldFilter:{field:{fieldPath:'isAi'},op:'EQUAL',value:{booleanValue:false}}},
    {fieldFilter:{field:{fieldPath:'established'},op:'EQUAL',value:{booleanValue:true}}},
    {fieldFilter:{field:{fieldPath:'rating'},op:'GREATER_THAN',value:{integerValue:'1500'}}},
   ]}}},aggregations:[{alias:'higherHumans',count:{}}]
  }
 },'alice');
 assert(result.ok,result.raw);
 assert.equal(JSON.parse(result.raw)[0].result.aggregateFields.higherHumans.integerValue,'1');
});


test('v3 continues established v2 priors in both ladders with engine-stamped history',async()=>{
 const bot='ai_shared-search-v2_expert',participants=['alice',bot];
 const s=source({participants,local:true});s.receipt.config.aiEngine='shared-search-v3';
 s.writes[0]=write(`ratingResults/${s.key}`,s.receipt,['at']);await accept(commit(s.writes));
 for(const pool of ['overall',s.pool]) {
  const prior={alice:{...empty},[bot]:{...empty,mean:1600,deviation:80,gamesPlayed:20,wins:10,losses:10}};
  await seed(`skillPools/${pool}/players/${bot}`,{...prior[bot],rating:1600,isAi:true,engineVersion:'shared-search-v2',aiDifficulty:'expert'});
  const result=settle(s,pool,prior);
  assert.equal(result.receipt.before[bot].mean,1600);
  assert.equal(result.records[bot].gamesPlayed,21);
  const suffix=`/players/${bot}/history/21`;
  const history=result.writes.find(w=>w.update.name.endsWith(suffix));
  assert.equal(history.update.fields.aiEngine.stringValue,'shared-search-v3');
  const wrong=structuredClone(result.writes);
  wrong.find(w=>w.update.name.endsWith(suffix)).update.fields.aiEngine.stringValue='shared-search-v2';
  await reject(commit(wrong));
  const missing=structuredClone(result.writes);
  delete missing.find(w=>w.update.name.endsWith(suffix)).update.fields.aiEngine;
  await reject(commit(missing));
  await accept(commit(result.writes));
 }
});

test('saved v2 games and older clients may omit history engine metadata',async()=>{
 const s=source({participants:['alice','ai_shared-search-v2_expert'],local:true});
 s.receipt.config.aiEngine='shared-search-v2';s.writes[0]=write(`ratingResults/${s.key}`,s.receipt,['at']);
 await accept(commit(s.writes));
 const result=settle(s);
 for(const w of result.writes) if(w.update.name.includes('/history/')) delete w.update.fields.aiEngine;
 await accept(commit(result.writes));
});

test('v3 cannot create a reset profile with a v3-specific rating ID',async()=>{
 const s=source({participants:['alice','ai_shared-search-v3_expert'],local:true});
 s.receipt.config.aiEngine='shared-search-v3';s.writes[0]=write(`ratingResults/${s.key}`,s.receipt,['at']);
 await reject(commit(s.writes));
});

test('online Court cannot record a result or settle either skill scope', async()=>{
 const s=await prepare(source({participants:['alice','bob']}));
 s.room.config.court=true;
 s.room.revision=2;
 await seed(`matches/${code}`,s.room);
 await reject(put(`matches/${code}/ratingVotes/alice`,s.vote('alice'),'alice'));
 const forged=structuredClone(s.writes);
 forged[0].update.fields.config.mapValue.fields.court={booleanValue:true};
 await reject(commit(forged));
 await reject(commit(s.writes));
 await reject(commit(settle(s).writes));
 await reject(commit(settle(s,s.pool).writes));
});

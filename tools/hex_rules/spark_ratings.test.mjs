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
function room(n=2) {
 const ids=['ivory','charcoal','copper','jade'].slice(0,n);const users=['alice','bob','carol','dan'].slice(0,n);
 return {version:1,code,host:'alice',config:{version:1,shape:'square',size:5,profile:n===2?'standardTak':'sharedRoads',starter:'ivory',seats:ids.map((id,i)=>({id,control:i===0?'localHuman':'onlineHuman',level:'easy'}))},
 owners:Object.fromEntries(ids.map((id,i)=>[id,users[i]])),styles:Object.fromEntries(ids.map(id=>[id,'standard'])),boardTheme:'classicWood',
 moves:ids.map(id=>({seat:id,x:0,y:0,type:'flat',direction:null,drops:[]})),resigned:null,timedOut:null,clock:null,aiRunner:null,aiLeaseAt:null};
}
async function setup(n=2,winner=0) {
 const r=room(n);await seed(`matches/${code}`,r);const users=Object.values(r.owners);
 for(const uid of users)await accept(put(`matches/${code}/ratingVotes/${uid}`,{ply:n,winner,name:uid},uid));
 return {r,users,pool:n===2?pool:`square-5-${n}-sharedRoads-open`};
}
function resultWrites({users,pool:ladder},winner=0,prior={}) {
 const n=users.length;const rating=i=>prior[users[i]]?.rating??1200;
 const before=i=>prior[users[i]]??{rating:1200,gamesPlayed:0,wins:0,losses:0,draws:0,opponents:0};
 const writes=[write(`ratingResults/${humanKey}`,{kind:'human',room:code,pool:ladder,participants:users,winner,ply:n},['at'])];
 for(let i=0;i<n;i++) {
  const b=before(i);let change=0;
  for(let j=0;j<n;j++)if(i!==j) {const s=winner===-1||(winner!==i&&winner!==j)?.5:winner===i?1:0;change+=s-1/(1+10**((rating(j)-rating(i))/400));}
  const next=Math.max(100,Math.round(b.rating+(b.gamesPlayed<30?40:20)*change/(n-1)));
  const score=winner===-1?.5:winner===i?1:0;
  writes.push(write(`ratingPools/${ladder}/players/${users[i]}`,{pool:ladder,displayName:users[i],rating:next,gamesPlayed:b.gamesPlayed+1,wins:b.wins+(score===1?1:0),losses:b.losses+(score===0?1:0),draws:b.draws+(score===.5?1:0),isAi:false,established:b.gamesPlayed+1>=10,opponents:0,lastResult:humanKey},['lastUpdated']));
  writes.push(write(`ratingPools/${ladder}/players/${users[i]}/history/${b.gamesPlayed+1}`,{rating:next,score,opponentName:`${n}-player game`},['timestamp']));
 }
 writes.push({update:{name:`projects/${project}/databases/(default)/documents/matches/${code}`,fields:value({ratingReceipt:humanKey}).mapValue.fields},updateMask:{fieldPaths:['ratingReceipt']}});
 return writes;
}
test('two independently signed players can settle once with exact Elo and history',async()=>{
 const s=await setup();const writes=resultWrites(s);await accept(commit(writes));await reject(commit(writes));
 await reject(put(`matches/${code}/ratingVotes/bob`,{ply:2,winner:1,name:'bob'},'bob'));
});
for(const n of [3,4])test(`${n}-player normalized Elo settles atomically within rule budgets`,async()=>{await accept(commit(resultWrites(await setup(n))));});
test('draws and unequal established ratings use the precise expected-score curve',async()=>{
 const s=await setup(2,-1);const prior={alice:{rating:1533,gamesPlayed:32,wins:20,losses:10,draws:2,opponents:0},bob:{rating:923,gamesPlayed:9,wins:2,losses:5,draws:2,opponents:0}};
 for(const uid of s.users)await seed(`ratingPools/${pool}/players/${uid}`,prior[uid]);
 await accept(commit(resultWrites(s,-1,prior)));
});
test('unilateral, mismatched, stale and anonymous votes cannot award ratings',async()=>{
 const r=room();await seed(`matches/${code}`,r);
 await reject(put(`matches/${code}/ratingVotes/alice`,{ply:2,winner:0,name:'alice'},'alice','anonymous'));
 await reject(put(`matches/${code}/ratingVotes/bob`,{ply:2,winner:0,name:'bob'},'alice'));
 await reject(put(`matches/${code}/ratingVotes/stranger`,{ply:2,winner:0,name:'x'},'stranger'));
 await accept(put(`matches/${code}/ratingVotes/alice`,{ply:2,winner:0,name:'alice'},'alice'));
 const s={users:['alice','bob'],pool};await reject(commit(resultWrites(s)));
 await accept(put(`matches/${code}/ratingVotes/bob`,{ply:2,winner:1,name:'bob'},'bob'));
 await reject(commit(resultWrites(s)));
 await accept(put(`matches/${code}/ratingVotes/bob`,{ply:2,winner:0,name:'bob'},'bob'));
 r.moves.push({...r.moves[0]});await seed(`matches/${code}`,r);await reject(commit(resultWrites(s)));
});
test('forged math, pool, winner, partial players and missing histories fail',async()=>{
 const s=await setup();const good=resultWrites(s);
 for(const edit of [w=>{w[1].update.fields.rating.integerValue='9999';},w=>{w[0].update.fields.pool.stringValue='hex-2-2-sharedRoads-open';},w=>{w[0].update.fields.winner.integerValue='1';},w=>{w.splice(3,2);},w=>{w.splice(2,1);},w=>{w[1].update.fields.gamesPlayed.integerValue='100';}]) {
  const w=structuredClone(good);edit(w);await reject(commit(w));
 }
 await reject(commit(good,'stranger'));await accept(commit(good));
});
test('a resignation must award the other player and shared-device ownership is unrated',async()=>{
 const s=await setup();s.r.resigned='ivory';await seed(`matches/${code}`,s.r);await reject(commit(resultWrites(s)));
 for(const uid of s.users)await accept(put(`matches/${code}/ratingVotes/${uid}`,{ply:2,winner:1,name:uid},uid));
 await accept(commit(resultWrites(s,1)));
});
test('receipts and samples cannot be enumerated or inspected by unrelated accounts',async()=>{
 const s=await setup();await accept(commit(resultWrites(s)));
 await reject(request(`/ratingResults/${humanKey}`,'GET',undefined,'stranger'));
 await reject(request('/ratingResults','GET',undefined,'alice'));
 await accept(request(`/ratingResults/${humanKey}`,'GET',undefined,'bob'));
});
const bot='ai_shared-search-v1_easy';
async function aiSetup() {
 const anchor={rating:1400,gamesPlayed:10,wins:8,losses:2,draws:0,opponents:0};
 await seed(`ratingPools/${pool}/players/alice`,anchor);return anchor;
}
function aiWrites(source='local-1',before={rating:1200,gamesPlayed:0,wins:0,losses:0,draws:0,opponents:0},known=false) {
 const id=hash(`alice_${source}`);const rating=Math.round(before.rating+(before.gamesPlayed<30?40:20)*(1-1/(1+10**((1400-before.rating)/400))));
 return [write(`ratingResults/${id}`,{kind:'ai',pool,participants:[bot],actor:'alice',source,winner:1,ply:2,moves:[{},{}],level:'easy',engine:'shared-search-v1'},['at']),
 write('ratingLimits/alice_'+pool+'_easy',{lastResult:id},['at']),
 ...(!known?[write(`ratingPools/${pool}/players/${bot}/opponents/alice`,{lastResult:id},['firstAt'])]:[]),
 write(`ratingPools/${pool}/players/${bot}`,{pool,displayName:'Easy AI',rating,gamesPlayed:before.gamesPlayed+1,wins:before.wins+1,losses:before.losses,draws:before.draws,isAi:true,established:false,opponents:before.opponents+(known?0:1),lastResult:id,engineVersion:'shared-search-v1',aiDifficulty:'easy'},['lastUpdated']),
 write(`ratingPools/${pool}/players/${bot}/history/${before.gamesPlayed+1}`,{rating,score:1,opponentName:'Established player'},['timestamp']),write(`aiResultKeys/alice_${source}`,{result:id})];
}
test('local AI estimates update only the bot, require established anchor and enforce 24-hour sampling',async()=>{
 await reject(commit(aiWrites()));await aiSetup();const first=aiWrites();await accept(commit(first));await reject(commit(first));
 const b={rating:Number(first.find(w=>w.update.name.endsWith('/players/'+bot)).update.fields.rating.integerValue),gamesPlayed:1,wins:1,losses:0,draws:0,opponents:1};
 await reject(commit(aiWrites('local-2',b,true)));
 await seed('ratingLimits/alice_'+pool+'_easy',{lastResult:hash('alice_local-1'),at:new Date(Date.now()-25*3600000)});
 await accept(commit(aiWrites('local-2',b,true)));
});
test('AI spoofed engine, points, actor and omitted quota/opponent records fail',async()=>{
 await aiSetup();const good=aiWrites();
 for(const edit of [w=>{w[0].update.fields.engine.stringValue='fake';},w=>{w.find(item=>item.update.name.endsWith('/players/'+bot)).update.fields.rating.integerValue='5000';},w=>{w[0].update.fields.actor.stringValue='bob';},w=>{w.splice(1,1);},w=>{w.splice(2,1);},w=>{w.find(item=>item.update.name.endsWith('/players/'+bot)).update.fields.opponents.integerValue='100';}]) {const w=structuredClone(good);edit(w);await reject(commit(w));}
 await accept(commit(good));
});

test('the last vote and settlement can share one atomic transaction',async()=>{
 const r=room(4);await seed(`matches/${code}`,r);
 const users=Object.values(r.owners);
 for(const uid of users.slice(0,3)) await accept(put(`matches/${code}/ratingVotes/${uid}`,{ply:4,winner:0,name:uid},uid));
 const s={users,pool:'square-5-4-sharedRoads-open'};
 await accept(commit([write(`matches/${code}/ratingVotes/dan`,{ply:4,winner:0,name:'dan'}),...resultWrites(s)],'dan'));
 r.moves.push({...r.moves[0]});await reject(put(`matches/${code}`,r,'alice'));
});
test('two valid settlements based on stale totals cannot erase one another',async()=>{
 const s=await setup();const first=resultWrites(s);await accept(commit(first));
 const other='UBBBBBB';const otherKey=hash(other);const r=room();r.code=other;await seed(`matches/${other}`,r);
 for(const uid of s.users) await accept(put(`matches/${other}/ratingVotes/${uid}`,{ply:2,winner:0,name:uid},uid));
 const stale=JSON.parse(JSON.stringify(first).replaceAll(humanKey,otherKey).replaceAll(code,other));
 await reject(commit(stale));
});
test('an AI source cannot be counted again under a new receipt after its cooldown',async()=>{
 await aiSetup();const first=aiWrites();await accept(commit(first));
 await seed('ratingLimits/alice_'+pool+'_easy',{lastResult:hash('alice_local-1'),at:new Date(Date.now()-25*3600000)});
 const before={rating:Number(first.find(w=>w.update.name.endsWith('/players/'+bot)).update.fields.rating.integerValue),gamesPlayed:1,wins:1,losses:0,draws:0,opponents:1};
 const duplicate=JSON.parse(JSON.stringify(aiWrites('local-1',before,true)).replaceAll(hash('alice_local-1'),hash('different')));
 await reject(commit(duplicate));
});

for(const shape of ['square','hex']) for(const size of shape==='square'?[3,4,5,6,7,8]:[2,3,4]) for(const n of [2,3,4]) {
 test(`${shape} size ${size} with ${n} independent accounts uses its own ladder`,async()=>{
  const r=room(n);r.config.shape=shape;r.config.size=size;r.config.profile=shape==='square'&&n===2?'standardTak':'sharedRoads';
  const ladder=`${shape}-${size}-${n}-${r.config.profile}-open`;
  await seed(`matches/${code}`,r);const users=Object.values(r.owners);
  for(const uid of users)await accept(put(`matches/${code}/ratingVotes/${uid}`,{ply:n,winner:n-1,name:uid},uid));
  await accept(commit(resultWrites({users,pool:ladder},n-1)));
 });
}
for(const [seconds,category] of [[300,'fast'],[600,'long']]) test(`clock category ${category} cannot award points to the untimed ladder`,async()=>{
 const s=await setup();s.r.config.clockSeconds=seconds;await seed(`matches/${code}`,s.r);
 await reject(commit(resultWrites(s)));
 await accept(commit(resultWrites({...s,pool:`square-5-2-standardTak-${category}`})));
});
for(const level of ['medium','hard','expert'])test(`${level} locally reported AI keeps an independent measured record`,async()=>{
 await aiSetup();const writes=JSON.parse(JSON.stringify(aiWrites()).replaceAll('_easy',`_${level}`).replaceAll('"easy"',`"${level}"`).replaceAll('Easy AI',`${level[0].toUpperCase()+level.slice(1)} AI`));
 await accept(commit(writes));
});
test('AI community samples can use a Hex ladder without affecting Square',async()=>{
 const ladder='hex-2-2-sharedRoads-open';await seed(`ratingPools/${ladder}/players/alice`,{rating:1400,gamesPlayed:10,wins:8,losses:2,draws:0,opponents:0});
 await accept(commit(JSON.parse(JSON.stringify(aiWrites()).replaceAll(pool,ladder))));
});
test('shared-device seats and missing signed-in owners cannot be rated',async()=>{
 const r=room(3);r.owners.charcoal='alice';r.config.seats[1].control='localHuman';await seed(`matches/${code}`,r);
 for(const uid of ['alice','carol'])await accept(put(`matches/${code}/ratingVotes/${uid}`,{ply:3,winner:0,name:uid},uid));
 await reject(commit(resultWrites({users:['alice','alice','carol'],pool:'square-5-3-sharedRoads-open'})));
});

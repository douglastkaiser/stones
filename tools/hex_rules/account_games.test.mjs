import {readFile} from 'node:fs/promises';
import {before,beforeEach,after,test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeHexEmulator,doc,getDoc,setDoc,setWithServerTime,assertFails,assertSucceeds,updateDoc} from './emulator_rest.mjs';
let environment;
const project='demo-stones-hex',origin=`http://${process.env.FIRESTORE_EMULATOR_HOST??'127.0.0.1:8088'}`;
if(!/^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(origin))throw new Error('Loopback emulator required');
const root=`projects/${project}/databases/(default)/documents`;
const encode=value=>value===null?{nullValue:null}:typeof value==='string'?{stringValue:value}:typeof value==='boolean'?{booleanValue:value}:typeof value==='number'?{integerValue:String(value)}:Array.isArray(value)?{arrayValue:{values:value.map(encode)}}:{mapValue:{fields:Object.fromEntries(Object.entries(value).map(([k,v])=>[k,encode(v)]))}};
const write=(path,data,stamps=[])=>({update:{name:`${root}/${path}`,fields:encode(data).mapValue.fields},...(stamps.length?{updateTransforms:stamps.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}:{})});
function token(uid){const now=Math.floor(Date.now()/1000),b=v=>Buffer.from(JSON.stringify(v)).toString('base64url');return `${b({alg:'none',typ:'JWT'})}.${b({sub:uid,user_id:uid,aud:project,iss:`https://securetoken.google.com/${project}`,iat:now,exp:now+3600,auth_time:now,firebase:{identities:{},sign_in_provider:'anonymous'}})}.`;}
async function commit(uid,writes){const response=await fetch(`${origin}/v1/${root}:commit`,{method:'POST',headers:{Authorization:`Bearer ${token(uid)}`,'Content-Type':'application/json'},body:JSON.stringify({writes})});const text=await response.text();if(!response.ok){const error=new Error(text);error.status=response.status;throw error;}return JSON.parse(text);}
const room=()=>({version:1,code:'UABCDEF',host:'host',config:{version:1,shape:'square',size:5,seats:[{id:'ivory',control:'localHuman',level:'easy'},{id:'charcoal',control:'onlineHuman',level:'easy'}],starter:'ivory',profile:'standardTak'},owners:{ivory:'host',charcoal:null},styles:{ivory:'standard',charcoal:'standard'},boardTheme:'morocco',moves:[],resigned:null,timedOut:null,clock:null,aiRunner:null,aiLeaseAt:null});
const entry=()=>({code:'UABCDEF',hex:false,unified:true,archived:false,muted:false});
const index=(uid='host',data=entry())=>write(`playerGames/${uid}/rooms/UABCDEF`,data,['addedAt']);
const job=()=>write('turnNotificationJobs/UABCDEF_0_0',{code:'UABCDEF',format:'matches',ply:0,revision:0,state:'pending'},['dueAt','createdAt']);
before(async()=>{environment=await initializeHexEmulator({projectId:project,firestore:{rules:await readFile(new URL('../../firestore.rules',import.meta.url),'utf8')}});});
beforeEach(async()=>environment.clearFirestore());after(async()=>environment?.cleanup());
test('hosting and account registration commit atomically using getAfter',async()=>{
 await assertSucceeds(commit('host',[write('matches/UABCDEF',room()),index()]));
 assert.equal((await getDoc(doc('host','playerGames/host/rooms','UABCDEF'))).data().archived,false);
 await assertFails(getDoc(doc('outsider','playerGames/host/rooms','UABCDEF')));
 await assertFails(commit('outsider',[index('outsider')]));
});
test('invalid companion index rolls back the room creation',async()=>{
 await assertFails(commit('host',[write('matches/UABCDEF',room()),index('other')]));
 await assert.rejects(getDoc(doc('host','matches','UABCDEF')));
});
test('archive and mute are owner-only and cannot rewrite room identity',async()=>{
 await commit('host',[write('matches/UABCDEF',room()),index()]);
 const own=doc('host','playerGames/host/rooms','UABCDEF');
 await assertSucceeds(updateDoc(own,{archived:true,muted:true}));
 await assertFails(updateDoc(doc('other','playerGames/host/rooms','UABCDEF'),{muted:false}));
 await assertFails(updateDoc(own,{hex:true}));
});
test('turn outbox requires a simultaneous authorized room transition',async()=>{
 await setDoc(doc('host','matches','UABCDEF'),room());
 await assertFails(commit('host',[job()]));
 const joined=room();joined.owners.charcoal='guest';
 await assertSucceeds(commit('guest',[write('matches/UABCDEF',joined,['startedAt']),index('guest'),job()]));
 await assertFails(getDoc(doc('guest','turnNotificationJobs','UABCDEF_0_0')));
 await assertFails(commit('guest',[job()]));
});
test('preferences and device tokens are private to their owner',async()=>{
 const prefs=doc('host','playerGames/host/preferences','notifications');
 await assertSucceeds(setDoc(prefs,{enabled:true}));
 await assertFails(getDoc(doc('other','playerGames/host/preferences','notifications')));
 const device=doc('host','playerGames/host/devices','a'.repeat(24));
 await assertSucceeds(setWithServerTime(device,{token:'x'.repeat(40),enabled:true},'updatedAt'));
 await assertFails(getDoc(doc('other','playerGames/host/devices','a'.repeat(24))));
});

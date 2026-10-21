import {readFile} from 'node:fs/promises';
import {before, beforeEach, after, test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeHexEmulator, assertFails, assertSucceeds, doc, setDoc,
  getDoc, updateDoc, updateWithServerTime, setWithServerTime, deleteDoc} from './emulator_rest.mjs';
let env;
const project='demo-stones-hex';
const root=`http://${process.env.FIRESTORE_EMULATOR_HOST??'127.0.0.1:8088'}/v1/projects/${project}/databases/(default)/documents`;
const room=uid=>doc(uid,'matches','UCHATTT');
const message=(uid,id='a'.repeat(32))=>doc(uid,'matches/UCHATTT/chat',id);
const base=()=>({version:1,code:'UCHATTT',host:'host',config:{version:1,ratingVersion:3,aiEngine:'shared-search-v2',shape:'hex',size:2,starter:'ivory',profile:'sharedRoads',seats:[
 {id:'ivory',control:'localHuman',level:'easy'},{id:'charcoal',control:'onlineHuman',level:'easy'}]},
 owners:{ivory:'host',charcoal:null},styles:{ivory:'morocco',charcoal:'standard'},boardTheme:'celestial',moves:[],resigned:null,timedOut:null,aiRunner:null,aiLeaseAt:null,clock:null,
 startedAt:null,lastMoveAt:null,finishedAt:null});
function token(uid,provider='anonymous') {
 const now=Math.floor(Date.now()/1000),b=v=>Buffer.from(JSON.stringify(v)).toString('base64url');
 return `${b({alg:'none',typ:'JWT'})}.${b({sub:uid,user_id:uid,aud:project,iss:`https://securetoken.google.com/${project}`,iat:now,exp:now+3600,auth_time:now,firebase:{identities:{},sign_in_provider:provider}})}.`;
}
async function request(path,method,body,uid='host',provider) {
 const result=await fetch(`${root}${path}`,{method,headers:{Authorization:`Bearer ${token(uid,provider)}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
 return {status:result.status,body:await result.json()};
}
async function query(uid,expiry=new Date(Date.now()+30000),limit=50) {
 return request('/matches/UCHATTT:runQuery','POST',{structuredQuery:{from:[{collectionId:'chat'}],
  where:{fieldFilter:{field:{fieldPath:'expiresAt'},op:'GREATER_THAN',value:{timestampValue:expiry.toISOString()}}},limit}},uid);
}
before(async()=>{env=await initializeHexEmulator({projectId:project,firestore:{rules:await readFile(new URL('../../firestore.rules',import.meta.url),'utf8')}});});
beforeEach(async()=>{await env.clearFirestore();await setDoc(room('host'),base());await updateWithServerTime(room('guest'),{'owners.charcoal':'guest','styles.charcoal':'kyoto'},'startedAt');});
after(async()=>env?.cleanup());
test('server timing starts at readiness and records terminal acknowledgements without changing styles',async()=>{
 const first=(await getDoc(room('host'))).data();assert(first.startedAt instanceof Date);assert.equal(first.styles.charcoal,'kyoto');
 await assertFails(updateDoc(room('host'),{startedAt:new Date()}));
 const move={seat:'ivory',x:0,y:0,type:'flat',direction:null,drops:[]};
 await assertSucceeds(updateWithServerTime(room('host'),{moves:[move]},'lastMoveAt'));
 await assertFails(updateDoc(room('host'),{lastMoveAt:new Date(Date.now()+100000)}));
 await assertSucceeds(updateWithServerTime(room('guest'),{resigned:'charcoal'},'finishedAt'));
 const ended=(await getDoc(room('host'))).data();assert(ended.finishedAt>=ended.startedAt);
});
test('chat is participant-only, immutable, bounded, expires and can be deleted',async()=>{
 const data={sender:'host',text:'hello',expiresAt:new Date(Date.now()+300000)};
 await assertSucceeds(setWithServerTime(message('host'),data,'createdAt'));
 await assertSucceeds(getDoc(message('guest')));
 await assertFails(getDoc(message('stranger')));
 await assertFails(updateDoc(message('host'),{text:'rewritten'}));
 await assertFails(setWithServerTime(message('guest','b'.repeat(32)),data,'createdAt'));
 await assertFails(setWithServerTime(message('host','c'.repeat(32)),{...data,text:'x'.repeat(501)},'createdAt'));
 await assertFails(setWithServerTime(message('host','d'.repeat(32)),{...data,expiresAt:new Date(Date.now()+600000)},'createdAt'));
 assert.equal((await query('guest')).status,200);assert.equal((await query('stranger')).status,403);
 assert.equal((await query('guest',new Date(0))).status,403);assert.equal((await query('guest',undefined,51)).status,403);
 await assertFails(deleteDoc(message('guest')));await assertSucceeds(deleteDoc(message('host')));
});
test('closed games refuse new messages and reads but allow participant cleanup',async()=>{
 await setWithServerTime(message('host'),{sender:'host',text:'temporary',expiresAt:new Date(Date.now()+300000)},'createdAt');
 await updateWithServerTime(room('host'),{resigned:'ivory'},'finishedAt');
 await assertFails(getDoc(message('guest')));
 await assertFails(setWithServerTime(message('guest','e'.repeat(32)),{sender:'guest',text:'late',expiresAt:new Date(Date.now()+300000)},'createdAt'));
 await assertSucceeds(deleteDoc(message('guest')));
});
test('account status is authenticated metadata; guests cannot impersonate Google accounts',async()=>{
 assert.equal((await request('/playerAccounts/guest','PATCH',{fields:{registered:{booleanValue:false}}},'guest')).status,200);
 assert.equal((await request('/playerAccounts/guest','PATCH',{fields:{registered:{booleanValue:true}}},'guest')).status,403);
 assert.equal((await request('/playerAccounts/host','PATCH',{fields:{registered:{booleanValue:false}}},'guest')).status,403);
 const result=await request('/playerAccounts/guest','PATCH',{fields:{registered:{booleanValue:true}}},'guest','google.com');
 assert.equal(result.status,200,JSON.stringify(result.body));
 await assertFails(setDoc(doc('guest','playerAccounts','guest'),{registered:false,email:'private@example.com'}));
});

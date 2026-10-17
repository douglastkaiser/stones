const {test} = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');
const R = require('./ratings.cjs');
class HttpsError extends Error { constructor(code,message) { super(message);this.code=code; } }
class DB {
  data=new Map(); queue=Promise.resolve();
  doc(path) { return {path,get:async()=>this.snapshot(path),collection:name=>({doc:id=>this.doc(`${path}/${name}/${id}`)})}; }
  snapshot(path) {return {exists:this.data.has(path),data:()=>structuredClone(this.data.get(path))};}
  runTransaction(fn) {
    const job=this.queue.then(async()=>{
      const writes=[];
      const result=await fn({get:async ref=>this.snapshot(ref.path),getAll:async(...refs)=>refs.map(r=>this.snapshot(r.path)),
        set:(ref,data)=>writes.push([ref.path,structuredClone(data)])});
      for(const [key,data]of writes)this.data.set(key,data);
      return result;
    });this.queue=job.catch(()=>{});return job;
  }
}
const db=new DB();
const load=Module._load;
Module._load=function(name,...args) {
  if(name==='firebase-functions/v2/https')return {onCall:(_,fn)=>fn,HttpsError};
  if(name==='firebase-functions/v2/firestore')return {onDocumentWritten:(_,fn)=>fn};
  if(name==='firebase-admin/app')return {initializeApp:()=>{}};
  if(name==='firebase-admin/firestore')return {getFirestore:()=>db};
  if(name==='firebase-admin/auth')return {getAuth:()=>({getUser:async uid=>({providerData:uid.startsWith('guest')?[]:[{}],displayName:uid})})};
  return load.call(this,name,...args);
};
const service=require('./index.cjs');
Module._load=load;
const auth=uid=>({uid,token:{firebase:{sign_in_provider:'google.com'}}});
const config={version:1,shape:'square',size:5,starter:'ivory',profile:'standardTak',
 seats:[{id:'ivory',control:'ai',level:'easy'},{id:'charcoal',control:'localHuman',level:'easy'}]};
const place=(seat,x,y)=>({seat,x,y,type:'flat',direction:null,drops:[]});
const prefix=async moves=>{
 const response=await service.ratingBotMove({auth:auth('alice'),data:{id:'local-game',config,moves}});
 return response.move;
};
test('unauthenticated and anonymous users cannot request calibration',async()=>{
 await assert.rejects(service.ratingBotMove({data:{}}),e=>e.code==='unauthenticated');
 await assert.rejects(service.ratingBotMove({auth:{uid:'guest',token:{firebase:{sign_in_provider:'anonymous'}}},data:{}}),e=>e.code==='unauthenticated');
});
test('server returns same evidence on retry and rejects changed history or illegality',async()=>{
 db.data.clear();
 const first=await prefix([]);
 assert.deepEqual(await prefix([]),first);
 assert.equal(db.data.get(`ratingLimits/${R.hash(['alice',new Date().toISOString().slice(0,10)])}`).moves,1);
 await assert.rejects(prefix([place('ivory',90,90),place('charcoal',0,0)]));
 assert.equal(db.data.get(`calibrationSessions/${R.hash(['alice','local-game'])}`).evidence[0].move.seat,'ivory');
});
test('calibration completion cannot count forged client AI moves',async()=>{
 db.data.clear();
 const cfg={...config,seats:[{id:'ivory',control:'localHuman',level:'easy'},{id:'charcoal',control:'ai',level:'easy'}]};
 const moves=[place('ivory',4,4),place('charcoal',0,0)];
 for(let x=1;x<5;x++){moves.push(place('ivory',x,0));if(x<4)moves.push({...place('charcoal',x,3),type:'standing'});}
 await assert.rejects(service.completeCalibration({auth:auth('alice'),data:{id:'forged',config:cfg,moves}}),e=>e.code==='failed-precondition');
 assert.equal([...db.data.keys()].filter(k=>k.startsWith('ratingReceipts/')).length,0);
});
test('server trigger excludes guests and illegal histories and deduplicates terminal delivery',async()=>{
 db.data.clear();
 const cfg={...config,seats:[{id:'ivory',control:'localHuman',level:'easy'},{id:'charcoal',control:'onlineHuman',level:'easy'}]};
 const moves=[place('ivory',4,4),place('charcoal',0,0)];
 for(let x=1;x<5;x++){moves.push(place('ivory',x,0));if(x<4)moves.push({...place('charcoal',x,3),type:'standing'});}
 const room={code:'UAAAAAA',config:cfg,owners:{ivory:'alice',charcoal:'bob'},moves};
 const event=data=>({params:{code:data.code},time:new Date().toISOString(),data:{after:{data:()=>data}}});
 await service.rateCompletedMatch(event({...room,owners:{ivory:'alice',charcoal:'guest-bob'}}));
 assert.equal(db.data.size,0);
 await service.rateCompletedMatch(event({...room,moves:[place('charcoal',0,0)]}));
 assert.equal(db.data.size,0);
 await Promise.all([service.rateCompletedMatch(event(room)),service.rateCompletedMatch(event(room))]);
 assert.equal(db.data.get('ratingPools/square-5-2-standardTak-open/players/alice').gamesPlayed,1);
});
test('hash ignores JSON object order, preserving Firestore evidence semantics',()=>{
 assert.equal(R.hash({config:{a:1,b:2},moves:[{x:1,y:2}]}),R.hash({moves:[{y:2,x:1}],config:{b:2,a:1}}));
});

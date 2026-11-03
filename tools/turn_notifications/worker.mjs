// Cloudflare Worker: bounded durable outbox delivery, without client wakeups.
const BASE = 'https://firestore.googleapis.com/v1/';
const encode = v => v === null ? {nullValue:null} : typeof v === 'boolean' ? {booleanValue:v} : typeof v === 'number' ? {integerValue:String(v)} : typeof v === 'string' ? {stringValue:v} : {mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,x])=>[k,encode(x)]))}};
const decode = v => 'timestampValue' in v ? v.timestampValue : 'stringValue' in v ? v.stringValue : 'integerValue' in v ? Number(v.integerValue) : 'booleanValue' in v ? v.booleanValue : 'nullValue' in v ? null : 'arrayValue' in v ? (v.arrayValue.values??[]).map(decode) : Object.fromEntries(Object.entries(v.mapValue?.fields??{}).map(([k,x])=>[k,decode(x)]));
const fields = v => Object.fromEntries(Object.entries(v).map(([k,x])=>[k,encode(x)]));
let cached;
const b64 = bytes => btoa(String.fromCharCode(...bytes)).replaceAll('+','-').replaceAll('/','_').replaceAll('=','');
async function bearer(env) {
 if(cached?.project===env.FIREBASE_PROJECT_ID && cached.expires>Date.now()+60000)return cached.token;
 const now=Math.floor(Date.now()/1000);
 const header=b64(new TextEncoder().encode(JSON.stringify({alg:'RS256',typ:'JWT'})));
 const payload=b64(new TextEncoder().encode(JSON.stringify({iss:env.SERVICE_ACCOUNT_EMAIL,scope:'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600})));
 const key=await crypto.subtle.importKey('pkcs8',Uint8Array.from(atob(env.SERVICE_ACCOUNT_PRIVATE_KEY.replace(/-----[^-]+-----|\s/g,'')),c=>c.charCodeAt(0)),{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
 const assertion=header+'.'+payload;
 const signature=b64(new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,new TextEncoder().encode(assertion))));
 const response=await fetch('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion:assertion+'.'+signature})});
 if(!response.ok)throw new Error('oauth_failed');
 const result=await response.json();cached={project:env.FIREBASE_PROJECT_ID,token:result.access_token,expires:Date.now()+result.expires_in*1000};return cached.token;
}
export function recipient(room, job) {
 if(job.format==='matches') {
  if(room.moves.length!==job.ply || (room.revision??0)!==job.revision || room.resigned || room.timedOut || room.finishedAt || room.takeback)return null;
  const seats=room.config.seats;
  if(seats.some(s=>s.control!=='ai'&&!room.owners[s.id]))return null;
  const index=seats.findIndex(s=>s.id===room.config.starter);
  const seat=seats[(index+room.moves.length)%seats.length];
  if(seat.control==='ai')return null;
  if(room.clock?.started?.[seat.id] && Date.now()>=Date.parse(room.clock.started[seat.id])+room.clock.bank[seat.id])return null;
  return room.owners[seat.id];
 }
 if(job.format==='hexGames') {
  if(room.ply!==job.ply || Object.keys(room.kinds).some(k=>room.kinds[k]!=='ai'&&!room.owners[k]))return null;
  const seat=String((room.starter+room.ply)%3);return room.kinds[seat]==='ai'?null:room.owners[seat];
 }
 if(job.format==='games' && room.moves.length===job.ply && room.status==='playing')return room[room.currentTurn]?.id;
 return null;
}
export async function processJob(api, snapshot, now = Date.now()) {
 const job=snapshot.data;
 if(!['matches','hexGames','games'].includes(job.format) || !/^([UH][A-Z]{6}|[A-Z]{6})$/.test(job.code))return;
 // A precondition on updateTime provides an atomic lease across concurrent invocations.
 const claimed=await api.patch(snapshot,{...job,dueAt:new Date(now+120000).toISOString(),attempts:(job.attempts??0)+1},['dueAt']);
 const room=await api.get(`${job.format}/${job.code}`);
 const uid=room && recipient(room.data,job);
 const finish=async(state)=>api.patch(claimed,{...claimed.data,state,completedAt:new Date(now).toISOString()},[]);
 if(!uid || now-Date.parse(job.createdAt)>86400000)return finish('obsolete');
 const [preferences, game]=await Promise.all([api.get(`playerGames/${uid}/preferences/notifications`),api.get(`playerGames/${uid}/rooms/${job.code}`)]);
 if(preferences?.data.enabled!==true || game?.data.muted===true)return finish('muted');
 const devices=await api.devices(uid,job.cursor);
 const sent={...(job.sent??{})};
 for(const device of devices) {
  const id=device.name.split('/').at(-1);
  if(sent[id] || !device.data.enabled || now-Date.parse(device.data.updatedAt)>30*86400000)continue;
  // Revalidate before each delivery: a player may have moved during the batch.
  const latest=await api.get(`${job.format}/${job.code}`);
  if(!latest || recipient(latest.data,job)!==uid)return finish('obsolete');
  const result=await api.send(device.data.token,{uid,code:job.code,event:snapshot.name.split('/').at(-1)});
  if(result==='invalid')await api.remove(device.name);
  else if(result!=='ok')throw new Error('delivery_retry');
  sent[id]=true;
  Object.assign(claimed,await api.patch(claimed,{...claimed.data,sent},[]));
 }
 if(devices.length===5)return api.patch(claimed,{...claimed.data,cursor:devices.at(-1).name,sent,dueAt:new Date(now+60000).toISOString()},['dueAt']);
 return finish('sent');
}
function restApi(env,token) {
 const root=`projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents`;
 async function request(path,method='GET',body) {
  const response=await fetch(BASE+path,{method,headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});
  if(response.status===404)return null;
  if(!response.ok)throw new Error('firestore_'+response.status);
  const text=await response.text();return text?JSON.parse(text):{};
 }
 const document=raw=>raw?{name:raw.name,updateTime:raw.updateTime,data:Object.fromEntries(Object.entries(raw.fields??{}).map(([k,v])=>[k,decode(v)]))}:null;
 return {
  async due(){const result=await request(root+':runQuery','POST',{structuredQuery:{from:[{collectionId:'turnNotificationJobs'}],where:{compositeFilter:{op:'AND',filters:[{fieldFilter:{field:{fieldPath:'state'},op:'EQUAL',value:{stringValue:'pending'}}},{fieldFilter:{field:{fieldPath:'dueAt'},op:'LESS_THAN_OR_EQUAL',value:{timestampValue:new Date().toISOString()}}}]}},orderBy:[{field:{fieldPath:'dueAt'},direction:'ASCENDING'}],limit:1}});return result.filter(r=>r.document).map(r=>document(r.document));},
  async get(path){return document(await request(root+'/'+path));},
  async patch(snapshot,data,timestamps){const value=fields(data);for(const key of ['dueAt','createdAt',...timestamps])if(data[key])value[key]={timestampValue:data[key]};
   const result=await request(root+':commit','POST',{writes:[{update:{name:snapshot.name,fields:value},currentDocument:{updateTime:snapshot.updateTime}}]});return {...snapshot,data,updateTime:result.writeResults[0].updateTime};},
  async devices(uid,cursor){const q={from:[{collectionId:'devices'}],orderBy:[{field:{fieldPath:'__name__'},direction:'ASCENDING'}],limit:5};if(cursor)q.startAt={values:[{referenceValue:cursor}],before:false};const rows=await request(root+`/playerGames/${uid}:runQuery`,'POST',{structuredQuery:q});return rows.filter(r=>r.document).map(r=>document(r.document));},
  remove:name=>request(name,'DELETE'),
  async send(token,data){const response=await fetch(`https://fcm.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/messages:send`,{method:'POST',headers:{Authorization:`Bearer ${cached.token}`,'Content-Type':'application/json'},body:JSON.stringify({message:{token,data,android:{ttl:'3600s',collapse_key:data.code,notification:{title:'Stones',body:'It’s your turn in Stones.',tag:data.code}},webpush:{headers:{TTL:'3600',Urgency:'normal'}}}})});if(response.ok)return 'ok';const error=await response.json();return error.error?.details?.some(d=>d.errorCode==='UNREGISTERED')?'invalid':'retry';}
 };
}
export default {
 async scheduled(_event,env){if(env.ENABLED!=='true')return;try{const api=restApi(env,await bearer(env));for(const job of await api.due())await processJob(api,job);console.log(JSON.stringify({event:'turn_sender_tick',ok:true}));}catch{console.error(JSON.stringify({event:'turn_sender_tick',ok:false}));}},
 async fetch(){return new Response('Stones turn sender',{status:200});}
};

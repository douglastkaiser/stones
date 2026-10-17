import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {before, beforeEach, after, test} from 'node:test';
import {initializeHexEmulator, assertFails, assertSucceeds, doc, setDoc,
  getDoc, collection, getDocs} from './emulator_rest.mjs';
let environment;
before(async()=>{environment=await initializeHexEmulator({projectId:'demo-stones-hex',
  firestore:{rules:await readFile(new URL('../../firestore.rules',import.meta.url),'utf8')}});});
beforeEach(async()=>{
 await environment.clearFirestore();
 for(const path of [`${base}/players/alice`,`${base}/players/alice/history/game`,`${base}/standings/alice`]) {
   const address=process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8088';
   assert.match(address,/^(127\.0\.0\.1|localhost):\d+$/);
   const response=await fetch(`http://${address}/v1/projects/demo-stones-hex/databases/(default)/documents/${path}`,
     {method:'PATCH',headers:{'Content-Type':'application/json',Authorization:'Bearer owner'},body:JSON.stringify({fields:{rating:{integerValue:'1200'}}})});
   assert(response.ok,await response.text());
 }
});
after(async()=>environment?.cleanup());
const db=()=>environment.unauthenticatedContext().firestore();
const signed=()=>environment.authenticatedContext('alice').firestore();
const base='ratingPools/square-5-2-standardTak-open';
const reference=(uid,path)=>{const parts=path.split('/');return doc(uid,parts.slice(0,-1).join('/'),parts.at(-1));};
test('public competition reads work without a Firebase identity',async()=>{
  await assertSucceeds(getDoc(reference(db(),`${base}/players/alice`)));
  await assertSucceeds(getDoc(reference(db(),`${base}/players/alice/history/game`)));
  await assertSucceeds(getDocs(collection(db(),`${base}/standings`)));
});
test('even the named player cannot forge their rank or bot strength',async()=>{
  for(const path of [`${base}/players/alice`,`${base}/players/ai_easy`,`${base}/standings/alice`,`${base}/players/alice/history/game`]) {
    await assertFails(setDoc(reference(signed(),path),{rating:9999,gamesPlayed:100}));
    await assertFails(setDoc(reference(db(),path),{rating:9999,gamesPlayed:100}));
  }
});
test('receipts, proof, opponent and quota data remain private and server-owned',async()=>{
  for(const path of ['ratingReceipts/match-UAAAAAA','calibrationSessions/session',
    `${base}/players/ai_easy/opponents/alice`,`${base}/players/ai_easy/samples/today`]) {
    await assertFails(getDoc(reference(signed(),path)));
    await assertFails(setDoc(reference(signed(),path),{rating:9999}));
  }
});
test('old unverified rating collection is still denied',async()=>{
  await assertFails(getDoc(reference(signed(),'ratings/alice')));
  await assertFails(setDoc(reference(signed(),'ratings/alice'),{rating:9999}));
});

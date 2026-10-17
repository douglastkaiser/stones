import {readFile} from 'node:fs/promises';
import {before, beforeEach, after, test} from 'node:test';
import {initializeHexEmulator, assertFails, assertSucceeds, doc, setDoc,
  getDoc, collection, getDocs} from './emulator_rest.mjs';
let environment;
before(async()=>{environment=await initializeHexEmulator({projectId:'demo-stones-hex',
  firestore:{rules:await readFile(new URL('../../firestore.rules',import.meta.url),'utf8')}});});
beforeEach(async()=>environment.clearFirestore());
after(async()=>environment?.cleanup());
const db=()=>environment.unauthenticatedContext().firestore();
const signed=()=>environment.authenticatedContext('alice').firestore();
const base='ratingPools/square-5-2-standardTak-open';
test('public competition reads work without a Firebase identity',async()=>{
  await assertSucceeds(getDoc(doc(db(),`${base}/players/alice`)));
  await assertSucceeds(getDoc(doc(db(),`${base}/players/alice/history/game`)));
  await assertSucceeds(getDocs(collection(db(),`${base}/standings`)));
});
test('even the named player cannot forge their rank or bot strength',async()=>{
  for(const path of [`${base}/players/alice`,`${base}/players/ai_easy`,`${base}/standings/alice`,`${base}/players/alice/history/game`]) {
    await assertFails(setDoc(doc(signed(),path),{rating:9999,gamesPlayed:100}));
    await assertFails(setDoc(doc(db(),path),{rating:9999,gamesPlayed:100}));
  }
});
test('receipts, proof, opponent and quota data remain private and server-owned',async()=>{
  for(const path of ['ratingReceipts/match-UAAAAAA','calibrationSessions/session','ratingLimits/daily',
    `${base}/players/ai_easy/opponents/alice`,`${base}/players/ai_easy/samples/today`]) {
    await assertFails(getDoc(doc(signed(),path)));
    await assertFails(setDoc(doc(signed(),path),{rating:9999}));
  }
});
test('old unverified rating collection is still denied',async()=>{
  await assertFails(getDoc(doc(signed(),'ratings/alice')));
  await assertFails(setDoc(doc(signed(),'ratings/alice'),{rating:9999}));
});

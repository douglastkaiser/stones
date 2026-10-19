import {readFile} from 'node:fs/promises';
import {before, beforeEach, after, test} from 'node:test';
import {initializeHexEmulator, assertFails, assertSucceeds, doc, setDoc, getDoc,
  setWithServerTime, queryDocs, deleteDoc, updateDoc, runTransaction} from './emulator_rest.mjs';
import assert from 'node:assert/strict';
let environment;
const ref = (uid, path, id) => doc(uid, path, id);
const room = () => ({version: 1, code: 'UABCDEF', host: 'host',
  config: {version: 1, shape: 'square', size: 5,
    seats: [{id: 'ivory', control: 'localHuman', level: 'easy'}, {id: 'charcoal', control: 'onlineHuman', level: 'easy'}],
    starter: 'ivory', profile: 'standardTak'},
  owners: {ivory: 'host', charcoal: null}, styles: {ivory: 'standard', charcoal: 'standard'},
  boardTheme: 'morocco', moves: [], resigned: null, timedOut: null, clock: null, aiRunner: null, aiLeaseAt: null});
const listing = {code: 'UABCDEF', shape: 'square', size: 5, players: 2};
const publish = (uid = 'host', owner = uid, data = listing) => setWithServerTime(ref(uid, 'openTables', owner), data, 'seenAt');
before(async () => { environment = await initializeHexEmulator({projectId: 'demo-stones-hex',
  firestore: {rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8')}}); });
beforeEach(async () => environment.clearFirestore());
after(async () => environment?.cleanup());

test('profile rename is owner-only, public by UID, bounded and independent of ratings', async () => {
  const own = ref('alice', 'playerProfiles', 'alice');
  await assertSucceeds(setWithServerTime(own, {name: 'Road builder'}, 'updatedAt'));
  assert.equal((await getDoc(ref(null, 'playerProfiles', 'alice'))).data().name, 'Road builder');
  await assertFails(setWithServerTime(ref('bob', 'playerProfiles', 'alice'), {name: 'Imposter'}, 'updatedAt'));
  for (const data of [{name: ''}, {name: '   '}, {name: 'x'.repeat(41)}, {name: 'one\ntwo'}, {name: 'one\u0000two'}, {name: 'Player', email: 'private@example.com'}, {name: 'Player', rating: 9999}]) {
    await assertFails(setWithServerTime(own, data, 'updatedAt'));
  }
  await assertFails(queryDocs('alice', 'playerProfiles', 25));
});

test('only an explicit host listing exposes a waiting room; private matches stay unlistable', async () => {
  await assertSucceeds(setDoc(ref('host', 'matches', 'UABCDEF'), room()));
  assert.equal((await queryDocs('guest', 'openTables', 25)).filter(row => row.document).length, 0);
  await assertFails(publish('outsider', 'host'));
  await assertFails(publish('outsider', 'outsider'));
  await assertSucceeds(publish());
  await assertSucceeds(queryDocs('guest', 'openTables', 25));
  await assertFails(queryDocs(null, 'openTables', 25));
  await assertFails(queryDocs('guest', 'openTables', 26));
  await assertFails(queryDocs('guest', 'openTables', null));
  await assertFails(queryDocs('guest', 'matches', 25));
  await assertFails(publish('host', 'host', {...listing, size: 8}));
  await assertFails(publish('host', 'host', {...listing, email: 'private'}));
  await assertFails(deleteDoc(ref('outsider', 'openTables', 'host')));
  await assertSucceeds(deleteDoc(ref('host', 'openTables', 'host')));
});

test('full and ended tables cannot refresh; simultaneous guests claim just one seat', async () => {
  await setDoc(ref('host', 'matches', 'UABCDEF'), room());
  await publish();
  const claim = uid => runTransaction(uid, async tx => {
    const target = ref(uid, 'matches', 'UABCDEF');
    const data = (await tx.get(target)).data();
    if (data.owners.charcoal !== null && data.owners.charcoal !== uid) throw new Error('Full');
    tx.update(target, {'owners.charcoal': uid});
  });
  const outcomes = await Promise.allSettled([claim('guest-a'), claim('guest-b')]);
  assert.equal(outcomes.filter(result => result.status === 'fulfilled').length, 1);
  await assertFails(publish());
  await deleteDoc(ref('host', 'openTables', 'host'));
});

test('client-authored timestamps cannot keep a listing alive', async () => {
  await setDoc(ref('host', 'matches', 'UABCDEF'), room());
  await assertFails(setDoc(ref('host', 'openTables', 'host'), {...listing, seenAt: new Date(Date.now() + 86400000)}));
  await publish();
  await assertFails(updateDoc(ref('host', 'openTables', 'host'), {seenAt: new Date(0)}));
});

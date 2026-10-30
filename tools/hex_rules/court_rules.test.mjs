import {readFile} from 'node:fs/promises';
import {before, after, beforeEach, test} from 'node:test';
import {initializeHexEmulator, assertFails, assertSucceeds, doc, setDoc, updateDoc, getDoc} from './emulator_rest.mjs';
import assert from 'node:assert/strict';
let environment;
const ids = ['ivory', 'charcoal', 'copper', 'jade'];
const ref = uid => doc(environment.authenticatedContext(uid).firestore(), 'matches', 'UABCDEF');
const move = (seat, i = 0) => ({seat, x: i, y: 0, type: 'flat', direction: null, drops: []});
const base = (shape = 'square', count = 2) => ({
  version: 1, code: 'UABCDEF', host: 'host',
  config: {version: 1, shape, size: shape === 'square' ? 5 : 2, court: true,
    seats: ids.slice(0, count).map((id, i) => ({id, control: i === 0 ? 'localHuman' : 'onlineHuman', level: 'easy'})),
    starter: 'ivory', profile: shape === 'square' && count === 2 ? 'standardTak' : 'sharedRoads'},
  owners: Object.fromEntries(ids.slice(0, count).map((id, i) => [id, i === 0 ? 'host' : null])),
  styles: Object.fromEntries(ids.slice(0, count).map(id => [id, 'standard'])),
  boardTheme: 'morocco', moves: [], resigned: null, aiRunner: null, aiLeaseAt: null,
  clock: null, timedOut: null, revision: 0,
});
before(async () => {
  environment = await initializeHexEmulator({projectId: 'demo-stones-hex',
    firestore: {host: '127.0.0.1', port: 8088,
      rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8')}});
});
beforeEach(async () => environment.clearFirestore());
after(async () => environment?.cleanup());
async function opened(shape = 'square', count = 2) {
  await assertSucceeds(setDoc(ref('host'), base(shape, count)));
  for (let i = 1; i < count; i++) await assertSucceeds(updateDoc(ref(`guest-${i}`), {[`owners.${ids[i]}`]: `guest-${i}`}));
  for (let i = 0; i < count; i++) {
    const previous = (await getDoc(ref('host'))).data();
    await assertSucceeds(updateDoc(ref(i === 0 ? 'host' : `guest-${i}`), {
      moves: [...previous.moves, move(ids[i], shape === 'square' ? i : i % 2)], revision: previous.revision + 1,
    }));
  }
  return (await getDoc(ref('host'))).data();
}
function decision(data, uid = 'host', target = 0) {
  return {requestedBy: uid, baseRevision: data.revision,
    retained: data.moves.slice(0, target), removed: data.moves.slice(target), approvals: [uid]};
}
for (const shape of ['square', 'hex']) for (const count of [2, 3, 4]) {
  test(`${shape} ${count}: all human votes are required and moves freeze`, async () => {
    const data = await opened(shape, count);
    const p = decision(data);
    let revision = data.revision + 1;
    await assertSucceeds(updateDoc(ref('host'), {takeback: p, revision}));
    await assertFails(updateDoc(ref('host'), {moves: [...data.moves, move('ivory')], revision: revision + 1}));
    await assertFails(updateDoc(ref('host'), {resigned: 'ivory', revision: revision + 1}));
    await assertFails(updateDoc(ref('host'), {takeback: null, moves: [], revision: revision + 1}));
    await assertFails(updateDoc(ref('stranger'), {takeback: null, moves: [], revision: revision + 1}));
    for (let i = 1; i < count; i++) {
      const approvals = [...p.approvals, `guest-${i}`];
      if (i < count - 1) {
        await assertFails(updateDoc(ref(`guest-${i}`), {takeback: null, moves: [], revision: revision + 1}));
        await assertSucceeds(updateDoc(ref(`guest-${i}`), {takeback: {...p, approvals}, revision: ++revision}));
        p.approvals = approvals;
      } else {
        await assertSucceeds(updateDoc(ref(`guest-${i}`), {takeback: null, moves: [], resigned: null,
          timedOut: null, finishedAt: null, revision: ++revision}));
      }
    }
    const rewound = (await getDoc(ref('host'))).data();
    assert.deepEqual(rewound.moves, []);
    assert.equal(rewound.takeback, null);
    await assertFails(updateDoc(ref('host'), {moves: [move('ivory')], revision: data.revision + 1}));
    await assertSucceeds(updateDoc(ref('host'), {moves: [move('ivory')], revision: revision + 1}));
  });
}
test('requests cannot forge votes, edit history or target an earlier human decision', async () => {
  const data = await opened('square', 2);
  const next = {...data, moves: [...data.moves, move('ivory', 2)], revision: data.revision + 1};
  await assertSucceeds(updateDoc(ref('host'), {moves: next.moves, revision: next.revision}));
  const p = decision(next, 'host', 2);
  for (const forged of [
    {...p, approvals: ['host', 'guest-1']},
    {...p, baseRevision: 0},
    {...p, retained: [move('ivory', 4), next.moves[1]]},
    decision(next),
    decision(next, 'host', 1),
  ]) await assertFails(updateDoc(ref('host'), {takeback: forged, revision: next.revision + 1}));
  await assertFails(updateDoc(ref('stranger'), {takeback: p, revision: next.revision + 1}));
  await assertSucceeds(updateDoc(ref('host'), {takeback: p, revision: next.revision + 1}));
  await assertFails(updateDoc(ref('guest-1'), {takeback: {...p, retained: []}, revision: next.revision + 2}));
  await assertSucceeds(updateDoc(ref('guest-1'), {takeback: null, revision: next.revision + 2}));
  assert.deepEqual((await getDoc(ref('host'))).data().moves, next.moves);
});
test('finished Court can rewind by agreement; ordinary games cannot request or rewrite', async () => {
  const data = await opened();
  await assertSucceeds(updateDoc(ref('guest-1'), {resigned: 'charcoal', revision: data.revision + 1}));
  const ended = (await getDoc(ref('host'))).data();
  await assertSucceeds(updateDoc(ref('host'), {takeback: decision(ended), revision: ended.revision + 1}));
  await assertSucceeds(updateDoc(ref('guest-1'), {takeback: null, moves: [], resigned: null,
    timedOut: null, finishedAt: null, revision: ended.revision + 2}));
  await environment.clearFirestore();
  const plain = base(); delete plain.config.court; delete plain.revision;
  await assertSucceeds(setDoc(ref('host'), plain));
  await assertSucceeds(updateDoc(ref('guest-1'), {'owners.charcoal': 'guest-1'}));
  await assertSucceeds(updateDoc(ref('host'), {moves: [move('ivory')]}));
  await assertFails(updateDoc(ref('host'), {moves: [], revision: 1}));
  await assertFails(updateDoc(ref('host'), {takeback: decision({...plain, moves: [move('ivory')], revision: 0}), revision: 1}));
});
test('timed Court and pre-approved creation are denied', async () => {
  const timed = base(); timed.config.clockSeconds = 60;
  await assertFails(setDoc(ref('host'), timed));
  const forged = base(); forged.takeback = {requestedBy: 'host'};
  await assertFails(setDoc(ref('host'), forged));
});

test('a sole online human can rewind while the observer cannot vote', async () => {
  const data = base();
  data.config.seats[0].control = 'ai'; data.owners.ivory = null;
  data.config.starter = 'charcoal';
  await assertSucceeds(setDoc(ref('host'), data));
  await assertSucceeds(updateDoc(ref('guest-1'), {'owners.charcoal': 'guest-1'}));
  await assertSucceeds(updateDoc(ref('guest-1'), {moves: [move('charcoal')], revision: 1}));
  const played = (await getDoc(ref('guest-1'))).data();
  await assertSucceeds(updateDoc(ref('guest-1'), {takeback: decision(played, 'guest-1'), revision: 2}));
  await assertFails(updateDoc(ref('host'), {takeback: null, moves: [], revision: 3}));
  await assertSucceeds(updateDoc(ref('guest-1'), {takeback: null, moves: [], revision: 3}));
});

test('shared local seats cast one account vote and only the latest decision can be undone', async () => {
  const data = base('hex', 4);
  data.config.seats[1].control = 'localHuman'; data.owners.charcoal = 'host';
  await assertSucceeds(setDoc(ref('host'), data));
  for (const i of [2, 3]) await assertSucceeds(updateDoc(ref(`guest-${i}`), {[`owners.${ids[i]}`]: `guest-${i}`}));
  let moves = [];
  for (let i = 0; i < 4; i++) {
    moves = [...moves, move(ids[i])];
    await assertSucceeds(updateDoc(ref(i < 2 ? 'host' : `guest-${i}`), {moves, revision: i + 1}));
  }
  const played = (await getDoc(ref('host'))).data();
  await assertFails(updateDoc(ref('host'), {takeback: decision(played), revision: 5}));
  const p = decision(played, 'host', 1);
  await assertSucceeds(updateDoc(ref('host'), {takeback: p, revision: 5}));
  await assertSucceeds(updateDoc(ref('guest-2'), {takeback: {...p, approvals: ['host', 'guest-2']}, revision: 6}));
  await assertSucceeds(updateDoc(ref('guest-3'), {takeback: null, moves: moves.slice(0, 1), revision: 7}));
});

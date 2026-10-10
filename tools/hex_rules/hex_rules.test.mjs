import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { initializeHexEmulator, assertFails, assertSucceeds,
  doc, setDoc, updateDoc, getDoc, collection, getDocs, runTransaction } from './emulator_rest.mjs';

let environment;
const code = 'HABCDEF';
const base = () => ({version: 2, code, host: 'host', radius: 2, starter: 0, ply: 0,
  kinds: {'0': 'localHuman', '1': 'remoteHuman', '2': 'ai'},
  owners: {'0': 'host', '1': null, '2': null}, moves: {}});
const ref = (uid, room = code) => doc(environment.authenticatedContext(uid).firestore(), 'hexGames', room);
const placement = (seat, q = 0, r = 0) => ({seat, q, r, type: 0, direction: -1, drops: []});
const append = (uid, ply, move) => updateDoc(ref(uid), {[`moves.${ply}`]: move, ply: ply + 1});

before(async () => {
  environment = await initializeHexEmulator({projectId: 'demo-stones-hex',
    firestore: {host: '127.0.0.1', port: 8088,
      rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8')}});
});
beforeEach(async () => environment.clearFirestore());
after(async () => environment?.cleanup());

async function ready() {
  await setDoc(ref('host'), base());
  await updateDoc(ref('guest'), {'owners.1': 'guest'});
}

test('authenticated creator reserves exactly three seats; unauthenticated access denied', async () => {
  await assertSucceeds(setDoc(ref('host'), base()));
  await assertFails(getDoc(doc(environment.unauthenticatedContext().firestore(), 'hexGames', code)));
  await assertFails(getDocs(collection(environment.authenticatedContext('guest').firestore(), 'hexGames')));
});

test('unsupported versions, bad radius, forged owner and extra seats rejected', async () => {
  for (const data of [ {...base(), version: 3}, {...base(), radius: 5}, {...base(), host: 'intruder'},
    {...base(), owners: {'0': 'host', '1': null, '2': null, '3': 'host'}},
    {...base(), owners: {'0': 'host', '1': 'forged', '2': null}} ]) {
    await assertFails(setDoc(ref('host'), data));
  }
});

test('both road-rule versions are accepted but cannot change after creation', async () => {
  await assertSucceeds(setDoc(ref('host'), {...base(), version: 1}));
  await assertFails(updateDoc(ref('host'), {version: 2}));
  await assertSucceeds(updateDoc(ref('guest'), {'owners.1': 'guest'}));
  await assertSucceeds(append('host', 0, placement(0)));
  await assertFails(updateDoc(ref('host'), {version: 2, ply: 2, 'moves.1': placement(1,1,0)}));
});

test('room does not play until every remote human joins', async () => {
  await setDoc(ref('host'), base());
  await assertFails(append('host', 0, placement(0)));
  await assertSucceeds(updateDoc(ref('guest'), {'owners.1': 'guest'}));
  await assertSucceeds(append('host', 0, placement(0)));
});

test('three remote humans join independently and cannot overwrite seats', async () => {
  const room = {...base(), kinds: {'0': 'localHuman', '1': 'remoteHuman', '2': 'remoteHuman'}};
  await setDoc(ref('host'), room);
  await assertSucceeds(updateDoc(ref('guest'), {'owners.1': 'guest'}));
  await assertFails(updateDoc(ref('guest'), {'owners.2': 'guest'}));
  await assertFails(updateDoc(ref('third'), {'owners.1': 'third'}));
  await assertSucceeds(updateDoc(ref('third'), {'owners.2': 'third'}));
  await assertSucceeds(append('host', 0, placement(0)));
  await assertSucceeds(append('guest', 1, placement(1, 1, 0)));
  await assertSucceeds(append('third', 2, placement(2, 0, 1)));
});

test('two humans and AI have distinct turn authority; only host drives AI', async () => {
  await ready();
  await assertFails(append('guest', 0, placement(0)));
  await assertSucceeds(append('host', 0, placement(0)));
  await assertFails(append('host', 1, placement(1)));
  await assertSucceeds(append('guest', 1, placement(1, 1, 0)));
  await assertFails(append('guest', 2, placement(2)));
  await assertFails(append('stranger', 2, placement(2)));
  await assertSucceeds(append('host', 2, placement(2, 0, 1)));
});

test('multi-human host controls only the seats assigned to that device', async () => {
  const room = {...base(), kinds: {'0': 'localHuman', '1': 'localHuman', '2': 'remoteHuman'},
    owners: {'0': 'host', '1': 'host', '2': null}};
  await setDoc(ref('host'), room);
  await updateDoc(ref('third'), {'owners.2': 'third'});
  await assertSucceeds(append('host', 0, placement(0)));
  await assertSucceeds(append('host', 1, placement(1, 1, 0)));
  await assertFails(append('host', 2, placement(2)));
  await assertSucceeds(append('third', 2, placement(2, 0, 1)));
});

test('logs cannot be rewritten, skipped, truncated or appended twice', async () => {
  await ready();
  await append('host', 0, placement(0));
  await assertFails(updateDoc(ref('guest'), {'moves.0': placement(0, 2, 0), 'moves.1': placement(1), ply: 2}));
  await assertFails(updateDoc(ref('guest'), {'moves.2': placement(1), ply: 2}));
  await assertFails(updateDoc(ref('guest'), {moves: {}, ply: 0}));
  await assertFails(append('host', 0, placement(0)));
});

test('invalid move shapes and mutable rules/roles rejected', async () => {
  await ready();
  for (const move of [placement(2), placement(0, 3, 0),
    {...placement(0), direction: 1}, {...placement(0), type: -1, direction: 0, drops: [0]},
    {...placement(0), type: -1, direction: 6, drops: [1]}]) {
    await assertFails(append('host', 0, move));
  }
  await assertFails(updateDoc(ref('host'), {radius: 3}));
  await assertFails(updateDoc(ref('host'), {'kinds.1': 'ai', 'owners.1': null}));
});

test('transactional racing joiners fill different available seats', async () => {
  await setDoc(ref('host'), {...base(), kinds: {'0': 'localHuman', '1': 'remoteHuman', '2': 'remoteHuman'}});
  const join = uid => runTransaction(environment.authenticatedContext(uid).firestore(), async transaction => {
    const snapshot = await transaction.get(ref(uid));
    const owners = snapshot.data().owners;
    const seat = ['1', '2'].find(key => owners[key] == null);
    if (!seat) throw new Error('full');
    transaction.update(ref(uid), {[`owners.${seat}`]: uid});
  });
  await Promise.all([join('guest'), join('third')]);
  const owners = (await getDoc(ref('host'))).data().owners;
  if (new Set(Object.values(owners)).size !== 3) throw new Error('Seat collision');
});

test('normal square room creation/join is unaffected', async () => {
  const db = environment.authenticatedContext('host').firestore();
  const square = doc(db, 'games', 'ABCDEF');
  await assertSucceeds(setDoc(square, {roomCode: 'ABCDEF', white: {id: 'host', displayName: 'Host'},
    black: null, boardSize: 5, moves: [], currentTurn: 'white', status: 'waiting', winner: null}));
  await assertSucceeds(updateDoc(doc(environment.authenticatedContext('guest').firestore(), 'games', 'ABCDEF'),
    {black: {id: 'guest', displayName: 'Guest'}, status: 'playing'}));
});

test('Hex shares seat cosmetics but joiners cannot replace opponent or bot styles', async () => {
  await setDoc(ref('host'), {...base(), pieceStyles: {'0': 'morocco', '1': 'standard', '2': 'kyoto'}});
  await assertFails(updateDoc(ref('guest'), {'owners.1': 'guest', 'pieceStyles.0': 'marble'}));
  await assertFails(updateDoc(ref('guest'), {'owners.1': 'guest', 'pieceStyles.2': 'stone'}));
  await assertFails(updateDoc(ref('guest'), {'owners.1': 'guest', 'pieceStyles.1': 'unknown'}));
  await assertSucceeds(updateDoc(ref('guest'), {'owners.1': 'guest', 'pieceStyles.1': 'polishedMarble'}));
  await assertFails(updateDoc(ref('guest'), {'pieceStyles.1': 'stone'}));
  await assertFails(updateDoc(ref('host'), {'moves.0': placement(0), ply: 1, 'pieceStyles.1': 'stone'}));
  await assertSucceeds(append('host', 0, placement(0)));
});

test('legacy Hex rooms accept a themed join with untouched default opponent styles', async () => {
  await setDoc(ref('host'), base());
  await assertFails(updateDoc(ref('guest'), {'owners.1': 'guest',
    pieceStyles: {'0': 'morocco', '1': 'kyoto', '2': 'standard'}}));
  await assertSucceeds(updateDoc(ref('guest'), {'owners.1': 'guest',
    pieceStyles: {'0': 'standard', '1': 'kyoto', '2': 'standard'}}));
  await assertSucceeds(append('host', 0, placement(0)));
});

test('square players can bring known styles; malformed styles are rejected', async () => {
  const square = doc(environment.authenticatedContext('host').firestore(), 'games', 'ABCDEF');
  const data = {roomCode: 'ABCDEF', white: {id: 'host', displayName: 'Host', pieceStyle: 'morocco'},
    black: null, boardSize: 5, moves: [], currentTurn: 'white', status: 'waiting', winner: null};
  await assertFails(setDoc(square, {...data, white: {...data.white, pieceStyle: 'unknown'}}));
  await assertSucceeds(setDoc(square, data));
  const guest = doc(environment.authenticatedContext('guest').firestore(), 'games', 'ABCDEF');
  await assertFails(updateDoc(guest, {black: {id: 'guest', displayName: 'Guest', pieceStyle: 4}, status: 'playing'}));
  await assertSucceeds(updateDoc(guest, {black: {id: 'guest', displayName: 'Guest', pieceStyle: 'kyoto'}, status: 'playing'}));
});

test('Hex host board survives joins and cannot be replaced by a guest or move', async () => {
  await assertFails(setDoc(ref('host'), {...base(), boardTheme: 'unknown'}));
  await setDoc(ref('host'), {...base(), boardTheme: 'morocco'});
  await assertFails(updateDoc(ref('guest'), {'owners.1': 'guest', boardTheme: 'kyoto'}));
  await assertSucceeds(updateDoc(ref('guest'), {'owners.1': 'guest'}));
  await assertFails(updateDoc(ref('host'), {'moves.0': placement(0), ply: 1, boardTheme: 'marble'}));
  await assertSucceeds(append('host', 0, placement(0)));
});

test('square host can choose either color and guest cannot replace the board', async () => {
  const square = doc(environment.authenticatedContext('host').firestore(), 'games', 'ABCDEF');
  await assertSucceeds(setDoc(square, {roomCode: 'ABCDEF', creatorColor: 'black', boardTheme: 'kyoto',
    white: null, black: {id: 'host', displayName: 'Host', pieceStyle: 'morocco'},
    boardSize: 5, moves: [], currentTurn: 'white', status: 'waiting', winner: null}));
  const guest = doc(environment.authenticatedContext('guest').firestore(), 'games', 'ABCDEF');
  await assertFails(updateDoc(guest, {white: {id: 'guest', displayName: 'Guest'}, status: 'playing', boardTheme: 'marble'}));
  await assertSucceeds(updateDoc(guest, {white: {id: 'guest', displayName: 'Guest'}, status: 'playing'}));
  await assertFails(updateDoc(guest, {moves: [{notation: 'a1', player: 'white'}], currentTurn: 'black', boardTheme: 'marble'}));
});

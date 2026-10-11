import {readFile} from 'node:fs/promises';
import {before, after, beforeEach, test} from 'node:test';
import {initializeHexEmulator, assertFails, assertSucceeds,
  doc, setDoc, updateDoc, getDoc, collection, getDocs, updateWithServerTime, runTransaction} from './emulator_rest.mjs';
import assert from 'node:assert/strict';

let environment;
const ids = ['ivory', 'charcoal', 'copper', 'jade'];
const ref = (uid, code = 'UABCDEF') => doc(environment.authenticatedContext(uid).firestore(), 'matches', code);
const base = (shape = 'square', controls = ['localHuman', 'onlineHuman'], starter = 'ivory') => ({
  version: 1, code: 'UABCDEF', host: 'host',
  config: {version: 1, shape, size: shape === 'square' ? 5 : 2,
    seats: controls.map((control, i) => ({id: ids[i], control, level: 'easy'})),
    starter, profile: shape === 'square' && controls.length === 2 ? 'standardTak' : 'sharedRoads'},
  owners: Object.fromEntries(controls.map((control, i) => [ids[i], control === 'localHuman' ? 'host' : null])),
  styles: Object.fromEntries(controls.map((_, i) => [ids[i], 'standard'])),
  boardTheme: 'morocco', moves: [], resigned: null, aiRunner: null, aiLeaseAt: null, clock: null, timedOut: null,
});
const placement = (seat, x = 0, y = 0) => ({seat, x, y, type: 'flat', direction: null, drops: []});
before(async () => {
  environment = await initializeHexEmulator({projectId: 'demo-stones-hex',
    firestore: {host: '127.0.0.1', port: 8088,
      rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8')}});
});
beforeEach(async () => environment.clearFirestore());
after(async () => environment?.cleanup());

const timed = (shape, count, seconds) => {
  const data = base(shape, ['localHuman', ...Array(count - 1).fill('onlineHuman')]);
  data.config.clockSeconds = seconds;
  data.clock = {
    bank: Object.fromEntries(ids.slice(0, count).map(id => [id, seconds * 1000])),
    started: Object.fromEntries(ids.slice(0, count).map(id => [id, null])),
    stopped: Object.fromEntries(ids.slice(0, count).map(id => [id, null])),
  };
  return data;
};
const timedMove = async (uid, move) => {
  const before = (await getDoc(ref(uid))).data();
  const n = before.config.seats.length;
  const index = (ids.indexOf(before.config.starter) + before.moves.length) % n;
  const current = before.config.seats[index].id;
  const next = before.config.seats[(index + 1) % n].id;
  const clock = structuredClone(before.clock);
  if (clock.started[next] !== null) clock.bank[next] -= clock.stopped[next] - clock.started[next];
  clock.stopped[next] = null;
  return updateWithServerTime(ref(uid), {moves: [...before.moves, move], clock},
      [`clock.stopped.${current}`, `clock.started.${next}`]);
};

test('timed rooms on both shapes debit server-acknowledged runs for every seat count', async () => {
  for (const shape of ['square', 'hex']) {
    for (const count of [2, 3, 4]) {
      await environment.clearFirestore();
      await assertSucceeds(setDoc(ref('host'), timed(shape, count, 60)));
      for (let i = 1; i < count; i++) await assertSucceeds(updateDoc(ref(`guest-${i}`), {[`owners.${ids[i]}`]: `guest-${i}`}));
      for (let ply = 0; ply < count * 2; ply++) {
        const seat = ids[ply % count];
        await assertSucceeds(timedMove(ply % count === 0 ? 'host' : `guest-${ply % count}`, placement(seat, ply % 3, Math.floor(ply / 3) - (shape === 'hex' ? 1 : 0))));
      }
      await assertFails(updateDoc(ref('host'), {'clock.bank.ivory': 60000}));
      await assertFails(updateDoc(ref('host'), {'clock.started.ivory': new Date()}));
    }
  }
});

test('clock expiry needs a real server deadline and participant; late moves cannot win the race', async () => {
  await assertSucceeds(setDoc(ref('host'), timed('square', 2, 1)));
  await assertSucceeds(updateDoc(ref('guest'), {'owners.charcoal': 'guest'}));
  await assertSucceeds(timedMove('host', placement('ivory')));
  await assertFails(updateDoc(ref('host'), {timedOut: 'charcoal'}));
  await new Promise(resolve => setTimeout(resolve, 1100));
  await assertFails(timedMove('guest', placement('charcoal', 1, 0)));
  await assertFails(updateDoc(ref('stranger'), {timedOut: 'charcoal'}));
  await assertSucceeds(updateDoc(ref('host'), {timedOut: 'charcoal'}));
  await assertFails(updateDoc(ref('guest'), {resigned: 'charcoal'}));
});

test('AI runner leases are exclusive, server-timed, renewable and recoverable by a guest', async () => {
  const data = base('hex', ['ai', 'onlineHuman', 'localHuman']);
  await assertSucceeds(setDoc(ref('host'), data));
  await assertSucceeds(updateDoc(ref('guest'), {'owners.charcoal': 'guest'}));
  await assertFails(updateWithServerTime(ref('stranger'), {aiRunner: 'stranger'}, 'aiLeaseAt'));
  await assertFails(updateDoc(ref('host'), {aiRunner: 'host', aiLeaseAt: new Date(Date.now() + 600000)}));
  await assertSucceeds(updateWithServerTime(ref('host'), {aiRunner: 'host'}, 'aiLeaseAt'));
  await assertFails(updateWithServerTime(ref('guest'), {aiRunner: 'guest'}, 'aiLeaseAt'));
  await assertFails(updateDoc(ref('guest'), {moves: [placement('ivory')]}));
  await assertSucceeds(updateWithServerTime(ref('host'), {aiRunner: 'host'}, 'aiLeaseAt'));
  await new Promise(resolve => setTimeout(resolve, 31000));
  await assertFails(updateDoc(ref('host'), {moves: [placement('ivory')]}));
  await assertSucceeds(updateWithServerTime(ref('guest'), {aiRunner: 'guest'}, 'aiLeaseAt'));
  await assertFails(updateDoc(ref('host'), {moves: [placement('ivory')]}));
  await assertSucceeds(updateDoc(ref('guest'), {moves: [placement('ivory')]}));
});

test('all 178 online seat combinations create, fill independently and authorize the whole exchange', async () => {
  let index = 0;
  for (const shape of ['square', 'hex']) {
    for (let count = 2; count <= 4; count++) {
      for (let pattern = 0; pattern < 3 ** count; pattern++) {
        const controls = Array.from({length: count}, (_, i) => ['localHuman', 'onlineHuman', 'ai'][Math.floor(pattern / 3 ** i) % 3]);
        if (!controls.includes('onlineHuman')) continue;
        const data = base(shape, controls, ids[count - 1]);
        const roomCode = `UAAAA${String.fromCharCode(65 + Math.floor(index / 26))}${String.fromCharCode(65 + index % 26)}`;
        data.code = roomCode;
        index++;
        await assertSucceeds(setDoc(ref('host', roomCode), data));
        for (let i = 0; i < count; i++) {
          if (controls[i] !== 'onlineHuman') continue;
          const uid = `guest-${i}`;
          await assertSucceeds(updateDoc(ref(uid, roomCode), {[`owners.${ids[i]}`]: uid, [`styles.${ids[i]}`]: 'kyoto'}));
          data.owners[ids[i]] = uid;
          data.styles[ids[i]] = 'kyoto';
        }
        if (controls.includes('ai')) {
          await assertSucceeds(updateWithServerTime(ref('host', roomCode), {aiRunner: 'host'}, 'aiLeaseAt'));
        }
        for (let ply = 0; ply < count; ply++) {
          const seat = ids[(count - 1 + ply) % count];
          const owner = data.owners[seat] ?? 'host';
          data.moves.push(placement(seat, ply % 2, Math.floor(ply / 2)));
          await assertFails(updateDoc(ref('stranger', roomCode), {moves: data.moves}));
          await assertSucceeds(updateDoc(ref(owner, roomCode), {moves: data.moves}));
        }
      }
    }
  }
  if (index !== 178) throw new Error(`Unexpected online case count ${index}`);
});

test('concurrent guests claim distinct seats and stale move commits cannot both append', async () => {
  await setDoc(ref('host'), base('hex', ['localHuman', 'onlineHuman', 'onlineHuman', 'onlineHuman']));
  await Promise.all(['guest-a', 'guest-b', 'guest-c'].map(uid =>
    runTransaction(uid, async tx => {
      const snapshot = await tx.get(ref(uid));
      const room = snapshot.data();
      if (Object.values(room.owners).includes(uid)) return;
      const seat = room.config.seats.find(s => s.control === 'onlineHuman' && room.owners[s.id] === null);
      assert.ok(seat, 'A guest lost its available seat');
      tx.update(ref(uid), {[`owners.${seat.id}`]: uid, [`styles.${seat.id}`]: 'morocco'});
    })));
  const joined = (await getDoc(ref('host'))).data();
  assert.deepEqual(new Set(Object.values(joined.owners)), new Set(['host', 'guest-a', 'guest-b', 'guest-c']));
  const attempts = await Promise.allSettled([0, 1].map(x =>
    runTransaction('host', async tx => {
      const snapshot = await tx.get(ref('host'));
      // These are competing confirmations of the same turn, not two moves.
      assert.equal(snapshot.data().moves.length, 0, 'The turn was already acknowledged');
      tx.update(ref('host'), {moves: [placement('ivory', x, 0)]});
    })));
  assert.equal(attempts.filter(result => result.status === 'fulfilled').length, 1);
  assert.equal((await getDoc(ref('host'))).data().moves.length, 1);
});

test('malformed creation and public room enumeration are denied', async () => {
  const data = base();
  const malformed = [
    {...data, host: 'stranger'}, {...data, version: 2}, {...data, moves: [placement('ivory')]},
    {...data, config: {...data.config, size: 9}},
    {...data, config: {...data.config, starter: 'jade'}},
    {...data, owners: {...data.owners, charcoal: 'forged'}},
    {...data, styles: {...data.styles, charcoal: 'unknown'}},
    {...data, boardTheme: 'unknown'},
    {...data, config: {...data.config, seats: [data.config.seats[0], data.config.seats[0]]}},
  ];
  for (const bad of malformed) await assertFails(setDoc(ref('host'), bad));
  await assertSucceeds(setDoc(ref('host'), data));
  await assertFails(getDoc(doc(environment.unauthenticatedContext().firestore(), 'matches', data.code)));
  await assertFails(getDocs(collection(environment.authenticatedContext('guest').firestore(), 'matches')));
});

test('joining cannot take two seats, alter host material or an occupied player theme', async () => {
  await setDoc(ref('host'), base('hex', ['localHuman', 'onlineHuman', 'onlineHuman', 'ai']));
  await assertFails(updateDoc(ref('host'), {'owners.charcoal': 'host'}));
  await assertFails(updateDoc(ref('guest'), {'owners.charcoal': 'guest', boardTheme: 'kyoto'}));
  await assertFails(updateDoc(ref('guest'), {'owners.charcoal': 'guest', 'styles.ivory': 'kyoto'}));
  await assertSucceeds(updateDoc(ref('guest'), {'owners.charcoal': 'guest', 'styles.charcoal': 'morocco'}));
  await assertFails(updateDoc(ref('guest'), {'owners.copper': 'guest'}));
  await assertFails(updateDoc(ref('third'), {'owners.charcoal': 'third'}));
  await assertSucceeds(updateDoc(ref('third'), {'owners.copper': 'third'}));
});

test('waiting, stale, rewritten, skipped and oversized moves are denied', async () => {
  await setDoc(ref('host'), base());
  await assertFails(updateDoc(ref('host'), {moves: [placement('ivory')]}));
  await updateDoc(ref('guest'), {'owners.charcoal': 'guest'});
  await assertFails(updateDoc(ref('guest'), {moves: [placement('ivory')]}));
  await assertFails(updateDoc(ref('host'), {moves: [{...placement('ivory'), type: 'standing'}]}));
  await assertSucceeds(updateDoc(ref('host'), {moves: [placement('ivory')]}));
  await assertFails(updateDoc(ref('guest'), {moves: [placement('ivory', 1), placement('charcoal', 1)]}));
  await assertFails(updateDoc(ref('guest'), {moves: [placement('ivory'), placement('charcoal', 1), placement('ivory', 2)]}));
  await assertSucceeds(updateDoc(ref('guest'), {moves: [placement('ivory'), placement('charcoal', 1)]}));
  const spread = {...placement('ivory'), type: null, direction: 'east', drops: [6]};
  const prefix = [placement('ivory'), placement('charcoal', 1)];
  await assertFails(updateDoc(ref('host'), {moves: [...prefix, spread]}));
  await assertFails(updateDoc(ref('host'), {moves: [...prefix, {...spread, drops: [3, 3]}]}));
  await assertFails(updateDoc(ref('host'), {moves: [...prefix, {...spread, direction: 'northEast', drops: [1]}]}));
  await assertFails(updateDoc(ref('host'), {moves: [...prefix, {...spread, drops: [1, 0]}]}));
  await assertFails(updateDoc(ref('host'), {moves: [...prefix, placement('ivory', -1)]}));
  await assertFails(updateDoc(ref('host'), {moves: [...prefix, placement('ivory', 2)], host: 'guest'}));
});

test('only a player can resign their owned seat and further appends stop', async () => {
  await setDoc(ref('host'), base());
  await updateDoc(ref('guest'), {'owners.charcoal': 'guest'});
  await assertFails(updateDoc(ref('stranger'), {resigned: 'ivory'}));
  await assertFails(updateDoc(ref('host'), {resigned: 'charcoal'}));
  await assertSucceeds(updateDoc(ref('guest'), {resigned: 'charcoal'}));
  await assertFails(updateDoc(ref('host'), {moves: [placement('ivory')]}));
  await assertFails(updateDoc(ref('guest'), {resigned: null}));
});

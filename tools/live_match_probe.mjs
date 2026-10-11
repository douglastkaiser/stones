// Manual production smoke test, never part of CI. Creates four independent
// anonymous test identities and six new, finally resigned QA rooms. It never
// reads existing users' games, changes policy, or deletes production data.
// Tokens stay in memory and are not printed. Uses Firebase's documented Auth
// and Firestore REST APIs under ordinary client security rules.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {randomInt} from 'node:crypto';

const project = 'stones-9a6a0';
if (process.env.STONES_LIVE_TEST !== project) {
  throw new Error(`This creates isolated production QA rooms. Set STONES_LIVE_TEST=${project} to run deliberately.`);
}
const source = await readFile(new URL('../lib/firebase_options.dart', import.meta.url), 'utf8');
const key = source.match(/apiKey: '([^']+)'/)?.[1];
assert.ok(key && source.includes(`projectId: '${project}'`));
const root = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const ids = ['ivory', 'charcoal', 'copper', 'jade'];
class RequestFailure extends Error {
  constructor(status) { super(`Firebase request failed (${status})`); this.status = status; }
}
async function request(url, method, body, client) {
  const response = await fetch(url, {
    method,
    headers: {'Content-Type': 'application/json', ...(client ? {Authorization: `Bearer ${client.token}`} : {})},
    ...(body === undefined ? {} : {body: JSON.stringify(body)}),
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) throw new RequestFailure(response.status);
  return response.status === 204 ? {} : response.json();
}
function encode(value) {
  if (value instanceof Date) return {timestampValue: value.toISOString()};
  if (value === null) return {nullValue: null};
  if (typeof value === 'string') return {stringValue: value};
  if (typeof value === 'number') return {integerValue: String(value)};
  if (Array.isArray(value)) return {arrayValue: {values: value.map(encode)}};
  return {mapValue: {fields: Object.fromEntries(Object.entries(value).map(([k, v]) => [k, encode(v)]))}};
}
function decode(value) {
  if ('timestampValue' in value) return new Date(value.timestampValue);
  if ('nullValue' in value) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('arrayValue' in value) return (value.arrayValue.values ?? []).map(decode);
  return Object.fromEntries(Object.entries(value.mapValue.fields ?? {}).map(([k, v]) => [k, decode(v)]));
}
async function read(code, client) {
  const document = await request(`${root}/matches/${code}`, 'GET', undefined, client);
  return {data: decode({mapValue: {fields: document.fields}}), updateTime: document.updateTime};
}
async function commit(code, snapshot, data, client, timestamps = []) {
  const copy = structuredClone(data);
  for (const path of timestamps) {
    const parts = path.split('.');
    let cursor = copy;
    for (const part of parts.slice(0, -1)) cursor = cursor[part];
    delete cursor[parts.at(-1)];
  }
  return request(`${root}:commit`, 'POST', {writes: [{
    update: {name: `projects/${project}/databases/(default)/documents/matches/${code}`, fields: encode(copy).mapValue.fields},
    currentDocument: snapshot ? {updateTime: snapshot.updateTime} : {exists: false},
    ...(timestamps.length ? {updateTransforms: timestamps.map(fieldPath => ({fieldPath, setToServerValue: 'REQUEST_TIME'}))} : {}),
  }]}, client);
}
const denied = operation => assert.rejects(operation, error => error instanceof RequestFailure && [401, 403].includes(error.status));
const clients = [];
for (let index = 0; index < 4; index++) {
  const identity = await request(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${key}`, 'POST', {returnSecureToken: true});
  clients.push({uid: identity.localId, token: identity.idToken});
}
console.log('Four independent anonymous QA clients authenticated.');
const [host, guest, third, stranger] = clients;
const hexCells = [[-1, -1], [0, -1], [1, -1], [-2, 0], [-1, 0], [0, 0], [1, 0], [2, 0]];
for (const shape of ['square', 'hex']) {
  for (const count of [2, 3, 4]) {
    const code = 'U' + Array.from({length: 6}, () => String.fromCharCode(65 + randomInt(26))).join('');
    const controls = count === 2 ? ['localHuman', 'onlineHuman'] : count === 3
      ? ['localHuman', 'ai', 'onlineHuman'] : ['localHuman', 'onlineHuman', 'ai', 'onlineHuman'];
    const data = {version: 1, code, host: host.uid,
      config: {version: 1, shape, size: shape === 'square' ? 5 : 2,
        seats: ids.slice(0, count).map((id, i) => ({id, control: controls[i], level: 'easy'})),
        starter: 'ivory', profile: shape === 'square' && count === 2 ? 'standardTak' : 'sharedRoads', clockSeconds: 60},
      owners: Object.fromEntries(ids.slice(0, count).map((id, i) => [id, controls[i] === 'localHuman' ? host.uid : null])),
      styles: Object.fromEntries(ids.slice(0, count).map((id, i) => [id, controls[i] === 'onlineHuman' ? 'standard' : 'morocco'])),
      boardTheme: 'morocco', moves: [], resigned: null, aiRunner: null, aiLeaseAt: null, timedOut: null,
      clock: {bank: Object.fromEntries(ids.slice(0, count).map(id => [id, 60000])),
        started: Object.fromEntries(ids.slice(0, count).map(id => [id, null])),
        stopped: Object.fromEntries(ids.slice(0, count).map(id => [id, null]))}};
    await commit(code, null, data, host);
    const owners = new Map([[host.uid, host], [guest.uid, guest], [third.uid, third]]);
    let remote = 0;
    for (const seat of data.config.seats.filter(seat => seat.control === 'onlineHuman')) {
      const client = remote++ === 0 ? guest : third;
      const snapshot = await read(code, client);
      snapshot.data.owners[seat.id] = client.uid;
      snapshot.data.styles[seat.id] = client === guest ? 'kyoto' : 'polishedMarble';
      await commit(code, snapshot, snapshot.data, client);
    }
    if (controls.includes('ai')) {
      const snapshot = await read(code, host);
      snapshot.data.aiRunner = host.uid;
      await commit(code, snapshot, snapshot.data, host, ['aiLeaseAt']);
      const occupied = await read(code, stranger);
      occupied.data.aiRunner = stranger.uid;
      await denied(commit(code, occupied, occupied.data, stranger, ['aiLeaseAt']));
    }
    for (let ply = 0; ply < count * 2; ply++) {
      const snapshot = await read(code, host);
      const room = snapshot.data;
      const seat = room.config.seats[ply % count];
      const client = seat.control === 'ai' ? host : owners.get(room.owners[seat.id]);
      const next = ids[(ply + 1) % count];
      const [x, y] = shape === 'hex' ? hexCells[ply] : [ply % 5, Math.floor(ply / 5)];
      room.moves.push({seat: seat.id, x, y, type: 'flat', direction: null, drops: []});
      if (room.clock.started[next] !== null) room.clock.bank[next] -= room.clock.stopped[next] - room.clock.started[next];
      room.clock.stopped[next] = null;
      const timestamps = [`clock.stopped.${seat.id}`, `clock.started.${next}`];
      await denied(commit(code, snapshot, room, stranger, timestamps));
      await commit(code, snapshot, room, client, timestamps);
      await assert.rejects(commit(code, snapshot, room, client, timestamps), error => error instanceof RequestFailure);
      const recovered = (await read(code, guest)).data;
      assert.equal(recovered.moves.length, ply + 1);
      assert.equal(recovered.boardTheme, 'morocco');
      assert.equal(recovered.styles[data.config.seats.find(s => s.control === 'onlineHuman').id], 'kyoto');
    }
    const final = await read(code, host);
    final.data.resigned = 'ivory';
    await commit(code, final, final.data, host);
    assert.equal((await read(code, third)).data.resigned, 'ivory');
    console.log(`PASS ${shape} ${count} seats: themes, clocks, AI authority, stale-write rejection, cold reads, durable ending (${code}).`);
  }
}
console.log('Six isolated live QA rooms passed. No existing user data or policy was modified.');

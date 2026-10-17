const {test} = require('node:test');
const assert = require('node:assert/strict');
const R = require('./ratings.cjs');
const player = (id, rating = 1200, games = 0) => ({...R.fresh(id, id, 'pool'), rating, gamesPlayed: games});

test('equal duel win, draw, established K, upset and floor', () => {
  assert.deepEqual(R.updates([player('a'), player('b')], 'a', 0).map(p => p.rating), [1220,1180]);
  assert.deepEqual(R.updates([player('a'), player('b')], null, 0).map(p => p.rating), [1200,1200]);
  assert.deepEqual(R.updates([player('a',1200,30), player('b',1200,30)], 'a', 0).map(p => p.rating), [1210,1190]);
  assert(R.updates([player('a',800), player('b',1600)], 'a', 0)[0].rating > 830);
  assert(R.updates([player('a',100), player('b',100)], 'b', 0)[0].rating >= 100);
});
test('multiplayer uses pregame values, normalized influence, losing rivals tie', () => {
  for (const n of [3,4]) {
    const result = R.updates(Array.from({length:n}, (_,i) => player(`${i}`)), '0', 0);
    assert.equal(result[0].rating, 1220);
    assert.equal(result[1].rating, n === 3 ? 1190 : 1193);
    assert.equal(result[1].rating, result[2].rating);
    assert(result.every(p => p.gamesPlayed === 1));
    assert.equal(result.reduce((s,p) => s+p.wins, 0),1);
    assert(R.updates(Array.from({length:n}, (_,i) => player(`${i}`)), null, 0).every(p => p.draws === 1 && p.rating === 1200));
  }
});
test('invalid scores, duplicate identities, absent winner rejected', () => {
  assert.throws(() => R.updates([player('a'),player('a')], 'a', 0));
  assert.throws(() => R.updates([player('a'),player('b')], 'c', 0));
  assert.throws(() => R.updates([player('a',NaN),player('b')], 'b', 0));
  assert.throws(() => R.humanIds({config:{seats:[{id:'a'},{id:'b'}]},owners:{a:'same',b:'same'}}));
});
test('bots share neutral prior, require established human and never edit human', () => {
  const bot = R.fresh('bot','Bot','pool',true,'easy');
  assert.equal(bot.rating, R.fresh('expert','Expert','pool',true,'expert').rating);
  assert.throws(() => R.calibration(bot,player('human'),1,0,true));
  const human = player('human',1600,10);
  const before = structuredClone(human);
  const next = R.calibration(bot,human,1,0,true);
  assert.deepEqual(human,before);
  assert(next.rating > 1230);
  assert.equal(next.opponents,1);
  assert.equal(R.calibration(next,human,0,0,false).opponents,1);
});
test('stable evidence hash includes game and turn and handles absent proof', () => {
  assert.notEqual(R.evidenceId('a',0),R.evidenceId('a',1));
  assert.notEqual(R.evidenceId('a',0),R.evidenceId('b',0));
  assert.notEqual(R.hash(undefined),R.hash({seat:'a'}));
});
class FakeDB {
  data = new Map(); queue = Promise.resolve(); fail = false;
  doc(path) { return {path, collection: name => ({doc: id => this.doc(`${path}/${name}/${id}`)})}; }
  runTransaction(callback) {
    const job = this.queue.then(async () => {
      const writes = [];
      const result = await callback({getAll: async (...refs) => refs.map(ref => ({exists:this.data.has(ref.path),data:()=>structuredClone(this.data.get(ref.path))})),
        set:(ref,data) => writes.push([ref.path,structuredClone(data)])});
      if (this.fail) throw Error('Transient commit failure');
      for (const [key,data] of writes) this.data.set(key,data);
      return result;
    });
    this.queue = job.catch(()=>{}); return job;
  }
}
const room = code => ({code,owners:{ivory:'alice',charcoal:'bob'}});
const result = {pool:'square-5-2-standardTak-open',winner:'ivory'};
const identities = [{uid:'alice',name:'Alice'},{uid:'bob',name:'Bob'}];
test('duplicate deliveries and concurrent distinct games update exactly once', async () => {
  const db = new FakeDB();
  const responses = await Promise.all(Array.from({length:12},()=>R.recordHumanResult(db,room('UAAAAAA'),result,identities,1)));
  assert.equal(responses.filter(Boolean).length,1);
  await Promise.all(['UBBBBBB','UCCCCCC'].map(code=>R.recordHumanResult(db,room(code),result,identities,2)));
  assert.equal(db.data.get(`ratingPools/${result.pool}/players/alice`).gamesPlayed,3);
  assert.equal(db.data.get(`ratingPools/${result.pool}/players/bob`).losses,3);
  assert.equal([...db.data.keys()].filter(k=>k.startsWith('ratingReceipts/')).length,3);
  assert.equal([...db.data.keys()].filter(k=>k.includes('/history/')).length,6);
  for (const [path, entry] of db.data) {
    if (path.includes('/history/')) {
      assert.match(path.split('/').at(-1), /^[a-f0-9]{64}$/);
      assert(!('match' in entry));
    }
  }
});
test('failed commit changes neither rating nor history nor receipt; retry works', async () => {
  const db = new FakeDB(); db.fail = true;
  await assert.rejects(R.recordHumanResult(db,room('UAAAAAA'),result,identities,0));
  assert.equal(db.data.size,0);
  db.fail = false;
  assert(await R.recordHumanResult(db,room('UAAAAAA'),result,identities,1));
});
test('established standings added at ten games and include no email', async () => {
  const db = new FakeDB();
  for(let i=0;i<10;i++) await R.recordHumanResult(db,room(`U${i}`),result,identities,i);
  const standing = db.data.get(`ratingPools/${result.pool}/standings/alice`);
  assert.equal(standing.gamesPlayed,10);
  assert(!('email' in standing));
});

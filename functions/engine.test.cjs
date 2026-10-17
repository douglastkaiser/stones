const {test} = require('node:test');
const assert = require('node:assert/strict');
globalThis.self = globalThis;
require('./engine.js');
const config = (shape='square',n=2) => ({version:1,shape,size:shape==='square'?5:2,
  seats:['ivory','charcoal','copper','jade'].slice(0,n).map((id,i)=>({id,control:i?'onlineHuman':'localHuman',level:'easy'})),
  starter:'ivory',profile:shape==='square'&&n===2?'standardTak':'sharedRoads'});
const call = async data => JSON.parse(await globalThis.stonesEngine(JSON.stringify(data)));
const place = (seat,x,y,type='flat')=>({seat,x,y,type,direction:null,drops:[]});
test('compiled shared engine accepts every shape and seat count, rejects malformed turns',async()=>{
  for(const shape of ['square','hex'])for(const n of [2,3,4]) {
    const result = await call({config:config(shape,n),moves:[]});
    assert.equal(result.finished,false); assert.equal(result.current,'ivory');
    assert(result.pool.startsWith(`${shape}-`));
    assert((await call({config:config(shape,n),moves:[place('charcoal',0,0)]})).error);
    assert((await call({config:config(shape,n),moves:[place('ivory',90,90)]})).error);
  }
});
test('compiled rules resolve actual road, reject appended terminal moves and Court',async()=>{
  const moves=[place('ivory',4,4),place('charcoal',0,0)];
  for(let x=1;x<5;x++) {
    moves.push(place('ivory',x,0));
    if(x<4)moves.push(place('charcoal',x,3,'standing'));
  }
  const result=await call({config:config(),moves});
  assert.equal(result.winner,'ivory');assert.equal(result.reason,'road');
  assert((await call({config:config(),moves:[...moves,place('charcoal',4,3)]})).error);
  const court=config();court.seats[1].control='ai';court.court=true;
  assert((await call({config:court,moves:[]})).error);
});
test('server AI uses shared search and produces a legal move',async()=>{
  const cfg=config();cfg.seats[0].control='ai';cfg.seats[1].control='localHuman';
  const {move,error}=await call({action:'bot',config:cfg,moves:[]});
  assert(!error);assert.equal(move.seat,'ivory');
  assert(!(await call({config:cfg,moves:[move]})).error);
});

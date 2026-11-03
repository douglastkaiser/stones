import {test} from 'node:test';
import assert from 'node:assert/strict';
import {recipient,processJob} from './worker.mjs';
const room={moves:[{}],config:{starter:'ivory',seats:[{id:'ivory',control:'localHuman'},{id:'charcoal',control:'onlineHuman'}]},owners:{ivory:'alice',charcoal:'bob'}};
const job={format:'matches',code:'UABCDEF',ply:1,revision:0,state:'pending',createdAt:new Date().toISOString()};
test('recipient is derived from confirmed turn and membership',()=>{assert.equal(recipient(room,job),'bob');assert.equal(recipient({...room,moves:[]},job),null);assert.equal(recipient({...room,finishedAt:'now'},job),null);assert.equal(recipient({...room,takeback:{}},job),null);});
test('Court revisions and AI turns never use stale recipients',()=>{assert.equal(recipient({...room,revision:2},job),null);assert.equal(recipient({...room,config:{...room.config,seats:[room.config.seats[0],{id:'charcoal',control:'ai'}]}},job),null);});
function api(){let sends=0;return {get sends(){return sends;},patch:async(s,data)=>({...s,data}),get:async path=>path.startsWith('matches/')?{data:room}:path.includes('preferences')?{data:{enabled:true}}:{data:{muted:false}},devices:async()=>[{name:'devices/device',data:{enabled:true,token:'token',updatedAt:new Date().toISOString()}}],send:async()=>{sends++;return 'ok';},remove:async()=>{}};}
test('durable job can deliver without an open client',async()=>{const a=api();const result=await processJob(a,{name:'jobs/event',data:job});assert.equal(a.sends,1);assert.equal(result.data.state,'sent');});
test('muted or obsolete jobs do not send',async()=>{const a=api();a.get=async()=>({data:{...room,moves:[]}});const result=await processJob(a,{name:'jobs/event',data:job});assert.equal(a.sends,0);assert.equal(result.data.state,'obsolete');});
test('lease contention prevents duplicate concurrent sends',async()=>{const a=api();a.patch=async()=>{throw new Error('precondition');};await assert.rejects(processJob(a,{name:'jobs/event',data:job}));assert.equal(a.sends,0);});

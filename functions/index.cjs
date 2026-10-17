"use strict";
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');
const R = require('./ratings.cjs');
initializeApp();
const db = getFirestore();
globalThis.self = globalThis;
require('./engine.js');
const engine = async data => {
  const result = JSON.parse(await globalThis.stonesEngine(JSON.stringify(data)));
  if (result.error) throw new HttpsError('invalid-argument', result.error);
  return result;
};
const options = {region: 'us-central1', maxInstances: 3, memory: '512MiB', timeoutSeconds: 30};
async function account(uid) {
  const user = await getAuth().getUser(uid);
  if (!user.providerData.length || user.disabled) throw new HttpsError('permission-denied', 'Sign in to a permanent account.');
  return {uid, name: (user.displayName || 'Player').slice(0, 60)};
}
function roomInput(room) {
  return {config: room.config, moves: room.moves, resigned: room.resigned, timedOut: room.timedOut};
}
function playerRef(pool, id) { return db.doc(`ratingPools/${pool}/players/${id}`); }
function signed(request) {
  if (!request.auth || request.auth.token.firebase?.sign_in_provider === 'anonymous') {
    throw new HttpsError('unauthenticated', 'Sign in with Google to use account ratings.');
  }
  return request.auth.uid;
}
function sessionKey(uid, id) {
  if (typeof id !== 'string' || !id || id.length > 160) throw new HttpsError('invalid-argument', 'Invalid match identity');
  return R.hash([uid, id]);
}
// AI calibration is available for logged-in local duels as well as online duels.
// Every counted AI move is generated here with the shared gameplay engine.
exports.ratingBotMove = onCall(options, async request => {
  const uid = signed(request);
  const {id, config, moves} = request.data;
  if (!Array.isArray(moves) || moves.length > 4096 || !Array.isArray(config?.seats) ||
      config.seats.length !== 2 || config.seats.filter(s => s.control === 'ai').length !== 1 || config.court) {
    throw new HttpsError('invalid-argument', 'Calibration requires an unassisted duel');
  }
  if (config.seats.some(s => s.control === 'onlineHuman')) {
    const snapshot = await db.doc(`matches/${id}`).get();
    const room = snapshot.data();
    if (!room || !Object.values(room.owners).includes(uid) || R.hash(room.config) !== R.hash(config) || R.hash(room.moves) !== R.hash(moves)) {
      throw new HttpsError('permission-denied', 'Room changed or belongs to another player');
    }
  }
  const key = sessionKey(uid, id);
  const ref = db.doc(`calibrationSessions/${key}`);
  const quotaRef = db.doc(`ratingLimits/${R.hash([uid, new Date().toISOString().slice(0,10)])}`);
  const quota = (await quotaRef.get()).data();
  const current = await ref.get();
  const prefix = R.hash({config, moves});
  const existing = current.data();
  if (existing && existing.engineVersion !== R.ENGINE) throw new HttpsError('failed-precondition', 'AI revision changed; start a new game');
  if (existing?.evidence?.[moves.length]) {
    if (existing.evidence[moves.length].prefix !== prefix) throw new HttpsError('failed-precondition', 'History was changed');
    return {move: existing.evidence[moves.length].move};
  }
  if ((quota?.moves || 0) >= 400) throw new HttpsError('resource-exhausted', 'Daily calibration limit reached. Continue as practice.');
  for (const [ply, proof] of Object.entries(existing?.evidence || {})) {
    if (Number(ply) >= moves.length || R.hash(moves[Number(ply)]) !== R.hash(proof.move)) {
      throw new HttpsError('failed-precondition', 'Calibration history diverged');
    }
  }
  const result = await engine({action: 'bot', config, moves});
  await db.runTransaction(async tx => {
    const [previousDoc, quotaDoc] = await tx.getAll(ref, quotaRef);
    const previous = previousDoc.data();
    if (previous?.evidence?.[moves.length]) {
      if (previous.evidence[moves.length].prefix !== prefix) throw new HttpsError('aborted', 'History changed');
      result.move = previous.evidence[moves.length].move;
      return;
    }
    if ((quotaDoc.data()?.moves || 0) >= 400) throw new HttpsError('resource-exhausted', 'Daily calibration limit reached');
    tx.set(quotaRef, {moves: (quotaDoc.data()?.moves || 0) + 1});
    tx.set(ref, {uid, id, engineVersion: R.ENGINE, evidence: {...(previous?.evidence || {}), [moves.length]: {prefix, move: result.move}}});
  });
  return result;
});

exports.completeCalibration = onCall(options, async request => {
  const uid = signed(request);
  const {id, config, moves} = request.data;
  const key = sessionKey(uid, id);
  if (!Array.isArray(config?.seats) || config.seats.length !== 2 ||
      config.seats.filter(s => s.control === 'ai').length !== 1) throw new HttpsError('invalid-argument', 'Not a calibration duel');
  const result = await engine({config, moves});
  if (!result.finished) return {status: 'practice', reason: 'Only completed board results calibrate AI'};
  const humanSeat = config.seats.find(s => s.control !== 'ai');
  const botSeat = config.seats.find(s => s.control === 'ai');
  if (config.seats.some(s => s.control === 'onlineHuman')) {
    const room = (await db.doc(`matches/${id}`).get()).data();
    if (!room || room.owners[humanSeat.id] !== uid || R.hash(room.moves) !== R.hash(moves) || R.hash(room.config) !== R.hash(config)) {
      throw new HttpsError('permission-denied', 'Room ownership or history mismatch');
    }
  }
  const botId = `ai_${R.ENGINE}_${botSeat.level}`;
  const receipt = db.doc(`ratingReceipts/calibration-${key}`);
  const session = db.doc(`calibrationSessions/${key}`);
  const humanRef = playerRef(result.pool, uid);
  const botRef = playerRef(result.pool, botId);
  const distinctRef = botRef.collection('opponents').doc(uid);
  const dayRef = botRef.collection('samples').doc(R.hash([uid, new Date().toISOString().slice(0,10)]));
  return db.runTransaction(async tx => {
    const [done, evidence, humanDoc, botDoc, opponent, daily] = await tx.getAll(receipt, session, humanRef, botRef, distinctRef, dayRef);
    if (done.exists) return {status: 'recorded'};
    const proof = evidence.data();
    if (!proof || proof.uid !== uid || proof.engineVersion !== R.ENGINE) throw new HttpsError('failed-precondition', 'No server AI evidence');
    for (let ply = 0; ply < moves.length; ply++) {
      if (moves[ply].seat === botSeat.id && (R.hash(proof.evidence[ply]?.move) !== R.hash(moves[ply]) ||
          proof.evidence[ply]?.prefix !== R.hash({config, moves: moves.slice(0, ply)}))) {
        throw new HttpsError('failed-precondition', 'Unverified AI move');
      }
    }
    if (!humanDoc.exists || humanDoc.data().gamesPlayed < 10) return {status: 'practice', reason: 'AI calibration needs an established human rating in this ladder (10 competitive games)'};
    if (daily.exists) return {status: 'practice', reason: 'One calibration sample per opponent per day'};
    const human = humanDoc.data();
    const bot = botDoc.data() || R.fresh(botId, `${botSeat.level[0].toUpperCase()}${botSeat.level.slice(1)} AI`, result.pool, true, botSeat.level);
    const score = result.winner === null ? 0.5 : result.winner === botSeat.id ? 1 : 0;
    const updated = R.calibration(bot, human, score, Date.now(), !opponent.exists);
    tx.set(botRef, updated);
    tx.set(distinctRef, {firstSeen: Date.now()});
    tx.set(dayRef, {match: id});
    tx.set(botRef.collection('history').doc(key), {rating: updated.rating, timestamp: Date.now(), opponentName: human.displayName, score});
    tx.set(receipt, {pool: result.pool, match: id, engineVersion: R.ENGINE, createdAt: Date.now()});
    return {status: 'recorded', rating: updated.rating};
  });
});

exports.rateCompletedMatch = onDocumentWritten({...options, document: 'matches/{code}', retry: true}, async event => {
  const room = event.data.after.data();
  if (!room || !room.config?.seats?.every(s => s.control !== 'ai')) return;
  let result;
  try { result = await engine(roomInput(room)); } catch (error) {
    console.warn('Unrated invalid room', event.params.code, error.message); return;
  }
  if (!result.finished) return;
  // Early concessions do not establish competitive strength.
  if (['resignation','time'].includes(result.reason) && result.ply < room.config.seats.length * 4) return;
  let identities;
  try { identities = await Promise.all(R.humanIds(room).map(account)); }
  catch (error) { if (['permission-denied','auth/user-not-found'].includes(error.code)) return; throw error; }
  if (room.timedOut) {
    const seat = result.current;
    const started = room.clock?.started?.[seat]?.toMillis?.();
    if (seat !== room.timedOut || !Number.isFinite(started) || event.time &&
        started + room.clock.bank[seat] > Date.parse(event.time)) return;
  }
  await R.recordHumanResult(db, room, result, identities, Date.now());
});

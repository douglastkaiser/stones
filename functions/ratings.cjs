"use strict";
const crypto = require('node:crypto');
const ENGINE = 'shared-search-v1';
const prior = 1200;
const provisionalGames = 10;
const canonical = value => Array.isArray(value) ? value.map(canonical) : value && typeof value === 'object'
  ? Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])])) : value;
const hash = value => crypto.createHash('sha256').update(JSON.stringify(canonical(value)) ?? 'undefined').digest('hex');
const evidenceId = (code, ply) => hash([code, ply]);
function fresh(id, displayName, pool, isAi = false, level = null) {
  return {id, displayName, pool, rating: prior, gamesPlayed: 0, wins: 0,
    losses: 0, draws: 0, isAi, ...(isAi ? {engineVersion: ENGINE, aiDifficulty: level, opponents: 0} : {})};
}
function expected(a, b) { return 1 / (1 + 10 ** ((b - a) / 400)); }
function updates(players, winner, now) {
  if (players.length < 2 || players.length > 4 || new Set(players.map(p => p.id)).size !== players.length ||
      (winner !== null && !players.some(p => p.id === winner))) throw Error('Invalid participants');
  return players.map(p => {
    if (!Number.isFinite(p.rating) || !Number.isInteger(p.gamesPlayed) || p.gamesPlayed < 0) throw Error('Invalid rating');
    const score = winner === null ? 0.5 : winner === p.id ? 1 : 0;
    const delta = players.filter(o => o.id !== p.id).reduce((sum, o) => {
      const pairScore = winner === null ? 0.5 : p.id === winner ? 1 : o.id === winner ? 0 : 0.5;
      return sum + pairScore - expected(p.rating, o.rating);
    }, 0) / (players.length - 1);
    return {...p, rating: Math.max(100, Math.round(p.rating + (p.gamesPlayed < 30 ? 40 : 20) * delta)),
      gamesPlayed: p.gamesPlayed + 1, wins: p.wins + (score === 1 ? 1 : 0),
      losses: p.losses + (score === 0 ? 1 : 0), draws: p.draws + (score === 0.5 ? 1 : 0),
      established: p.gamesPlayed + 1 >= provisionalGames, lastUpdated: now};
  });
}
function humanIds(room) {
  const humans = room.config.seats.filter(s => s.control !== 'ai');
  const ids = humans.map(s => room.owners[s.id]);
  if (ids.some(id => typeof id !== 'string' || !id) || new Set(ids).size !== ids.length) throw Error('Independent seats required');
  return ids;
}
function calibration(bot, human, score, now, distinct) {
  if (human.gamesPlayed < provisionalGames || ![0, 0.5, 1].includes(score)) throw Error('Established opponent required');
  return {...bot, rating: Math.max(100, Math.round(bot.rating + (bot.gamesPlayed < 30 ? 40 : 20) * (score - expected(bot.rating, human.rating)))),
    gamesPlayed: bot.gamesPlayed + 1, wins: bot.wins + (score === 1 ? 1 : 0), losses: bot.losses + (score === 0 ? 1 : 0),
    draws: bot.draws + (score === 0.5 ? 1 : 0), opponents: bot.opponents + (distinct ? 1 : 0), lastUpdated: now,
    established: bot.gamesPlayed + 1 >= 30 && bot.opponents + (distinct ? 1 : 0) >= 10};
}
async function recordHumanResult(db, room, result, identities, now) {
  const receipt = db.doc(`ratingReceipts/match-${room.code}`);
  const refs = identities.map(p => db.doc(`ratingPools/${result.pool}/players/${p.uid}`));
  const winningId = result.winner === null ? null : room.owners[result.winner];
  return db.runTransaction(async tx => {
    const [done, ...snapshots] = await tx.getAll(receipt, ...refs);
    if (done.exists) return false;
    const players = snapshots.map((snapshot, i) => ({...(snapshot.data() || fresh(identities[i].uid, identities[i].name, result.pool)), displayName: identities[i].name}));
    const updated = updates(players, winningId, now);
    for (let i = 0; i < refs.length; i++) {
      const player = updated[i];
      tx.set(refs[i], player);
      if (player.established) tx.set(db.doc(`ratingPools/${result.pool}/standings/${player.id}`), player);
      tx.set(refs[i].collection('history').doc(hash(room.code)), {
        rating: player.rating, timestamp: now, opponentName: players.filter(p => p.id !== player.id).map(p => p.displayName).join(', '),
        score: winningId === null ? 0.5 : winningId === player.id ? 1 : 0,
      });
    }
    tx.set(receipt, {pool: result.pool, match: room.code, createdAt: now});
    return true;
  });
}
module.exports = {ENGINE, prior, hash, evidenceId, fresh, updates, humanIds, calibration, recordHumanResult};

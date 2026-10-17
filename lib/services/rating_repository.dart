import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/elo_rating.dart';
import '../game/match_config.dart';
import '../game/match_controller.dart';
import '../game/match_room_store.dart';
import '../game/rating_evidence.dart';

abstract class RatingRepository {
  Stream<EloRating?> watchPlayer(String pool, String uid);
  Future<List<EloRating>> leaders(String pool);
  Future<List<EloRating>> bots(String pool);
  Future<int> rank(String pool, int rating);
  Future<List<EloHistoryEntry>> history(String pool, String uid);
  Future<String> submitResult(MatchSession session, List<Map<String, dynamic>> moves);
}

class FirebaseRatingRepository implements RatingRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _players(String pool) =>
      _db.collection('ratingPools').doc(pool).collection('players');
  @override
  Stream<EloRating?> watchPlayer(String pool, String uid) => _players(pool)
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .where((doc) => !doc.metadata.isFromCache || doc.exists)
      .map((doc) => doc.exists ? EloRating.fromMap(doc.id, _dates(doc.data()!)) : null);
  @override
  Future<List<EloRating>> leaders(String pool) async {
    final result = await _db
        .collection('ratingPools')
        .doc(pool)
        .collection('players')
        .where('isAi', isEqualTo: false)
        .where('established', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(50)
        .get(const GetOptions(source: Source.server));
    return result.docs
        .map((doc) => EloRating.fromMap(doc.id, _dates(doc.data())))
        .toList();
  }

  @override
  Future<List<EloRating>> bots(String pool) async {
    final result = await _players(pool)
        .where('isAi', isEqualTo: true)
        .get(const GetOptions(source: Source.server));
    return result.docs
        .where((doc) => doc.data()['engineVersion'] == 'shared-search-v1')
        .map((doc) => EloRating.fromMap(doc.id, _dates(doc.data())))
        .toList();
  }

  @override
  Future<int> rank(String pool, int rating) async {
    final result = await _db
        .collection('ratingPools')
        .doc(pool)
        .collection('players')
        .where('isAi', isEqualTo: false)
        .where('established', isEqualTo: true)
        .where('rating', isGreaterThan: rating)
        .count()
        .get()
        .timeout(const Duration(seconds: 8));
    return 1 + (result.count ?? 0);
  }

  @override
  Future<List<EloHistoryEntry>> history(String pool, String uid) async {
    final result = await _players(pool)
        .doc(uid)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get(const GetOptions(source: Source.server));
    return result.docs
        .map((doc) => EloHistoryEntry.fromMap(_dates(doc.data())))
        .toList()
        .reversed
        .toList();
  }

  Map<String, dynamic> _dates(Map<String, dynamic> data) => {
    ...data,
    for (final key in ['lastUpdated', 'timestamp'])
      if (data[key] is Timestamp) key: (data[key] as Timestamp).millisecondsSinceEpoch,
  };

  @override
  Future<String> submitResult(MatchSession session, List<Map<String, dynamic>> moves) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return 'Sign in to record ratings';
    final evidence = RatingEvidence.verify(session, moves, user.uid);
    if (evidence == null) return 'Practice Ãƒâ€šÃ‚Â· this game is not eligible for ratings';
    if (evidence.humans.length == 1) {
      return _sampleAI(session, evidence, moves, user.uid).timeout(const Duration(seconds: 15));
    }
    final name = user.displayName?.trim();
    final displayName = name == null || name.isEmpty ? 'Player' : name.substring(0, min(60, name.length));
    Future<String> settle() => _settleHuman(session, evidence, user.uid, displayName)
        .timeout(const Duration(seconds: 15));
    final status = await settle();
    if (!status.startsWith('Waiting')) return status;
    // Both clients can finish together; the last vote settles for everyone.
    // Waiting never blocks gameplay and remains explicitly retryable on reload.
    try {
      await _db.collection('matches').doc(session.id).collection('ratingVotes')
          .snapshots().firstWhere((snapshot) => evidence.humans.every((uid) =>
            snapshot.docs.any((doc) => doc.id == uid &&
              doc.data()['ply'] == evidence.game.ply && doc.data()['winner'] == evidence.winner)))
          .timeout(const Duration(seconds: 12));
      return await settle();
    } on TimeoutException {
      return status;
    }
  }

  Future<String> _settleHuman(MatchSession session, RatingEvidence e, String uid, String name) =>
      _db.runTransaction((tx) async {
    final roomRef = _db.collection('matches').doc(session.id);
    final raw = (await tx.get(roomRef)).data()!;
    final resultId = raw['ratingReceipt'] as String? ?? sha256.convert(utf8.encode(session.id!)).toString();
    final receiptRef = _db.collection('ratingResults').doc(resultId);
    if ((await tx.get(receiptRef)).exists) return 'Rating recorded';
    final room = FirestoreMatchRoomStore.decodeRoom(raw);
    if (!RatingEvidence.same(room.toMap(), session.room!.toMap())) {
      // Lease changes are irrelevant, but board/ownership/termination must agree.
      if (!RatingEvidence.same(room.moves, session.room!.moves) ||
          !RatingEvidence.same(room.owners, session.room!.owners) ||
          room.resigned != session.room!.resigned || room.timedOut != session.room!.timedOut) {
        throw StateError('Room changed; reopen it before confirming the result');
      }
    }
    if (RatingEvidence.verify(MatchSession(game: room.replay(), room: room, id: room.code, uid: uid),
        room.moves, uid) == null) {
      throw StateError('Room result is not eligible');
    }
    final votes = <Map<String, dynamic>>[];
    for (final id in e.humans) {
      votes.add(id == uid ? {'ply': e.game.ply, 'winner': e.winner, 'name': name} :
          (await tx.get(roomRef.collection('ratingVotes').doc(id))).data() ?? {});
    }
    final agreed = votes.every((v) => v['ply'] == e.game.ply && v['winner'] == e.winner);
    final previous = <Map<String, dynamic>>[];
    if (agreed) {
      for (final id in e.humans) {
        previous.add((await tx.get(_players(e.pool).doc(id))).data() ?? {});
      }
    }
    tx.set(roomRef.collection('ratingVotes').doc(uid),
        {'ply': e.game.ply, 'winner': e.winner, 'name': name});
    if (!agreed) return 'Waiting for all players to confirm this result. Reopen the room or retry later.';
    tx.update(roomRef, {'ratingReceipt': resultId});
    tx.set(receiptRef, {'kind': 'human', 'room': session.id, 'pool': e.pool, 'participants': e.humans,
      'winner': e.winner, 'ply': e.game.ply, 'at': FieldValue.serverTimestamp()});
    for (var i = 0; i < e.humans.length; i++) {
      final before = previous[i];
      final rating = before['rating'] as int? ?? 1200;
      var change = 0.0;
      for (var j = 0; j < e.humans.length; j++) {
        if (i == j) {
          continue;
        }
        final score = e.winner == -1 || (e.winner != i && e.winner != j) ? 0.5 : e.winner == i ? 1.0 : 0.0;
        change += score - EloCalculator.expectedScore(rating, previous[j]['rating'] as int? ?? 1200);
      }
      final games = before['gamesPlayed'] as int? ?? 0;
      final nextRating = max(100, (rating + EloCalculator.kFactor(games) * change / (e.humans.length - 1)).round());
      final score = e.winner == -1 ? 0.5 : e.winner == i ? 1.0 : 0.0;
      final data = _record(before, e.pool, votes[i]['name'] as String, nextRating, score,
          resultId, isAi: false);
      _write(tx, e.pool, e.humans[i], data, score, '${e.humans.length}-player game');
    }
    return 'Rating recorded';
  });

  Future<String> _sampleAI(MatchSession session, RatingEvidence e,
      List<Map<String, dynamic>> moves, String uid) => _db.runTransaction((tx) async {
    final level = e.game.config.seats.firstWhere((s) => s.control == SeatControl.ai).level.name;
    final bot = 'ai_${RatingEvidence.engine}_$level';
    final id = sha256.convert(utf8.encode('${uid}_${session.id}')).toString();
    final receiptRef = _db.collection('ratingResults').doc(id);
    if ((await tx.get(receiptRef)).exists) return 'AI community estimate recorded';
    final anchor = (await tx.get(_players(e.pool).doc(uid))).data();
    if ((anchor?['gamesPlayed'] as int? ?? 0) < 10) {
      return 'Practice Ãƒâ€šÃ‚Â· play 10 competitive games in this ladder before contributing AI estimates';
    }
    final botRef = _players(e.pool).doc(bot);
    final before = (await tx.get(botRef)).data() ?? {};
    final limitRef = _db.collection('ratingLimits').doc('${uid}_${e.pool}_$level');
    final limit = (await tx.get(limitRef)).data();
    final last = limit?['at'] as Timestamp?;
    if (last != null && DateTime.now().difference(last.toDate()) < const Duration(hours: 24)) {
      return 'Practice Ãƒâ€šÃ‚Â· one AI sample per opponent and ladder every 24 hours';
    }
    final opponentRef = botRef.collection('opponents').doc(uid);
    final opponent = await tx.get(opponentRef);
    final score = e.winner == -1 ? 0.5 : e.winner == 1 ? 1.0 : 0.0;
    final next = EloCalculator.calculateNewRatings(ratingA: before['rating'] as int? ?? 1200,
      ratingB: anchor!['rating'] as int, gamesPlayedA: before['gamesPlayed'] as int? ?? 0,
      gamesPlayedB: anchor['gamesPlayed'] as int, actualScoreA: score).$1;
    tx.set(receiptRef, {'kind': 'ai', 'pool': e.pool, 'participants': [bot], 'actor': uid,
      'source': session.id, 'winner': e.winner, 'ply': moves.length, 'moves': moves,
      'level': level, 'engine': RatingEvidence.engine, 'at': FieldValue.serverTimestamp()});
    tx.set(_db.collection('aiResultKeys').doc('${uid}_${session.id}'), {'result': id});
    tx.set(limitRef, {'at': FieldValue.serverTimestamp(), 'lastResult': id});
    if (!opponent.exists) tx.set(opponentRef, {'firstAt': FieldValue.serverTimestamp(), 'lastResult': id});
    final data = _record(before, e.pool, '${level[0].toUpperCase()}${level.substring(1)} AI', next,
        score, id, isAi: true);
    data.addAll({'engineVersion': RatingEvidence.engine, 'aiDifficulty': level,
      'opponents': (before['opponents'] as int? ?? 0) + (opponent.exists ? 0 : 1)});
    _write(tx, e.pool, bot, data, score, 'Established player');
    return 'AI community estimate recorded Ãƒâ€šÃ‚Â· human rating unchanged';
  });

  Map<String, dynamic> _record(Map<String, dynamic> before, String pool, String name,
      int rating, double score, String result, {required bool isAi}) {
    final games = (before['gamesPlayed'] as int? ?? 0) + 1;
    return {'pool': pool, 'displayName': name, 'rating': rating, 'gamesPlayed': games,
      'wins': (before['wins'] as int? ?? 0) + (score == 1 ? 1 : 0),
      'losses': (before['losses'] as int? ?? 0) + (score == 0 ? 1 : 0),
      'draws': (before['draws'] as int? ?? 0) + (score == 0.5 ? 1 : 0),
      'isAi': isAi, 'established': !isAi && games >= 10, 'opponents': 0,
      'lastResult': result, 'lastUpdated': FieldValue.serverTimestamp()};
  }

  void _write(Transaction tx, String pool, String id, Map<String, dynamic> data,
      double score, String opponent) {
    final player = _players(pool).doc(id);
    tx.set(player, data);
    tx.set(player.collection('history').doc('${data['gamesPlayed']}'), {
      'rating': data['rating'], 'timestamp': FieldValue.serverTimestamp(),
      'score': score, 'opponentName': opponent});
  }
}

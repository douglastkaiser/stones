import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/elo_rating.dart';
import '../game/match_config.dart';
import '../game/match_controller.dart';
import '../game/match_room_store.dart';
import '../game/rating_evidence.dart';
import '../game/placement_elo.dart';
import '../game/rating_submission.dart';
import '../game/match_state.dart';
import '../game/skill_rating.dart';

part 'skill_result_recorder.dart';

abstract interface class LiveRatingRepository {
  Stream<List<EloRating>> watchLeaders(String pool);
}

abstract class RatingRepository {
  Stream<EloRating?> watchPlayer(String pool, String uid);
  Future<List<EloRating>> leaders(String pool);
  Future<List<EloRating>> bots(String pool);
  Future<int> rank(String pool, int rating);
  Future<List<EloHistoryEntry>> history(String pool, String uid);
  Future<RatingSubmission> submitResult(
      MatchSession session, List<Map<String, dynamic>> moves);
}

class FirebaseRatingRepository
    implements RatingRepository, LiveRatingRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _players(String pool) =>
      _db.collection('skillPools').doc(pool).collection('players');
  CollectionReference<Map<String, dynamic>> _legacyPlayers(String pool) =>
      _db.collection('ratingPools').doc(pool).collection('players');
  @override
  Stream<List<EloRating>> watchLeaders(String pool) {
    final topPlayers =
        _players(pool).orderBy('rating', descending: true).limit(50);
    final aiPlayers = _players(pool).where('isAi', isEqualTo: true);
    late StreamController<List<EloRating>> controller;
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final values = <int, List<EloRating>>{};
    void receive(int index, QuerySnapshot<Map<String, dynamic>> snapshot) {
      // An empty offline cache is not evidence of an empty public ladder.
      if (snapshot.metadata.isFromCache) return;
      values[index] = snapshot.docs
          .map((doc) => EloRating.fromMap(doc.id, _dates(doc.data())))
          .toList();
      if (values.length != 2) return;
      controller.add({
        for (final list in values.values)
          for (final player in list) player.id: player
      }.values.toList());
    }

    controller = StreamController<List<EloRating>>(
      onListen: () {
        subscriptions.add(topPlayers
            .snapshots(includeMetadataChanges: true)
            .listen((s) => receive(0, s), onError: controller.addError));
        subscriptions.add(aiPlayers
            .snapshots(includeMetadataChanges: true)
            .listen((s) => receive(1, s), onError: controller.addError));
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  @override
  Stream<EloRating?> watchPlayer(String pool, String uid) => _players(pool)
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .where((doc) => !doc.metadata.isFromCache || doc.exists)
      .map((doc) =>
          doc.exists ? EloRating.fromMap(doc.id, _dates(doc.data()!)) : null);
  @override
  Future<List<EloRating>> leaders(String pool) async {
    final result = await _db
        .collection('skillPools')
        .doc(pool)
        .collection('players')
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
        .where(
            (doc) => doc.data()['engineVersion'] == MatchConfig.currentAiEngine)
        .map((doc) => EloRating.fromMap(doc.id, _dates(doc.data())))
        .toList();
  }

  @override
  Future<int> rank(String pool, int rating) async {
    final result = await _db
        .collection('skillPools')
        .doc(pool)
        .collection('players')
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
          if (data[key] is Timestamp)
            key: (data[key] as Timestamp).millisecondsSinceEpoch,
      };

  @override
  Future<RatingSubmission> submitResult(
      MatchSession session, List<Map<String, dynamic>> moves) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const RatingSubmission.unrated('Sign in to record ratings');
    }
    if (session.game?.config.ratingVersion == 1) {
      final message = await _submitLegacy(session, moves);
      return RatingSubmission(
          message.startsWith('Waiting') || message.startsWith('Preparing')
              ? RatingSubmissionState.pending
              : message.contains('recorded')
                  ? RatingSubmissionState.confirmed
                  : RatingSubmissionState.unrated,
          message);
    }
    final evidence = RatingEvidence.verify(session, moves, user.uid);
    if (evidence == null) {
      return const RatingSubmission.unrated(
          'Practice · this game is not eligible for ratings');
    }
    var name = user.displayName?.trim() ?? 'Player';
    try {
      final profile = await _db
          .collection('playerProfiles')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
      name = profile.data()?['name'] as String? ?? name;
    } catch (_) {/* A profile read must not prevent recording the result. */}
    name = name.isEmpty ? 'Player' : name.substring(0, min(60, name.length));
    if (session.game!.config.ratingVersion >= 3) {
      return _SkillResultRecorder(_db, _newResultId)
          .submit(session, evidence, moves, user.uid, name);
    }
    Future<RatingSubmission> settle() =>
        _settlePlacements(session, evidence, moves, user.uid, name)
            .timeout(const Duration(seconds: 15));
    var result = await settle();
    if (result.message == 'Preparing rating receipt') result = await settle();
    if (result.state != RatingSubmissionState.pending || session.room == null) {
      return result;
    }
    final confirmed = Completer<void>();
    final subscription = _db
        .collection('matches')
        .doc(session.id)
        .collection('ratingVotes')
        .snapshots()
        .listen((snapshot) {
      if (!confirmed.isCompleted &&
          evidence.humans.every((id) => snapshot.docs.any((vote) =>
              vote.id == id &&
              _sameVote(vote.data(), _placementVote(evidence, ''))))) {
        confirmed.complete();
      }
    }, onError: (Object error, StackTrace stack) {
      if (!confirmed.isCompleted) confirmed.completeError(error, stack);
    });
    try {
      await confirmed.future.timeout(const Duration(seconds: 12));
      return await settle();
    } on TimeoutException {
      return result;
    } finally {
      await subscription.cancel();
    }
  }

  Map<String, dynamic> _placementVote(RatingEvidence e, String name) => {
        'version': 2,
        'ply': e.game.ply,
        'winner': e.winner,
        'reason': e.game.result!.reason.name,
        'ranks': e.ranks,
        'flats': [for (final id in e.game.config.ids) e.standings.flats[id]!],
        'name': name,
      };

  bool _sameVote(Map<String, dynamic>? a, Map<String, dynamic> b) =>
      a != null &&
      RatingEvidence.same({...a}..remove('name'), {...b}..remove('name'));

  RatingSubmission _fromReceipt(Map<String, dynamic> receipt, MatchState game) {
    final participants = (receipt['participants'] as List).cast<String>();
    final before = Map<String, dynamic>.from(receipt['before']);
    final after = Map<String, dynamic>.from(receipt['after']);
    return RatingSubmission(RatingSubmissionState.confirmed, 'Rating recorded',
        deltas: {
          for (var i = 0; i < game.config.ids.length; i++)
            game.config.ids[i]: RatingDelta(
                before[participants[i]] as int, after[participants[i]] as int)
        });
  }

  Future<RatingSubmission> _settlePlacements(
          MatchSession session,
          RatingEvidence e,
          List<Map<String, dynamic>> moves,
          String uid,
          String name) =>
      _db.runTransaction((tx) async {
        final online = session.room != null;
        final roomRef = _db.collection('matches').doc(session.id);
        final sourceRef =
            _db.collection('aiResultKeys').doc('${uid}_${session.id}');
        final source = (await tx.get(online ? roomRef : sourceRef)).data();
        if (online && source?['ratingKey'] == null) {
          tx.update(roomRef, {'ratingKey': _newResultId()});
          return const RatingSubmission.pending('Preparing rating receipt');
        }
        final receiptId =
            (online ? source!['ratingKey'] : source?['result']) as String? ??
                _newResultId();
        final receiptRef = _db.collection('ratingResults').doc(receiptId);
        final existing = (await tx.get(receiptRef)).data();
        if (existing != null) return _fromReceipt(existing, e.game);
        final vote = _placementVote(e, name);
        final votes = <String, Map<String, dynamic>?>{};
        if (online) {
          for (final id in e.humans) {
            votes[id] = id == uid
                ? vote
                : (await tx.get(roomRef.collection('ratingVotes').doc(id)))
                    .data();
          }
          if (!e.humans.every((id) => _sameVote(votes[id], vote))) {
            tx.set(roomRef.collection('ratingVotes').doc(uid), vote);
            return const RatingSubmission.pending(
                'Waiting for all players to confirm these standings. Reopen the room or retry later.');
          }
        }
        final participants = e.participants;
        final ids = participants.toSet();
        final previous = <String, Map<String, dynamic>>{};
        for (final id in ids) {
          previous[id] =
              (await tx.get(_legacyPlayers(e.pool).doc(id))).data() ?? {};
        }
        final before = {
          for (final id in ids) id: previous[id]!['rating'] as int? ?? 1200
        };
        final after = PlacementElo.calculate(
            participants: participants,
            ranks: e.ranks,
            ratings: before,
            gamesPlayed: {
              for (final id in ids)
                id: previous[id]!['gamesPlayed'] as int? ?? 0
            });
        final names = <String>[
          for (var i = 0; i < participants.length; i++)
            e.game.config.seats[i].control == SeatControl.ai
                ? '${e.game.config.seats[i].level.name[0].toUpperCase()}${e.game.config.seats[i].level.name.substring(1)} AI'
                : online
                    ? votes[participants[i]]!['name'] as String
                    : name
        ];
        final receipt = <String, dynamic>{
          'kind': 'placements',
          'version': 2,
          'pool': e.pool,
          'participants': participants,
          'config': e.game.config.toMap(),
          'ranks': e.ranks,
          'winner': e.winner,
          'reason': e.game.result!.reason.name,
          'flats': vote['flats'],
          'names': names,
          'ply': e.game.ply,
          'actor': uid,
          'source': session.id,
          'room': online ? session.id : null,
          'moves': online ? <Map<String, dynamic>>[] : moves,
          'before': before,
          'after': after,
          'at': FieldValue.serverTimestamp(),
        };
        tx.set(receiptRef, receipt);
        if (online) {
          tx.set(roomRef.collection('ratingVotes').doc(uid), vote);
          tx.update(roomRef, {'ratingReceipt': receiptId});
        } else {
          tx.set(sourceRef, {'result': receiptId});
        }
        for (final id in ids) {
          final indices = [
            for (var i = 0; i < participants.length; i++)
              if (participants[i] == id) i
          ];
          final scores = [
            for (final i in indices)
              e.ranks[i] != 1
                  ? 0.0
                  : e.ranks.where((rank) => rank == 1).length > 1
                      ? .5
                      : 1.0
          ];
          final old = previous[id]!;
          final seat = e.game.config.seats[indices.first];
          final ai = seat.control == SeatControl.ai;
          final games = (old['gamesPlayed'] as int? ?? 0) + indices.length;
          final data = <String, dynamic>{
            'pool': e.pool,
            'displayName': names[indices.first],
            'rating': after[id],
            'gamesPlayed': games,
            'wins':
                (old['wins'] as int? ?? 0) + scores.where((s) => s == 1).length,
            'losses': (old['losses'] as int? ?? 0) +
                scores.where((s) => s == 0).length,
            'draws': (old['draws'] as int? ?? 0) +
                scores.where((s) => s == .5).length,
            'isAi': ai,
            'established': games >= 10,
            'opponents': ai ? old['opponents'] as int? ?? 0 : 0,
            'lastResult': receiptId,
            'lastUpdated': FieldValue.serverTimestamp(),
            if (ai) 'engineVersion': e.game.config.aiEngine,
            if (ai) 'aiDifficulty': seat.level.name,
          };
          final player = _legacyPlayers(e.pool).doc(id);
          tx.set(player, data);
          tx.set(player.collection('history').doc('$games'), {
            'rating': after[id],
            'before': before[id],
            'delta': after[id]! - before[id]!,
            'timestamp': FieldValue.serverTimestamp(),
            'score': scores.reduce((a, b) => a + b) / scores.length,
            'opponentName': '${participants.length}-player game',
            'placements': e.ranks,
            'seat': indices.first,
            'appearances': indices.length,
          });
        }
        return _fromReceipt(receipt, e.game);
      });

  Future<String> _submitLegacy(
      MatchSession session, List<Map<String, dynamic>> moves) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return 'Sign in to record ratings';
    final evidence = RatingEvidence.verify(session, moves, user.uid);
    if (evidence == null) {
      return 'Practice · this game is not eligible for ratings';
    }
    if (evidence.humans.length == 1) {
      return _sampleAI(session, evidence, moves, user.uid)
          .timeout(const Duration(seconds: 15));
    }
    final name = user.displayName?.trim();
    final displayName = name == null || name.isEmpty
        ? 'Player'
        : name.substring(0, min(60, name.length));
    Future<String> settle() =>
        _settleHuman(session, evidence, user.uid, displayName)
            .timeout(const Duration(seconds: 15));
    var status = await settle();
    if (status == 'Preparing rating receipt') {
      status = await settle();
    }
    if (!status.startsWith('Waiting')) return status;
    // Both clients can finish together; the last vote settles for everyone.
    // Waiting never blocks gameplay and remains explicitly retryable on reload.
    final confirmed = Completer<void>();
    final subscription = _db
        .collection('matches')
        .doc(session.id)
        .collection('ratingVotes')
        .snapshots()
        .listen((snapshot) {
      if (!confirmed.isCompleted &&
          evidence.humans.every((uid) => snapshot.docs.any((doc) =>
              doc.id == uid &&
              doc.data()['ply'] == evidence.game.ply &&
              doc.data()['winner'] == evidence.winner))) {
        confirmed.complete();
      }
    }, onError: (Object error, StackTrace stack) {
      if (!confirmed.isCompleted) confirmed.completeError(error, stack);
    });
    try {
      await confirmed.future.timeout(const Duration(seconds: 12));
      return await settle();
    } on TimeoutException {
      return status;
    } finally {
      await subscription.cancel();
    }
  }

  Future<String> _settleHuman(
          MatchSession session, RatingEvidence e, String uid, String name) =>
      _db.runTransaction((tx) async {
        final roomRef = _db.collection('matches').doc(session.id);
        final raw = (await tx.get(roomRef)).data()!;
        if (raw['ratingKey'] == null) {
          tx.update(roomRef, {'ratingKey': _newResultId()});
          return 'Preparing rating receipt';
        }
        final resultId =
            raw['ratingReceipt'] as String? ?? raw['ratingKey'] as String;
        final receiptRef = _db.collection('ratingResults').doc(resultId);
        if ((await tx.get(receiptRef)).exists) return 'Rating recorded';
        final room = FirestoreMatchRoomStore.decodeRoom(raw);
        if (!RatingEvidence.same(room.toMap(), session.room!.toMap())) {
          // Lease changes are irrelevant, but board/ownership/termination must agree.
          if (!RatingEvidence.same(room.moves, session.room!.moves) ||
              !RatingEvidence.same(room.owners, session.room!.owners) ||
              room.resigned != session.room!.resigned ||
              room.timedOut != session.room!.timedOut) {
            throw StateError(
                'Room changed; reopen it before confirming the result');
          }
        }
        if (RatingEvidence.verify(
                MatchSession(
                    game: room.replay(), room: room, id: room.code, uid: uid),
                room.moves,
                uid) ==
            null) {
          throw StateError('Room result is not eligible');
        }
        final votes = <Map<String, dynamic>>[];
        for (final id in e.humans) {
          votes.add(id == uid
              ? {'ply': e.game.ply, 'winner': e.winner, 'name': name}
              : (await tx.get(roomRef.collection('ratingVotes').doc(id)))
                      .data() ??
                  {});
        }
        final agreed = votes
            .every((v) => v['ply'] == e.game.ply && v['winner'] == e.winner);
        final previous = <Map<String, dynamic>>[];
        if (agreed) {
          for (final id in e.humans) {
            previous.add(
                (await tx.get(_legacyPlayers(e.pool).doc(id))).data() ?? {});
          }
        }
        tx.set(roomRef.collection('ratingVotes').doc(uid),
            {'ply': e.game.ply, 'winner': e.winner, 'name': name});
        if (!agreed) {
          return 'Waiting for all players to confirm this result. Reopen the room or retry later.';
        }
        tx.update(roomRef, {'ratingReceipt': resultId});
        tx.set(receiptRef, {
          'kind': 'human',
          'room': session.id,
          'pool': e.pool,
          'participants': e.humans,
          'winner': e.winner,
          'ply': e.game.ply,
          'at': FieldValue.serverTimestamp()
        });
        for (var i = 0; i < e.humans.length; i++) {
          final before = previous[i];
          final rating = before['rating'] as int? ?? 1200;
          var change = 0.0;
          for (var j = 0; j < e.humans.length; j++) {
            if (i == j) {
              continue;
            }
            final score = e.winner == -1 || (e.winner != i && e.winner != j)
                ? 0.5
                : e.winner == i
                    ? 1.0
                    : 0.0;
            change += score -
                EloCalculator.expectedScore(
                    rating, previous[j]['rating'] as int? ?? 1200);
          }
          final games = before['gamesPlayed'] as int? ?? 0;
          final nextRating = max(
              100,
              (rating +
                      EloCalculator.kFactor(games) *
                          change /
                          (e.humans.length - 1))
                  .round());
          final score = e.winner == -1
              ? 0.5
              : e.winner == i
                  ? 1.0
                  : 0.0;
          final data = _record(before, e.pool, votes[i]['name'] as String,
              nextRating, score, resultId,
              isAi: false);
          _write(tx, e.pool, e.humans[i], data, score,
              '${e.humans.length}-player game');
        }
        return 'Rating recorded';
      });

  Future<String> _sampleAI(MatchSession session, RatingEvidence e,
          List<Map<String, dynamic>> moves, String uid) =>
      _db.runTransaction((tx) async {
        final level = e.game.config.seats
            .firstWhere((s) => s.control == SeatControl.ai)
            .level
            .name;
        final bot = 'ai_${RatingEvidence.engine}_$level';
        final keyRef =
            _db.collection('aiResultKeys').doc('${uid}_${session.id}');
        final existingKey = (await tx.get(keyRef)).data();
        final id = existingKey?['result'] as String? ?? _newResultId();
        final receiptRef = _db.collection('ratingResults').doc(id);
        if ((await tx.get(receiptRef)).exists) {
          return 'AI community estimate recorded';
        }
        final anchor = (await tx.get(_legacyPlayers(e.pool).doc(uid))).data();
        if ((anchor?['gamesPlayed'] as int? ?? 0) < 10) {
          return 'Practice · play 10 competitive games in this ladder before contributing AI estimates';
        }
        final botRef = _legacyPlayers(e.pool).doc(bot);
        final before = (await tx.get(botRef)).data() ?? {};
        final limitRef =
            _db.collection('ratingLimits').doc('${uid}_${e.pool}_$level');
        final limit = (await tx.get(limitRef)).data();
        final last = limit?['at'] as Timestamp?;
        if (last != null &&
            DateTime.now().difference(last.toDate()) <
                const Duration(hours: 24)) {
          return 'Practice · one AI sample per opponent and ladder every 24 hours';
        }
        final opponentRef = botRef.collection('opponents').doc(uid);
        final opponent = await tx.get(opponentRef);
        final score = e.winner == -1
            ? 0.5
            : e.winner == 1
                ? 1.0
                : 0.0;
        final next = EloCalculator.calculateNewRatings(
                ratingA: before['rating'] as int? ?? 1200,
                ratingB: anchor!['rating'] as int,
                gamesPlayedA: before['gamesPlayed'] as int? ?? 0,
                gamesPlayedB: anchor['gamesPlayed'] as int,
                actualScoreA: score)
            .$1;
        tx.set(receiptRef, {
          'kind': 'ai',
          'pool': e.pool,
          'participants': [bot],
          'actor': uid,
          'source': session.id,
          'winner': e.winner,
          'ply': moves.length,
          'moves': moves,
          'level': level,
          'engine': RatingEvidence.engine,
          'at': FieldValue.serverTimestamp()
        });
        tx.set(keyRef, {'result': id});
        tx.set(
            limitRef, {'at': FieldValue.serverTimestamp(), 'lastResult': id});
        if (!opponent.exists) {
          tx.set(opponentRef,
              {'firstAt': FieldValue.serverTimestamp(), 'lastResult': id});
        }
        final data = _record(
            before,
            e.pool,
            '${level[0].toUpperCase()}${level.substring(1)} AI',
            next,
            score,
            id,
            isAi: true);
        data.addAll({
          'engineVersion': RatingEvidence.engine,
          'aiDifficulty': level,
          'opponents':
              (before['opponents'] as int? ?? 0) + (opponent.exists ? 0 : 1)
        });
        _write(tx, e.pool, bot, data, score, 'Established player');
        return 'AI community estimate recorded · human rating unchanged';
      });

  String _newResultId() {
    final random = Random.secure();
    return List.generate(64, (_) => random.nextInt(16).toRadixString(16))
        .join();
  }

  Map<String, dynamic> _record(Map<String, dynamic> before, String pool,
      String name, int rating, double score, String result,
      {required bool isAi}) {
    final games = (before['gamesPlayed'] as int? ?? 0) + 1;
    return {
      'pool': pool,
      'displayName': name,
      'rating': rating,
      'gamesPlayed': games,
      'wins': (before['wins'] as int? ?? 0) + (score == 1 ? 1 : 0),
      'losses': (before['losses'] as int? ?? 0) + (score == 0 ? 1 : 0),
      'draws': (before['draws'] as int? ?? 0) + (score == 0.5 ? 1 : 0),
      'isAi': isAi,
      'established': !isAi && games >= 10,
      'opponents': 0,
      'lastResult': result,
      'lastUpdated': FieldValue.serverTimestamp()
    };
  }

  void _write(Transaction tx, String pool, String id, Map<String, dynamic> data,
      double score, String opponent) {
    final player = _legacyPlayers(pool).doc(id);
    tx.set(player, data);
    tx.set(player.collection('history').doc('${data['gamesPlayed']}'), {
      'rating': data['rating'],
      'timestamp': FieldValue.serverTimestamp(),
      'score': score,
      'opponentName': opponent
    });
  }
}

part of 'rating_repository.dart';

/// Confirmation freezes the source once. Each scope then settles atomically,
/// independently and exactly once, within Spark's security-rule access limits.
class _SkillResultRecorder {
  _SkillResultRecorder(this.db, this.newId);
  final FirebaseFirestore db;
  final String Function() newId;

  Map<String, dynamic> _vote(RatingEvidence e, String name) => {
        'version': 3,
        'ply': e.game.ply,
        'winner': e.winner,
        'reason': e.game.result!.reason.name,
        'name': name,
      };

  bool _agrees(Map<String, dynamic>? a, Map<String, dynamic> b) =>
      a != null &&
      RatingEvidence.same({...a}..remove('name'), {...b}..remove('name'));

  Future<RatingSubmission> submit(MatchSession session, RatingEvidence e,
      List<Map<String, dynamic>> moves, String uid, String name) async {
    if (session.room != null) {
      final accounts = await Future.wait(e.humans.map((uid) => db
              .collection('playerAccounts')
              .doc(uid)
              .get(const GetOptions(source: Source.server))))
          .timeout(const Duration(seconds: 8));
      if (accounts.any((doc) => doc.data()?['registered'] == false)) {
        return const RatingSubmission(RatingSubmissionState.awaitingAccounts,
            'A player is using a guest account. Every human must sign in to record ratings. Ask them to sign in, then reopen this room or retry.');
      }
    }
    Future<String?> confirm() => _confirm(session, e, moves, uid, name)
        .timeout(const Duration(seconds: 15));
    var key = await confirm();
    if (key == null && session.room != null) {
      // A legacy room can need its immutable random key allocated first.
      key = await confirm();
      if (key == null) {
        try {
          await db
              .collection('matches')
              .doc(session.id)
              .collection('ratingVotes')
              .snapshots()
              .timeout(const Duration(seconds: 12))
              .firstWhere((snapshot) => e.humans.every((human) => snapshot.docs
                  .any((vote) =>
                      vote.id == human &&
                      _agrees(vote.data(), _vote(e, name)))));
          key = await confirm();
        } on TimeoutException {
          return const RatingSubmission.pending(
              'Waiting for all players to confirm. Every human must sign in and open the finished game; guest accounts cannot confirm ratings.');
        }
      }
    }
    if (key == null) return const RatingSubmission.pending();
    final receipts = <String, Map<String, dynamic>>{};
    for (final pool in ['overall', e.pool]) {
      try {
        receipts[pool] =
            await _settle(key, pool).timeout(const Duration(seconds: 15));
      } catch (error) {
        // Preserve any confirmed delta; a retry reads its immutable receipt.
        return RatingSubmission(
            RatingSubmissionState.failed, ratingFailureMessage(error),
            failure: ratingFailure(error),
            deltas: _deltas(receipts['overall'], e),
            formatDeltas: _deltas(receipts[e.pool], e),
            skillBased: true);
      }
    }
    return RatingSubmission(
        RatingSubmissionState.confirmed, 'Overall and format ratings recorded',
        deltas: _deltas(receipts['overall'], e),
        formatDeltas: _deltas(receipts[e.pool], e),
        skillBased: true);
  }

  Map<SeatId, RatingDelta> _deltas(
      Map<String, dynamic>? receipt, RatingEvidence e) {
    if (receipt == null) return {};
    final before = Map<String, dynamic>.from(receipt['before']);
    final after = Map<String, dynamic>.from(receipt['after']);
    return {
      for (var i = 0; i < e.participants.length; i++)
        e.game.config.ids[i]: RatingDelta(
            SkillEstimate.fromMap(
                    Map<String, dynamic>.from(before[e.participants[i]]))
                .rating,
            SkillEstimate.fromMap(
                    Map<String, dynamic>.from(after[e.participants[i]]))
                .rating),
    };
  }

  Future<String?> _confirm(MatchSession session, RatingEvidence e,
          List<Map<String, dynamic>> moves, String uid, String name) =>
      db.runTransaction((tx) async {
        final online = session.room != null;
        final sourceRef = online
            ? db.collection('matches').doc(session.id)
            : db.collection('aiResultKeys').doc('${uid}_${session.id}');
        final source = (await tx.get(sourceRef)).data();
        if (online && source?['ratingKey'] == null) {
          tx.update(sourceRef, {'ratingKey': newId()});
          return null;
        }
        final key =
            (online ? source!['ratingKey'] : source?['result']) as String? ??
                newId();
        final receiptRef = db.collection('ratingResults').doc(key);
        if ((await tx.get(receiptRef)).exists) return key;
        final vote = _vote(e, name);
        final votes = <String, Map<String, dynamic>?>{};
        if (online) {
          for (final human in e.humans) {
            votes[human] = human == uid
                ? vote
                : (await tx.get(sourceRef.collection('ratingVotes').doc(human)))
                    .data();
          }
          if (!e.humans.every((human) => _agrees(votes[human], vote))) {
            tx.set(sourceRef.collection('ratingVotes').doc(uid), vote);
            return null;
          }
        }
        final names = [
          for (var i = 0; i < e.participants.length; i++)
            e.game.config.seats[i].control == SeatControl.ai
                ? '${e.game.config.seats[i].level.name[0].toUpperCase()}${e.game.config.seats[i].level.name.substring(1)} AI'
                : online
                    ? votes[e.participants[i]]!['name'] as String
                    : name,
        ];
        tx.set(receiptRef, {
          'kind': 'skill',
          'version': 3,
          'pool': e.pool,
          'participants': e.participants,
          'config': e.game.config.toMap(),
          'winner': e.winner,
          'reason': e.game.result!.reason.name,
          'names': names,
          'ply': e.game.ply,
          'actor': uid,
          'source': session.id,
          'room': online ? session.id : null,
          'moves': online ? <Map<String, dynamic>>[] : moves,
          'at': FieldValue.serverTimestamp(),
        });
        if (online) {
          tx.set(sourceRef.collection('ratingVotes').doc(uid), vote);
          tx.update(sourceRef, {'ratingReceipt': key});
        } else {
          tx.set(sourceRef, {'result': key});
        }
        return key;
      });

  Future<Map<String, dynamic>> _settle(String key, String pool) =>
      db.runTransaction((tx) async {
        final receiptRef = db
            .collection('skillSettlements')
            .doc(key)
            .collection('scopes')
            .doc(pool);
        final existing = (await tx.get(receiptRef)).data();
        if (existing != null) return existing;
        final source =
            (await tx.get(db.collection('ratingResults').doc(key))).data()!;
        final participants = (source['participants'] as List).cast<String>();
        final ids = participants.toSet();
        final players =
            db.collection('skillPools').doc(pool).collection('players');
        final previous = <String, Map<String, dynamic>>{};
        for (final id in ids) {
          previous[id] = (await tx.get(players.doc(id))).data() ?? {};
        }
        final before = {
          for (final id in ids) id: SkillEstimate.fromMap(previous[id]!)
        };
        final winner = source['winner'] as int;
        final after = SkillCalculator.forMatch(
            participants: participants, winner: winner, estimates: before);
        final receipt = <String, dynamic>{
          'source': key,
          'pool': pool,
          'before': {for (final id in ids) id: before[id]!.toMap()},
          'after': {for (final id in ids) id: after[id]!.toMap()},
          'at': FieldValue.serverTimestamp(),
        };
        tx.set(receiptRef, receipt);
        for (final id in ids) {
          final index = participants.indexOf(id);
          final seat = (source['config'] as Map)['seats'][index] as Map;
          final ai = seat['control'] == 'ai';
          final old = previous[id]!;
          final games = (old['gamesPlayed'] as int? ?? 0) + 1;
          final score = winner == -1
              ? .5
              : participants[winner] == id
                  ? 1.0
                  : 0.0;
          final next = after[id]!;
          tx.set(players.doc(id), {
            'pool': pool,
            'displayName': (source['names'] as List)[index],
            ...next.toMap(),
            'rating': next.rating,
            'gamesPlayed': games,
            'wins': (old['wins'] as int? ?? 0) + (score == 1 ? 1 : 0),
            'losses': (old['losses'] as int? ?? 0) + (score == 0 ? 1 : 0),
            'draws': (old['draws'] as int? ?? 0) + (score == .5 ? 1 : 0),
            'isAi': ai,
            'established': games >= 10 && next.deviation <= 150,
            'lastResult': key,
            'lastUpdated': FieldValue.serverTimestamp(),
            if (ai)
              'engineVersion': (source['config'] as Map)['aiEngine'] ??
                  RatingEvidence.engine,
            if (ai) 'aiDifficulty': seat['level'],
          });
          tx.set(players.doc(id).collection('history').doc('$games'), {
            ...next.toMap(),
            'rating': next.rating,
            'before': before[id]!.rating,
            'delta': next.rating - before[id]!.rating,
            'timestamp': FieldValue.serverTimestamp(),
            'score': score,
            'opponentName': '${participants.length}-player game',
            'seat': index,
            'appearances': participants.where((p) => p == id).length,
          });
        }
        return receipt;
      });
}

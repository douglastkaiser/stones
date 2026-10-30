import '../models/cosmetics.dart';
import 'match_config.dart';
import 'court_takeback.dart';
import 'match_clock.dart';
import 'match_elapsed.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// A second device confirmed a turn before this client's transaction completed.
class StaleMatchMove extends StateError {
  StaleMatchMove()
      : super('Another move was confirmed first. Refreshing board.');
}

/// New unified room codec. Existing square/Hex rooms retain their own codecs.
class MatchRoom {
  MatchRoom({
    required this.code,
    required this.host,
    required this.config,
    required Map<SeatId, String?> owners,
    Map<SeatId, PieceStyle>? styles,
    this.boardTheme = BoardTheme.classicWood,
    List<Map<String, dynamic>> moves = const [],
    this.revision = 0,
    this.takeback,
    this.resigned,
    this.aiRunner,
    this.aiLeaseAt,
    MatchClock? clock,
    this.timedOut,
    this.startedAt,
    this.lastMoveAt,
    this.finishedAt,
  })  : clock = clock ??
            (config.clockSeconds > 0 ? MatchClock.initial(config) : null),
        owners = Map.unmodifiable(owners),
        styles = Map.unmodifiable(
            styles ?? {for (final id in config.ids) id: PieceStyle.standard}),
        moves = List.unmodifiable(
            moves.map((move) => Map<String, dynamic>.unmodifiable({
                  ...move,
                  'drops': List<int>.unmodifiable(
                      (move['drops'] as List).cast<int>()),
                }))) {
    if (!RegExp(r'^U[A-Z]{6}$').hasMatch(code) ||
        host.isEmpty ||
        !config.online ||
        owners.length != config.seats.length ||
        this.styles.length != config.seats.length ||
        config.ids.any(
            (id) => !owners.containsKey(id) || !this.styles.containsKey(id)) ||
        owners.values.any((uid) => uid != null && uid.isEmpty) ||
        (resigned != null && !config.ids.contains(resigned)) ||
        (timedOut != null &&
            (!config.ids.contains(timedOut) || resigned != null)) ||
        ((this.clock == null) != (config.clockSeconds == 0)) ||
        (this.clock != null &&
            (this.clock!.bank.length != config.ids.length ||
                config.ids.any((id) => !this.clock!.bank.containsKey(id))))) {
      throw const FormatException('Invalid unified room');
    }
    for (final seat in config.seats) {
      if ((seat.control == SeatControl.localHuman && owners[seat.id] != host) ||
          (seat.control == SeatControl.ai && owners[seat.id] != null)) {
        throw const FormatException('Invalid seat ownership');
      }
    }
    final remoteOwners = config.seats
        .where((s) => s.control == SeatControl.onlineHuman)
        .map((s) => owners[s.id])
        .whereType<String>()
        .toList();
    if (remoteOwners.contains(host) ||
        remoteOwners.toSet().length != remoteOwners.length) {
      throw const FormatException(
          'Online identities must occupy distinct seats');
    }
    if (revision < 0 ||
        (!config.court && (revision != 0 || takeback != null))) {
      throw const FormatException('Invalid Court revision');
    }
    final decision = takeback;
    if (decision != null &&
        (!ready ||
            decision.baseRevision < 0 ||
            decision.baseRevision >= revision ||
            !humanOwners.contains(decision.requestedBy) ||
            decision.approvals.isEmpty ||
            decision.approvals.toSet().length != decision.approvals.length ||
            !decision.approvals.contains(decision.requestedBy) ||
            !humanOwners.containsAll(decision.approvals) ||
            decision.removed.isEmpty ||
            decision.removed.length > config.seats.length ||
            !_equal(moves, [...decision.retained, ...decision.removed]) ||
            owners[SeatId.values
                    .byName(decision.removed.first['seat'] as String)] !=
                decision.requestedBy ||
            decision.removed.skip(1).any((move) =>
                owners[SeatId.values.byName(move['seat'] as String)] ==
                decision.requestedBy))) {
      throw const FormatException('Invalid Court takeback');
    }
    if ((aiRunner == null) != (aiLeaseAt == null) ||
        (aiRunner != null &&
            aiRunner != host &&
            !owners.values.contains(aiRunner))) {
      throw const FormatException('Invalid AI runner lease');
    }
  }

  final String code;
  final String host;
  final MatchConfig config;
  final Map<SeatId, String?> owners;
  final Map<SeatId, PieceStyle> styles;
  final BoardTheme boardTheme;
  final List<Map<String, dynamic>> moves;
  final int revision;
  final CourtTakeback? takeback;
  Set<String> get humanOwners => owners.values.whereType<String>().toSet();
  final SeatId? resigned;
  final String? aiRunner;
  final DateTime? aiLeaseAt;
  final MatchClock? clock;
  final SeatId? timedOut;
  final DateTime? startedAt, lastMoveAt, finishedAt;
  MatchElapsed? elapsed(bool finished) {
    if (startedAt == null) return null;
    final end = finished ? finishedAt : null;
    if (finished && end == null) return null;
    return finished
        ? MatchElapsed(
            milliseconds:
                end!.difference(startedAt!).inMilliseconds.clamp(0, 1 << 53))
        : MatchElapsed(runningSince: startedAt);
  }

  static const leaseDuration = Duration(seconds: 30);
  bool runnerActive(DateTime now) =>
      aiLeaseAt != null && now.isBefore(aiLeaseAt!.add(leaseDuration));
  bool runsAI(String uid, DateTime now) => aiRunner == uid && runnerActive(now);
  MatchRoom claimRunner(String uid, DateTime now) {
    if (!ready ||
        replay().finished ||
        !config.seats.any((s) => s.control == SeatControl.ai) ||
        (uid != host && !owners.values.contains(uid)) ||
        (runnerActive(now) && aiRunner != uid)) {
      throw StateError('AI lease is unavailable');
    }
    return MatchRoom(
        startedAt: startedAt,
        lastMoveAt: lastMoveAt,
        finishedAt: finishedAt,
        revision: revision,
        takeback: takeback,
        code: code,
        host: host,
        config: config,
        owners: owners,
        styles: styles,
        boardTheme: boardTheme,
        moves: moves,
        resigned: resigned,
        aiRunner: uid,
        aiLeaseAt: now,
        clock: clock,
        timedOut: timedOut);
  }

  bool get ready => config.seats
      .every((s) => s.control == SeatControl.ai || owners[s.id] != null);
  Set<SeatId> controlledBy(String uid) =>
      config.ids.where((id) => owners[id] == uid).toSet();
  bool canMove(String uid, MatchState game, {DateTime? now}) =>
      ready &&
      takeback == null &&
      resigned == null &&
      timedOut == null &&
      !(clock?.expired(game.current, now ?? DateTime.now()) ?? false) &&
      !game.finished &&
      (owners[game.current] == uid ||
          (config.seat(game.current).control == SeatControl.ai &&
              runsAI(uid, now ?? DateTime.now())));

  late final MatchState _replayed = _replay();
  MatchState replay() => _replayed;

  MatchState _replay() {
    var game = MatchState.initial(config);
    for (final recorded in moves) {
      game = _applyRecord(game, recorded);
    }
    return _termination(game);
  }

  MatchState replayAfter(MatchRoom previous, MatchState position) {
    if (previous.code != code ||
        previous.host != host ||
        !_equal(previous.config.toMap(), config.toMap()) ||
        previous.boardTheme != boardTheme ||
        previous.moves.length != position.ply ||
        revision < previous.revision) {
      throw const FormatException('Room configuration or history changed');
    }
    for (final id in config.ids) {
      if (previous.owners[id] != null &&
          (owners[id] != previous.owners[id] ||
              styles[id] != previous.styles[id])) {
        throw const FormatException('Occupied seat identity or theme changed');
      }
    }
    // Rewinds are server-authorized history revisions, never unconfirmed edits.
    if (config.court && revision > previous.revision) return replay();
    if (moves.length < previous.moves.length ||
        (previous.resigned != null && previous.resigned != resigned) ||
        (previous.timedOut != null && previous.timedOut != timedOut)) {
      throw const FormatException('Room history changed without a revision');
    }
    for (var i = 0; i < previous.moves.length; i++) {
      if (!_equal(previous.moves[i], moves[i])) {
        throw const FormatException('Recorded move prefix changed');
      }
    }
    if (previous.resigned != null || previous.timedOut != null) return position;
    var game = position;
    for (final record in moves.skip(previous.moves.length)) {
      game = _applyRecord(game, record);
    }
    return _termination(game);
  }

  MatchState _applyRecord(MatchState game, Map<String, dynamic> record) {
    if (record['seat'] != game.current.name) {
      throw const FormatException('Recorded seat is out of turn');
    }
    final next = MatchRules.play(game, MatchMove.fromMap(record));
    if (next == null) throw const FormatException('Illegal recorded move');
    return next;
  }

  MatchState _termination(MatchState game) {
    final endedSeat = resigned ?? timedOut;
    if (endedSeat == null) return game;
    if (game.finished) {
      throw const FormatException('Resignation follows terminal move');
    }
    return game.copyWith(
        result: config.seats.length == 2
            ? MatchResult(config.next(endedSeat),
                timedOut == null ? ResultReason.resignation : ResultReason.time)
            : const MatchResult(null, ResultReason.abandoned));
  }

  MatchRoom expire(String uid, DateTime now) {
    final game = replay();
    if ((uid != host && !owners.values.contains(uid)) ||
        game.finished ||
        !(clock?.expired(game.current, now) ?? false)) {
      throw StateError('No clock expiry to claim');
    }
    return MatchRoom(
        startedAt: startedAt,
        lastMoveAt: lastMoveAt,
        finishedAt: finishedAt,
        revision: revision,
        takeback: takeback,
        code: code,
        host: host,
        config: config,
        owners: owners,
        styles: styles,
        boardTheme: boardTheme,
        moves: moves,
        aiRunner: aiRunner,
        aiLeaseAt: aiLeaseAt,
        clock: clock,
        timedOut: game.current);
  }

  MatchRoom join(String uid, PieceStyle style) {
    if (uid.isEmpty) throw const FormatException('Missing joining identity');
    if (host == uid || owners.values.contains(uid)) return this;
    if (resigned != null || moves.isNotEmpty) {
      throw StateError('Match already started');
    }
    final seat = config.seats
        .where(
            (s) => s.control == SeatControl.onlineHuman && owners[s.id] == null)
        .firstOrNull;
    if (seat == null) throw StateError('Room is full');
    return MatchRoom(
        startedAt: startedAt,
        lastMoveAt: lastMoveAt,
        finishedAt: finishedAt,
        revision: revision,
        takeback: takeback,
        code: code,
        host: host,
        config: config,
        owners: {...owners, seat.id: uid},
        styles: {...styles, seat.id: style},
        boardTheme: boardTheme,
        moves: moves,
        aiRunner: aiRunner,
        aiLeaseAt: aiLeaseAt,
        clock: clock,
        timedOut: timedOut);
  }

  MatchRoom append(String uid, int expectedPly, MatchMove move,
      {DateTime? now, int expectedRevision = 0}) {
    final game = replay();
    if (game.ply != expectedPly || revision != expectedRevision) {
      throw StaleMatchMove();
    }
    if (!canMove(uid, game, now: now) || MatchRules.play(game, move) == null) {
      throw StateError('Stale, unauthorized or illegal move');
    }
    return MatchRoom(
        startedAt: startedAt,
        lastMoveAt: lastMoveAt,
        finishedAt: finishedAt,
        revision: config.court ? revision + 1 : revision,
        takeback: takeback,
        code: code,
        host: host,
        config: config,
        owners: owners,
        styles: styles,
        boardTheme: boardTheme,
        moves: [...moves, move.toMap(game.current)],
        aiRunner: aiRunner,
        aiLeaseAt: aiLeaseAt,
        clock: clock?.advance(
            game.current, config.next(game.current), now ?? DateTime.now()));
  }

  MatchRoom resign(String uid, SeatId seat) {
    if (owners[seat] != uid ||
        !ready ||
        takeback != null ||
        replay().finished) {
      throw StateError('Cannot resign this player');
    }
    return MatchRoom(
        startedAt: startedAt,
        lastMoveAt: lastMoveAt,
        finishedAt: finishedAt,
        revision: config.court ? revision + 1 : revision,
        takeback: takeback,
        code: code,
        host: host,
        config: config,
        owners: owners,
        styles: styles,
        boardTheme: boardTheme,
        moves: moves,
        resigned: seat,
        aiRunner: aiRunner,
        aiLeaseAt: aiLeaseAt,
        clock: clock);
  }

  MatchRoom updateTakeback(
      String uid, int expectedRevision, CourtTakebackAction action) {
    if (!config.court ||
        !ready ||
        !humanOwners.contains(uid) ||
        revision != expectedRevision) {
      throw StateError('Stale or unauthorized Court decision');
    }
    CourtTakeback? decision = takeback;
    List<Map<String, dynamic>> records = moves;
    var rewound = false;
    switch (action) {
      case CourtTakebackAction.request:
        if (decision != null) throw StateError('A takeback is already pending');
        final index = moves.lastIndexWhere((move) =>
            owners[SeatId.values.byName(move['seat'] as String)] == uid);
        if (index < 0) throw StateError('No human move to take back');
        decision = CourtTakeback(
            requestedBy: uid,
            baseRevision: revision,
            retained: moves.take(index).toList(),
            removed: moves.skip(index).toList(),
            approvals: [uid]);
      case CourtTakebackAction.approve:
        if (decision == null ||
            (decision.approvals.contains(uid) && humanOwners.length != 1)) {
          throw StateError('No takeback awaiting your agreement');
        }
        if (!decision.approvals.contains(uid)) decision = decision.approve(uid);
      case CourtTakebackAction.decline:
        if (decision == null || decision.requestedBy == uid) {
          throw StateError('No takeback to decline');
        }
        decision = null;
      case CourtTakebackAction.cancel:
        if (decision == null || decision.requestedBy != uid) {
          throw StateError('Only the requester can cancel');
        }
        decision = null;
    }
    if (action == CourtTakebackAction.approve &&
        decision != null &&
        decision.approvals.toSet().containsAll(humanOwners)) {
      records = decision.retained;
      decision = null;
      rewound = true;
    }
    return MatchRoom(
        code: code,
        host: host,
        config: config,
        owners: owners,
        styles: styles,
        boardTheme: boardTheme,
        moves: records,
        revision: revision + 1,
        takeback: decision,
        resigned: rewound ? null : resigned,
        timedOut: rewound ? null : timedOut,
        clock: clock,
        aiRunner: aiRunner,
        aiLeaseAt: aiLeaseAt,
        startedAt: startedAt,
        lastMoveAt: lastMoveAt,
        finishedAt: rewound ? null : finishedAt);
  }

  Map<String, dynamic> toMap() => {
        'startedAt': startedAt?.toUtc().toIso8601String(),
        'lastMoveAt': lastMoveAt?.toUtc().toIso8601String(),
        'finishedAt': finishedAt?.toUtc().toIso8601String(),
        if (config.court) 'revision': revision,
        if (takeback != null) 'takeback': takeback!.toMap(),
        'version': 1,
        'code': code,
        'host': host,
        'config': config.toMap(),
        'owners': {
          for (final entry in owners.entries) entry.key.name: entry.value
        },
        'styles': {
          for (final entry in styles.entries) entry.key.name: entry.value.name
        },
        'boardTheme': boardTheme.name,
        'moves': moves,
        'resigned': resigned?.name,
        'aiRunner': aiRunner,
        'aiLeaseAt': aiLeaseAt?.toUtc().toIso8601String(),
        'clock': clock?.toMap(),
        'timedOut': timedOut?.name,
      };

  factory MatchRoom.fromMap(Map<String, dynamic> map) {
    if (map['version'] != 1) {
      throw const FormatException('Unsupported room version');
    }
    final config =
        MatchConfig.fromMap(Map<String, dynamic>.from(map['config']));
    if ((map['clock'] == null) != (config.clockSeconds == 0)) {
      throw const FormatException('Room clock does not match configuration');
    }
    final owners = Map<String, dynamic>.from(map['owners']);
    final styles = Map<String, dynamic>.from(map['styles']);
    return MatchRoom(
        revision: map['revision'] as int? ?? 0,
        takeback: map['takeback'] == null
            ? null
            : CourtTakeback.fromMap(Map<String, dynamic>.from(map['takeback'])),
        startedAt:
            map['startedAt'] == null ? null : DateTime.parse(map['startedAt']),
        lastMoveAt: map['lastMoveAt'] == null
            ? null
            : DateTime.parse(map['lastMoveAt']),
        finishedAt: map['finishedAt'] == null
            ? null
            : DateTime.parse(map['finishedAt']),
        code: map['code'] as String,
        host: map['host'] as String,
        config: config,
        owners: owners.map((key, value) =>
            MapEntry(SeatId.values.byName(key), value as String?)),
        styles: styles.map((key, value) => MapEntry(SeatId.values.byName(key),
            PieceStyle.values.byName(value as String))),
        boardTheme: BoardTheme.values.byName(map['boardTheme'] as String),
        moves: (map['moves'] as List)
            .map((m) => Map<String, dynamic>.from(m))
            .toList(),
        resigned: map['resigned'] == null
            ? null
            : SeatId.values.byName(map['resigned'] as String),
        aiRunner: map['aiRunner'] as String?,
        clock: map['clock'] == null
            ? null
            : MatchClock.fromMap(Map<String, dynamic>.from(map['clock'])),
        timedOut: map['timedOut'] == null
            ? null
            : SeatId.values.byName(map['timedOut'] as String),
        aiLeaseAt: map['aiLeaseAt'] == null
            ? null
            : DateTime.parse(map['aiLeaseAt'] as String));
  }

  static bool _equal(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every((key) => b.containsKey(key) && _equal(a[key], b[key]));
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(a.length, (i) => i).every((i) => _equal(a[i], b[i]));
    }
    return a == b;
  }
}

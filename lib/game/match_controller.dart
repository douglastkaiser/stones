import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'match_ai.dart';
import 'match_coaching.dart';
import 'match_clock.dart';
import 'match_config.dart';
import 'match_room.dart';
import 'match_room_store.dart';
import 'match_rules.dart';
import 'match_state.dart';
import 'match_storage.dart';

class MatchSession {
  const MatchSession(
      {this.game,
      this.room,
      this.id,
      this.uid,
      this.busy = false,
      this.connected = true,
      this.paused = false,
      this.explanation,
      this.inputLocked = false,
      this.clock,
      this.error});
  final MatchState? game;
  final MatchRoom? room;
  final String? id;
  final String? uid;
  final bool busy;
  final bool connected;
  final bool paused;
  final String? error;
  final String? explanation;
  final bool inputLocked;
  final MatchClock? clock;
  bool get ready => game != null && (room?.ready ?? true);
  bool get canPlay =>
      ready &&
      connected &&
      !busy &&
      !inputLocked &&
      !(clock?.expired(game!.current, DateTime.now()) ?? false) &&
      !(clock != null && paused && room == null) &&
      !game!.finished &&
      game!.config.seat(game!.current).control != SeatControl.ai &&
      (room == null || room!.owners[game!.current] == uid);
  MatchSession copyWith(
          {MatchState? game,
          MatchRoom? room,
          bool? busy,
          bool? connected,
          bool? paused,
          String? explanation,
          bool? inputLocked,
          MatchClock? clock,
          String? error}) =>
      MatchSession(
          game: game ?? this.game,
          room: room ?? this.room,
          id: id,
          uid: uid,
          busy: busy ?? this.busy,
          connected: connected ?? this.connected,
          paused: paused ?? this.paused,
          explanation: explanation ?? this.explanation,
          inputLocked: inputLocked ?? this.inputLocked,
          clock: clock ?? this.clock,
          error: error);
}

class MatchController extends StateNotifier<MatchSession> {
  MatchController(
      {required this.storage,
      required this.authenticate,
      required this.store,
      this.remember,
      this.completed,
      this.botDelay = const Duration(milliseconds: 250),
      Future<MatchMove?> Function(MatchState, BotLevel)? search})
      : _searchOverride = search,
        super(const MatchSession());
  final LocalMatchStorage storage;
  final Future<String> Function() authenticate;
  final MatchRoomStore Function() store;
  final Future<void> Function(MatchRoom, String)? remember;
  final Future<void> Function(MatchSession)? completed;
  final Set<String> _completionPending = {};
  final Set<String> _completionHandled = {};
  final Duration botDelay;
  final Future<MatchMove?> Function(MatchState, BotLevel)? _searchOverride;
  Future<MatchMove?> search(MatchState game, BotLevel level) {
    if (_searchOverride != null) return _searchOverride!(game, level);
    final epoch = _epoch;
    final token = _searchToken;
    return selectMatchMove(game, level,
        cancelled: () => !mounted || epoch != _epoch || token != _searchToken);
  }

  StreamSubscription<MatchRoomUpdate>? _subscription;
  Timer? _timer;
  Timer? _clockTimer;
  bool _localWritePending = false;
  bool _expiryPending = false;
  int _epoch = 0;
  int _searchToken = 0;
  int? _searchingPly;
  int? _searchingToken;
  int? _awaitingPly;
  bool _leaseBusy = false;
  List<Map<String, dynamic>> _localMoves = [];

  void leave() {
    _epoch++;
    _searchToken++;
    _timer?.cancel();
    _clockTimer?.cancel();
    _localWritePending = false;
    _expiryPending = false;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _awaitingPly = null;
    _leaseBusy = false;
    if (mounted) state = const MatchSession();
  }

  Future<void> start(MatchConfig config) async {
    leave();
    final epoch = _epoch;
    if (config.online) {
      state = const MatchSession(busy: true);
      try {
        final uid = await authenticate();
        if (!mounted || epoch != _epoch) return;
        final room = await store().create(uid, config);
        await remember?.call(room, uid);
        if (!mounted || epoch != _epoch) return;
        state = MatchSession(id: room.code, uid: uid);
        _accept(room);
        _subscribe(room.code);
      } catch (error) {
        if (mounted && epoch == _epoch) state = MatchSession(error: '$error');
        rethrow;
      }
    } else {
      _localMoves = [];
      final id =
          'local-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
      state = MatchSession(
          game: MatchState.initial(config),
          id: id,
          busy: true,
          clock: config.clockSeconds > 0 ? MatchClock.initial(config) : null);
      try {
        await _save();
      } catch (error) {
        if (mounted && epoch == _epoch) {
          state = MatchSession(error: 'Could not save the new game: $error');
        }
        rethrow;
      }
      if (!mounted || epoch != _epoch) return;
      state = state.copyWith(busy: false);
      _watchClock();
      _schedule();
    }
  }

  Future<bool> resumeLocal() async {
    leave();
    final epoch = _epoch;
    final snapshot = await storage.read();
    if (snapshot == null || !mounted || epoch != _epoch) return false;
    final config =
        MatchConfig.fromMap(Map<String, dynamic>.from(snapshot['config']));
    if (config.online) {
      throw const FormatException('Online games resume through their room');
    }
    var game = MatchState.initial(config);
    final records = (snapshot['moves'] as List)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    for (final record in records) {
      if (record['seat'] != game.current.name) {
        throw const FormatException('Saved turn mismatch');
      }
      final next = MatchRules.play(game, MatchMove.fromMap(record));
      if (next == null) throw const FormatException('Saved move is illegal');
      game = next;
    }
    if (snapshot['result'] != null) {
      final result = Map<String, dynamic>.from(snapshot['result']);
      final reason = ResultReason.values.byName(result['reason'] as String);
      if (game.finished ||
          ![ResultReason.time, ResultReason.resignation, ResultReason.abandoned]
              .contains(reason)) {
        throw const FormatException('Invalid saved termination');
      }
      game = game.copyWith(
          result: MatchResult(
              result['winner'] == null
                  ? null
                  : SeatId.values.byName(result['winner'] as String),
              reason));
    }
    _localMoves = records;
    final clock = snapshot['clock'] == null
        ? null
        : MatchClock.fromMap(Map<String, dynamic>.from(snapshot['clock']));
    if ((clock == null) != (config.clockSeconds == 0) ||
        (clock != null &&
            (clock.bank.length != config.ids.length ||
                config.ids.any((id) => !clock.bank.containsKey(id)) ||
                clock.bank.values
                    .any((ms) => ms > config.clockSeconds * 1000)))) {
      throw const FormatException('Saved clock does not match configuration');
    }
    state = MatchSession(
        game: game, id: snapshot['id'] as String, paused: true, clock: clock);
    _watchClock();
    _notifyCompleted();
    return true;
  }

  Future<void> join(String code, {String? expectedUid}) async {
    leave();
    final epoch = _epoch;
    state = const MatchSession(busy: true);
    try {
      final normalized = code.trim().toUpperCase();
      if (!RegExp(r'^U[A-Z]{6}$').hasMatch(normalized)) {
        throw StateError('Enter the seven-letter room code beginning with U');
      }
      final uid = await authenticate();
      if (!mounted || epoch != _epoch) return;
      if (expectedUid != null && uid != expectedUid) {
        throw StateError(
            'Use the original account or browser profile to resume');
      }
      final room = expectedUid == null
          ? await store().join(normalized, uid)
          : await store().read(normalized);
      if (room.host != uid && !room.owners.values.contains(uid)) {
        throw StateError('This identity does not own a seat');
      }
      await remember?.call(room, uid);
      if (!mounted || epoch != _epoch) return;
      state = MatchSession(id: room.code, uid: uid);
      _accept(room);
      _subscribe(room.code);
    } catch (error) {
      if (mounted && epoch == _epoch) state = MatchSession(error: '$error');
      rethrow;
    }
  }

  void _subscribe(String code) {
    final epoch = _epoch;
    _subscription = store().watch(code).listen((update) {
      if (!mounted || epoch != _epoch) return;
      if (!update.confirmed) {
        if (!update.connected) {
          _timer?.cancel();
          _searchToken++;
        }
        state = state.copyWith(connected: update.connected);
        return;
      }
      try {
        _accept(update.room!);
      } catch (error) {
        state = state.copyWith(connected: false, busy: false, error: '$error');
      }
    }, onError: (Object error) {
      if (!mounted || epoch != _epoch) return;
      _timer?.cancel();
      _searchToken++;
      state = state.copyWith(connected: false, busy: false, error: '$error');
    });
  }

  void _accept(MatchRoom room) {
    if (state.room != null && room.moves.length < state.room!.moves.length) {
      return;
    }
    final game = state.room == null
        ? room.replay()
        : room.replayAfter(state.room!, state.game!);
    if (_awaitingPly != null && game.ply >= _awaitingPly!) _awaitingPly = null;
    state = state.copyWith(
        game: game,
        room: room,
        clock: room.clock,
        connected: true,
        busy: _awaitingPly != null ||
            (_searchingToken == _searchToken && _searchingPly == game.ply));
    _notifyCompleted();
    _watchClock();
    _schedule();
  }

  void _notifyCompleted() {
    if (completed == null || state.game?.finished != true || state.id == null) {
      return;
    }
    final key =
        '${state.id}:${state.game!.ply}:${state.game!.result!.reason.name}';
    if (_completionHandled.contains(key) || !_completionPending.add(key)) {
      return;
    }
    final snapshot = state;
    final epoch = _epoch;
    unawaited(completed!(snapshot).then((value) {
      _completionHandled.add(key);
    }).catchError((Object error) {
      if (mounted && epoch == _epoch) {
        state = state.copyWith(
            error: 'Game saved; reward update needs a retry: $error');
      }
    }).whenComplete(() => _completionPending.remove(key)));
  }

  Future<bool> play(MatchMove move, {bool bot = false}) async {
    final game = state.game;
    if (game == null ||
        !state.ready ||
        !state.connected ||
        state.busy ||
        (state.clock?.expired(game.current, DateTime.now()) ?? false) ||
        game.finished) {
      return false;
    }
    final ai = game.config.seat(game.current).control == SeatControl.ai;
    if (bot != ai ||
        (!bot && !state.canPlay) ||
        (bot &&
            state.room != null &&
            !state.room!.runsAI(state.uid!, DateTime.now()))) {
      return false;
    }
    final result = MatchRules.play(game, move);
    if (result == null) return false;
    final epoch = _epoch;
    state = state.copyWith(busy: true);
    try {
      final room = state.room;
      if (room == null) {
        _localWritePending = true;
        final records = [..._localMoves, move.toMap(game.current)];
        final now = DateTime.now();
        final clock = state.clock?.advance(game.current, result.current, now);
        await storage.write({
          'id': state.id,
          'config': game.config.toMap(),
          'moves': records,
          if (clock != null) 'clock': clock.frozen(now).toMap(),
        });
        if (!mounted || epoch != _epoch) return true;
        _localMoves = records;
        _localWritePending = false;
        state = state.copyWith(
            game: result,
            clock: result.finished || state.paused ? clock?.frozen(now) : clock,
            explanation: game.config.court && bot
                ? MatchCoaching.explain(game, move)
                : null);
      } else {
        _awaitingPly = game.ply + 1;
        await store().submit(room.code, state.uid!, game.ply, move);
      }
      if (!mounted || epoch != _epoch) return true;
      state = state.copyWith(busy: _awaitingPly != null);
      _schedule();
      _notifyCompleted();
      return true;
    } catch (error) {
      if (mounted && epoch == _epoch) {
        _localWritePending = false;
        _awaitingPly = null;
        state = state.copyWith(busy: false, error: '$error');
      }
      return false;
    }
  }

  Future<void> _save() => storage.write({
        'id': state.id,
        'config': state.game!.config.toMap(),
        'moves': _localMoves,
        if (state.clock != null)
          'clock': state.clock!.frozen(DateTime.now()).toMap(),
        if (state.game!.result != null &&
            [
              ResultReason.time,
              ResultReason.resignation,
              ResultReason.abandoned
            ].contains(state.game!.result!.reason))
          'result': {
            'winner': state.game!.result!.winner?.name,
            'reason': state.game!.result!.reason.name
          },
      });

  void _watchClock() {
    _clockTimer?.cancel();
    if (state.clock == null || state.game!.finished) return;
    var ticks = 0;
    _clockTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted || state.game == null || state.game!.finished) {
        timer.cancel();
        return;
      }
      if (state.room == null && state.paused) return;
      if (state.clock!.expired(state.game!.current, DateTime.now()) &&
          !_localWritePending &&
          _awaitingPly == null) {
        unawaited(_expireClock());
      } else if (++ticks % 20 == 0 &&
          state.room == null &&
          !state.busy &&
          !state.paused) {
        unawaited(_save().catchError((Object error) {
          if (mounted) {
            state = state.copyWith(
                error: 'Clock checkpoint could not be saved: $error');
          }
        }));
      }
    });
  }

  Future<void> _expireClock() async {
    if (_expiryPending || state.game == null || !state.connected) return;
    _expiryPending = true;
    final epoch = _epoch;
    final game = state.game!;
    _searchToken++;
    _timer?.cancel();
    state = state.copyWith(busy: true);
    try {
      if (state.room != null) {
        await store().expire(state.room!.code, state.uid!);
      } else {
        final result = game.config.seats.length == 2
            ? MatchResult(game.config.next(game.current), ResultReason.time)
            : const MatchResult(null, ResultReason.abandoned);
        final clock = state.clock!.frozen(DateTime.now());
        await storage.write({
          'id': state.id,
          'config': game.config.toMap(),
          'moves': _localMoves,
          'clock': clock.toMap(),
          'result': {
            'winner': result.winner?.name,
            'reason': result.reason.name
          }
        });
        if (mounted && epoch == _epoch) {
          state = state.copyWith(
              game: game.copyWith(result: result), clock: clock, busy: false);
          _notifyCompleted();
        }
      }
    } catch (error) {
      if (mounted && epoch == _epoch) {
        state = state.copyWith(
            busy: false,
            paused: state.room == null,
            error: 'Clock expiry awaits confirmation: $error');
      }
    } finally {
      if (mounted && epoch == _epoch) _expiryPending = false;
    }
  }

  Future<MatchMove?> hint() async {
    final game = state.game;
    if (game == null || !game.config.court || !state.canPlay) return null;
    final epoch = _epoch;
    final token = ++_searchToken;
    state = state.copyWith(busy: true);
    try {
      final move = await search(game, BotLevel.hard);
      if (!mounted || epoch != _epoch || token != _searchToken) return null;
      state = state.copyWith(
          busy: false,
          explanation: move == null
              ? 'No legal hint found.'
              : MatchCoaching.explain(game, move));
      return move;
    } catch (error) {
      if (mounted && epoch == _epoch && token == _searchToken) {
        state = state.copyWith(busy: false, error: 'Hint unavailable: $error');
      }
      return null;
    }
  }

  Future<bool> takeBack() async {
    final game = state.game;
    if (game == null ||
        !game.config.court ||
        state.room != null ||
        state.busy) {
      return false;
    }
    final index = _localMoves.lastIndexWhere((move) =>
        game.config
            .seat(SeatId.values.byName(move['seat'] as String))
            .control ==
        SeatControl.localHuman);
    if (index < 0) return false;
    final epoch = _epoch;
    _searchToken++;
    _timer?.cancel();
    final records = _localMoves.take(index).toList();
    var restored = MatchState.initial(game.config);
    for (final record in records) {
      restored = MatchRules.play(restored, MatchMove.fromMap(record))!;
    }
    state = state.copyWith(busy: true);
    try {
      await storage.write(
          {'id': state.id, 'config': game.config.toMap(), 'moves': records});
      if (!mounted || epoch != _epoch) return false;
      _localMoves = records;
      state = state.copyWith(
          game: restored,
          busy: false,
          paused: false,
          explanation:
              'Took back the last human move and the AI replies after it.');
      _schedule();
      return true;
    } catch (error) {
      if (mounted && epoch == _epoch) {
        state = state.copyWith(
            busy: false, error: 'Takeback could not be saved: $error');
      }
      return false;
    }
  }

  void pause(bool paused) {
    if (!mounted || state.game == null) return;
    _searchToken++;
    _timer?.cancel();
    final clock = state.room != null
        ? state.clock
        : paused
            ? state.clock?.frozen(DateTime.now())
            : state.game!.ply > 0
                ? state.clock?.begin(state.game!.current, DateTime.now())
                : state.clock;
    state = state.copyWith(
        paused: paused,
        clock: clock,
        busy: _awaitingPly != null || _localWritePending);
    if (state.room == null && state.game != null && !_localWritePending) {
      unawaited(_save().catchError((Object error) {
        if (mounted) {
          state = state.copyWith(error: 'Could not save paused clock: $error');
        }
      }));
    }
    _schedule();
  }

  /// Stop work immediately on navigation; defer notification past widget teardown.
  void suspend() {
    _timer?.cancel();
    final token = ++_searchToken;
    scheduleMicrotask(() {
      if (mounted && token == _searchToken) pause(true);
    });
  }

  bool get _botTurn =>
      state.ready &&
      state.connected &&
      !state.paused &&
      !state.busy &&
      !state.game!.finished &&
      state.game!.config.seat(state.game!.current).control == SeatControl.ai &&
      (state.room == null || state.room!.runsAI(state.uid!, DateTime.now()));

  void _schedule() {
    _timer?.cancel();
    if (state.game != null &&
        (state.clock?.expired(state.game!.current, DateTime.now()) ?? false)) {
      return;
    }
    if (_leaseBusy) return;
    final room = state.room;
    if (room != null &&
        state.ready &&
        state.connected &&
        !state.paused &&
        !state.busy &&
        !state.game!.finished &&
        state.game!.config.seat(state.game!.current).control ==
            SeatControl.ai &&
        (room.aiRunner != state.uid ||
            room.aiLeaseAt == null ||
            DateTime.now().isAfter(room.aiLeaseAt!
                .add(MatchRoom.leaseDuration - const Duration(seconds: 5))))) {
      final epoch = _epoch;
      final token = ++_searchToken;
      _timer = Timer(const Duration(seconds: 1), () async {
        if (!mounted || epoch != _epoch || token != _searchToken) return;
        if (room.runnerActive(DateTime.now()) && room.aiRunner != state.uid) {
          _schedule();
          return;
        }
        _leaseBusy = true;
        try {
          final claimed = await store().claimRunner(room.code, state.uid!);
          if (mounted && epoch == _epoch && token == _searchToken) {
            _accept(claimed);
          }
        } catch (error) {
          // A participant may have won the transaction. Re-read its lease.
          try {
            final latest = await store().read(room.code);
            if (mounted && epoch == _epoch && token == _searchToken) {
              _accept(latest);
            }
          } catch (readError) {
            if (mounted && epoch == _epoch) {
              state = state.copyWith(
                  connected: false,
                  error: 'Reconnect to continue AI: $readError');
            }
          }
        } finally {
          if (mounted && epoch == _epoch) {
            _leaseBusy = false;
            _schedule();
          }
        }
      });
      return;
    }
    if (!_botTurn) return;
    final epoch = _epoch;
    final token = ++_searchToken;
    final game = state.game!;
    _timer = Timer(botDelay, () async {
      if (!mounted || epoch != _epoch || token != _searchToken || !_botTurn) {
        return;
      }
      state = state.copyWith(busy: true);
      try {
        _searchingPly = game.ply;
        _searchingToken = token;
        final move = await search(game, game.config.seat(game.current).level);
        if (!mounted ||
            epoch != _epoch ||
            token != _searchToken ||
            state.game?.ply != game.ply ||
            state.paused) {
          return;
        }
        state = state.copyWith(busy: false);
        _searchingPly = null;
        _searchingToken = null;
        if (move != null) await play(move, bot: true);
      } catch (error) {
        if (mounted && epoch == _epoch && token == _searchToken) {
          state = state.copyWith(
              busy: false, paused: true, error: 'AI paused: $error');
        }
      }
    });
  }

  @override
  void dispose() {
    _epoch++;
    _searchToken++;
    _timer?.cancel();
    _clockTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

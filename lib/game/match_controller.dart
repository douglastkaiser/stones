import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'match_ai.dart';
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
      this.error});
  final MatchState? game;
  final MatchRoom? room;
  final String? id;
  final String? uid;
  final bool busy;
  final bool connected;
  final bool paused;
  final String? error;
  bool get ready => game != null && (room?.ready ?? true);
  bool get canPlay =>
      ready &&
      connected &&
      !busy &&
      !game!.finished &&
      game!.config.seat(game!.current).control != SeatControl.ai &&
      (room == null || room!.owners[game!.current] == uid);
  MatchSession copyWith(
          {MatchState? game,
          MatchRoom? room,
          bool? busy,
          bool? connected,
          bool? paused,
          String? error}) =>
      MatchSession(
          game: game ?? this.game,
          room: room ?? this.room,
          id: id,
          uid: uid,
          busy: busy ?? this.busy,
          connected: connected ?? this.connected,
          paused: paused ?? this.paused,
          error: error);
}

class MatchController extends StateNotifier<MatchSession> {
  MatchController(
      {required this.storage,
      required this.authenticate,
      required this.store,
      this.remember,
      this.botDelay = const Duration(milliseconds: 250),
      Future<MatchMove?> Function(MatchState, BotLevel)? search})
      : search = search ?? ((game, level) => selectMatchMove(game, level)),
        super(const MatchSession());
  final LocalMatchStorage storage;
  final Future<String> Function() authenticate;
  final MatchRoomStore Function() store;
  final Future<void> Function(MatchRoom, String)? remember;
  final Duration botDelay;
  final Future<MatchMove?> Function(MatchState, BotLevel) search;
  StreamSubscription<MatchRoomUpdate>? _subscription;
  Timer? _timer;
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
      state =
          MatchSession(game: MatchState.initial(config), id: id, busy: true);
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
    _localMoves = records;
    state =
        MatchSession(game: game, id: snapshot['id'] as String, paused: true);
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
        connected: true,
        busy: _awaitingPly != null ||
            (_searchingToken == _searchToken && _searchingPly == game.ply));
    _schedule();
  }

  Future<bool> play(MatchMove move, {bool bot = false}) async {
    final game = state.game;
    if (game == null ||
        !state.ready ||
        !state.connected ||
        state.busy ||
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
        final records = [..._localMoves, move.toMap(game.current)];
        await storage.write({
          'id': state.id,
          'config': game.config.toMap(),
          'moves': records,
        });
        if (!mounted || epoch != _epoch) return true;
        _localMoves = records;
        state = state.copyWith(game: result);
      } else {
        _awaitingPly = game.ply + 1;
        await store().submit(room.code, state.uid!, game.ply, move);
      }
      if (!mounted || epoch != _epoch) return true;
      state = state.copyWith(busy: _awaitingPly != null);
      _schedule();
      return true;
    } catch (error) {
      if (mounted && epoch == _epoch) {
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
      });

  void pause(bool paused) {
    if (!mounted) return;
    _searchToken++;
    _timer?.cancel();
    state = state.copyWith(paused: paused, busy: _awaitingPly != null);
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
          if (mounted && epoch == _epoch && token == _searchToken)
            _accept(claimed);
        } catch (error) {
          // A participant may have won the transaction. Re-read its lease.
          try {
            final latest = await store().read(room.code);
            if (mounted && epoch == _epoch && token == _searchToken)
              _accept(latest);
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
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

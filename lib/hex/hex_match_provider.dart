import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/online_game_provider.dart';
import 'hex_ai.dart';
import 'hex_game.dart';
import 'hex_room.dart';
import 'hex_room_store.dart';

class HexMatchState {
  const HexMatchState(
      {this.game,
      this.room,
      this.kinds = const [],
      this.controls = const {},
      this.busy = false,
      this.connected = true,
      this.paused = false,
      this.error});
  final HexGame? game;
  final HexRoom? room;
  final List<HexSeatKind> kinds;
  final Set<HexSeat> controls;
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
      controls.contains(game!.current);
}

class HexMatchController extends StateNotifier<HexMatchState> {
  HexMatchController(
      {required this.authenticate,
      required this.store,
      this.botDelay = const Duration(milliseconds: 450)})
      : super(const HexMatchState());
  final Future<String> Function() authenticate;
  final HexRoomStore Function() store;
  final Duration botDelay;
  StreamSubscription<HexRoom>? _subscription;
  Timer? _botTimer;
  String? _uid;
  int _epoch = 0;
  int? _awaitingPly;

  void startLocal(int radius, List<HexSeatKind> kinds, HexSeat starter) {
    if (kinds.length != 3 || kinds.contains(HexSeatKind.remoteHuman)) {
      throw ArgumentError('Local matches need three local human/AI seats');
    }
    leave();
    state = HexMatchState(
        game: HexGame.initial(radius: radius, starter: starter),
        kinds: List.unmodifiable(kinds),
        controls: HexSeat.values
            .where((seat) => kinds[seat.index] == HexSeatKind.localHuman)
            .toSet());
    _scheduleBot();
  }

  Future<void> create(
      int radius, List<HexSeatKind> kinds, HexSeat starter) async {
    leave();
    final epoch = _epoch;
    _publish(busy: true);
    try {
      final uid = await authenticate();
      final room = await store().create(uid, radius, kinds, starter);
      if (!mounted || epoch != _epoch) return;
      _uid = uid;
      _accept(room);
      _subscribe(room.code);
    } catch (error) {
      if (mounted && epoch == _epoch) {
        _publish(busy: false, error: _message(error));
      }
    }
  }

  Future<void> join(String code) async {
    leave();
    final epoch = _epoch;
    _publish(busy: true);
    try {
      final normalized = code.trim().toUpperCase();
      if (!RegExp(r'^H[A-Z]{6}$').hasMatch(normalized)) {
        throw StateError(
            'Enter the seven-letter hex room code beginning with H');
      }
      final uid = await authenticate();
      final room = await store().join(normalized, uid);
      if (!mounted || epoch != _epoch) return;
      _uid = uid;
      _accept(room);
      _subscribe(room.code);
    } catch (error) {
      if (mounted && epoch == _epoch) {
        _publish(busy: false, error: _message(error));
      }
    }
  }

  void _subscribe(String code) {
    final epoch = _epoch;
    _subscription = store().watch(code).listen((room) {
      if (!mounted || epoch != _epoch) return;
      try {
        _accept(room);
      } catch (error) {
        _publish(connected: false, busy: false, error: _message(error));
      }
    }, onError: (Object error) {
      if (!mounted || epoch != _epoch) return;
      _botTimer?.cancel();
      _publish(connected: false, busy: false, error: _message(error));
    });
  }

  void _accept(HexRoom room) {
    // Replay every record, including terminal results. Never advance past a bad
    // record, silently skip moves, or accept an unsupported rules version.
    final game = room.replay();
    if (state.room?.code == room.code && game.ply < state.game!.ply) return;
    if (_awaitingPly != null && game.ply >= _awaitingPly!) _awaitingPly = null;
    state = HexMatchState(
        game: game,
        room: room,
        kinds: room.kinds,
        controls: room.controlledBy(_uid!),
        busy: _awaitingPly != null,
        paused: state.paused);
    _scheduleBot();
  }

  Future<bool> play(HexMove move, {bool bot = false}) async {
    final game = state.game;
    if (game == null ||
        !state.ready ||
        !state.connected ||
        state.busy ||
        game.finished) {
      return false;
    }
    final room = state.room;
    final isBot = state.kinds[game.current.index] == HexSeatKind.ai;
    if (bot != isBot ||
        (!bot && !state.controls.contains(game.current)) ||
        (bot && room != null && room.host != _uid)) {
      return false;
    }
    final result = HexRules.play(game, move);
    if (result == null) {
      _publish(error: 'That move is not legal');
      return false;
    }
    final epoch = _epoch;
    _publish(busy: true);
    try {
      if (room != null) {
        _awaitingPly = game.ply + 1;
        await store().submit(room.code, _uid!, game.ply, move);
        // The acknowledged room snapshot owns the resulting board. No local
        // optimistic move can diverge from transaction replay.
      } else {
        state = HexMatchState(
            game: result,
            kinds: state.kinds,
            controls: state.controls,
            paused: state.paused);
      }
      if (mounted && epoch == _epoch) {
        _publish(busy: _awaitingPly != null);
        _scheduleBot();
      }
      return true;
    } catch (error) {
      if (mounted && epoch == _epoch) {
        _awaitingPly = null;
        _publish(busy: false, error: _message(error));
      }
      return false;
    }
  }

  bool get _botTurn =>
      state.ready &&
      state.connected &&
      !state.busy &&
      !state.paused &&
      !state.game!.finished &&
      state.kinds[state.game!.current.index] == HexSeatKind.ai &&
      (state.room == null || state.room!.host == _uid);

  void _scheduleBot() {
    _botTimer?.cancel();
    if (!_botTurn) return;
    final game = state.game!;
    final epoch = _epoch;
    _botTimer = Timer(botDelay, () async {
      _publish(busy: true);
      try {
        final move = kIsWeb
            ? await HexAI.chooseResponsive(game,
                cancelled: () =>
                    !mounted ||
                    epoch != _epoch ||
                    state.game?.ply != game.ply ||
                    state.paused)
            : await compute(HexAI.choose, game);
        if (!mounted ||
            epoch != _epoch ||
            state.game?.ply != game.ply ||
            state.paused) {
          return;
        }
        _publish(busy: false);
        if (move != null) {
          await play(move, bot: true);
        } else {
          _publish(error: 'AI has no legal move');
        }
      } catch (error) {
        if (mounted && epoch == _epoch) {
          _publish(busy: false, error: _message(error));
        }
      }
    });
  }

  void togglePause() {
    if (state.room != null) return;
    _epoch++;
    _botTimer?.cancel();
    state = HexMatchState(
        game: state.game,
        kinds: state.kinds,
        controls: state.controls,
        paused: !state.paused);
    _scheduleBot();
  }

  void _publish({bool? busy, bool? connected, String? error}) {
    if (!mounted) return;
    state = HexMatchState(
        game: state.game,
        room: state.room,
        kinds: state.kinds,
        controls: state.controls,
        busy: busy ?? state.busy,
        connected: connected ?? state.connected,
        paused: state.paused,
        error: error);
  }

  String _message(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Room access denied. Hex multiplayer rules must be deployed on the server.',
        'unavailable' => 'Connection lost. Rejoin the room to reconnect.',
        _ => 'Could not connect (${error.code}). Try again.',
      };
    }
    if (error is StateError) return error.message.toString();
    if (error is FormatException) return 'Invalid room data: ${error.message}';
    return 'Could not load this match. Try again.';
  }

  void leave({bool notify = true}) {
    _epoch++;
    _botTimer?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    _uid = null;
    _awaitingPly = null;
    if (!mounted) return;
    if (notify) {
      state = const HexMatchState();
    } else {
      // Consumer listeners are still attached during widget disposal. Notify
      // only after unmount, and never clear a newer match started meanwhile.
      final epoch = _epoch;
      scheduleMicrotask(() {
        if (mounted && epoch == _epoch) state = const HexMatchState();
      });
    }
  }

  @override
  void dispose() {
    _epoch++;
    _botTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final hexMatchProvider =
    StateNotifierProvider<HexMatchController, HexMatchState>((ref) {
  return HexMatchController(
      authenticate: () async {
        await ref.read(onlineGameProvider.notifier).initialize();
        final error = ref.read(onlineGameProvider).errorMessage;
        if (error != null) throw StateError(error);
        final user = FirebaseAuth.instance.currentUser ??
            (await FirebaseAuth.instance.signInAnonymously()).user;
        if (user == null) throw StateError('Sign in to join a hex match');
        return user.uid;
      },
      store: () => FirestoreHexRoomStore(FirebaseFirestore.instance));
});

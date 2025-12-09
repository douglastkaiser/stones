
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase_options.dart';
import '../models/models.dart';
import '../services/services.dart';

class OnlineGameState {
  final bool initializing;
  final bool creating;
  final bool joining;
  final OnlineGameSession? session;
  final String? roomCode;
  final PlayerColor? localColor;
  final bool opponentInactive;
  final String? errorMessage;
  final int appliedMoveCount;

  const OnlineGameState({
    this.initializing = false,
    this.creating = false,
    this.joining = false,
    this.session,
    this.roomCode,
    this.localColor,
    this.opponentInactive = false,
    this.errorMessage,
    this.appliedMoveCount = 0,
  });

  bool get isLocalTurn =>
      session != null && localColor != null && session!.currentTurn == localColor;

  bool get waitingForOpponent => session?.status == OnlineStatus.waiting;

  OnlineGameState copyWith({
    bool? initializing,
    bool? creating,
    bool? joining,
    OnlineGameSession? session,
    String? roomCode,
    PlayerColor? localColor,
    bool? opponentInactive,
    String? errorMessage,
    int? appliedMoveCount,
    bool clearError = false,
  }) {
    return OnlineGameState(
      initializing: initializing ?? this.initializing,
      creating: creating ?? this.creating,
      joining: joining ?? this.joining,
      session: session ?? this.session,
      roomCode: roomCode ?? this.roomCode,
      localColor: localColor ?? this.localColor,
      opponentInactive: opponentInactive ?? this.opponentInactive,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      appliedMoveCount: appliedMoveCount ?? this.appliedMoveCount,
    );
  }
}

class OnlineGameController extends StateNotifier<OnlineGameState> {
  OnlineGameController(this._ref) : super(const OnlineGameState());

  final Ref _ref;
  final _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  Future<void> initialize() async {
    if (state.initializing) return;
    state = state.copyWith(initializing: true, clearError: true);
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      await _ensureAuth();
    } finally {
      state = state.copyWith(initializing: false);
    }
  }

  Future<void> createGame({required int boardSize}) async {
    await initialize();
    state = state.copyWith(creating: true, clearError: true);
    try {
      final user = FirebaseAuth.instance.currentUser ??
          (await _ensureAuth(force: true));
      if (user == null) {
        throw Exception('Unable to authenticate with Play Games.');
      }

      final code = _generateRoomCode();
      final player = _playerFor(user);
      final session = OnlineGameSession(
        roomCode: code,
        white: player,
        boardSize: boardSize,
        moves: const [],
        status: OnlineStatus.waiting,
      );
      await _firestore.collection('games').doc(code).set(session.toMap());
      _listenToRoom(code, localColor: PlayerColor.white);
      state = state.copyWith(
        session: session,
        roomCode: code,
        localColor: PlayerColor.white,
        appliedMoveCount: 0,
      );
      _beginLocalGame(boardSize);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(creating: false);
    }
  }

  Future<void> joinGame(String roomCode) async {
    await initialize();
    state = state.copyWith(joining: true, clearError: true);
    final code = roomCode.toUpperCase();
    try {
      final user = FirebaseAuth.instance.currentUser ??
          (await _ensureAuth(force: true));
      if (user == null) {
        throw Exception('Unable to authenticate with Play Games.');
      }

      final docRef = _firestore.collection('games').doc(code);
      int? boardSize;
      await _firestore.runTransaction((txn) async {
        final snapshot = await txn.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Room not found.');
        }
        final data = snapshot.data();
        if (data == null) throw Exception('Room data missing.');
        final existing = OnlineGameSession.fromSnapshot(code, data);
        boardSize = existing.boardSize;
        if (existing.black != null && existing.black!.id != user.uid) {
          throw Exception('Room already has two players.');
        }

        final updated = existing.copyWith(
          black: existing.black ?? _playerFor(user),
          status: OnlineStatus.playing,
        );
        txn.update(docRef, {
          'black': updated.black?.toMap(),
          'status': updated.status.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _listenToRoom(code, localColor: PlayerColor.black);
      state = state.copyWith(roomCode: code, localColor: PlayerColor.black);
      _beginLocalGame(boardSize ?? 5);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(joining: false);
    }
  }

  Future<void> leaveRoom() async {
    await _subscription?.cancel();
    _subscription = null;
    state = const OnlineGameState();
  }

  Future<void> recordLocalMove(MoveRecord move, GameState latestState) async {
    final activeSession = state.session;
    if (activeSession == null || state.localColor == null) return;

    final docRef = _firestore.collection('games').doc(activeSession.roomCode);
    final nextStatus = latestState.isGameOver
        ? OnlineStatus.finished.name
        : OnlineStatus.playing.name;
    final winner = latestState.result == null
        ? null
        : latestState.result == GameResult.draw
            ? OnlineWinner.draw.name
            : latestState.result == GameResult.whiteWins
                ? OnlineWinner.white.name
                : OnlineWinner.black.name;

    await _firestore.runTransaction((txn) async {
      final snapshot = await txn.get(docRef);
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;
      final moves = List<Map<String, dynamic>>.from(data['moves'] as List? ?? []);
      moves.add(
        OnlineGameMove(
          notation: move.notation,
          player: state.localColor!,
        ).toMap(),
      );

      txn.update(docRef, {
        'moves': moves,
        'currentTurn': latestState.currentPlayer.name,
        'status': nextStatus,
        'winner': winner,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    state = state.copyWith(appliedMoveCount: state.appliedMoveCount + 1);
  }

  Future<void> resign() async {
    final activeSession = state.session;
    if (activeSession == null || state.localColor == null) return;
    final docRef = _firestore.collection('games').doc(activeSession.roomCode);
    final winner = state.localColor == PlayerColor.white
        ? OnlineWinner.black.name
        : OnlineWinner.white.name;
    await docRef.update({
      'status': OnlineStatus.finished.name,
      'winner': winner,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> requestRematch() async {
    final activeSession = state.session;
    if (activeSession == null) return;
    final docRef = _firestore.collection('games').doc(activeSession.roomCode);
    await docRef.update({
      'moves': <Map<String, dynamic>>[],
      'status': OnlineStatus.waiting.name,
      'winner': null,
      'currentTurn': PlayerColor.white.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    state = state.copyWith(appliedMoveCount: 0);
    _beginLocalGame(activeSession.boardSize);
  }

  Future<void> _listenToRoom(String roomCode, {required PlayerColor localColor}) async {
    await _subscription?.cancel();
    _subscription = _firestore
        .collection('games')
        .doc(roomCode)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;
      final session = OnlineGameSession.fromSnapshot(roomCode, data);
      final opponentInactive = _isOpponentInactive(session);
      state = state.copyWith(
        session: session,
        roomCode: roomCode,
        localColor: localColor,
        opponentInactive: opponentInactive,
        clearError: true,
      );
      _syncMovesWithLocalGame(session);
    });
  }

  Future<User?> _ensureAuth({bool force = false}) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null && !force) return auth.currentUser;
    try {
      await _ref.read(playGamesServiceProvider.notifier).manualSignIn();
      return await auth.signInWithProvider(GoogleAuthProvider()).then((c) => c.user);
    } catch (_) {
      // Fallback to anonymous auth to allow Firestore access until Play Games is configured.
      return (await auth.signInAnonymously()).user;
    }
  }

  OnlineGamePlayer _playerFor(User user) {
    final playGames = _ref.read(playGamesServiceProvider);
    final displayName = playGames.player?.displayName ?? user.displayName ?? 'Player';
    return OnlineGamePlayer(id: user.uid, displayName: displayName);
  }

  String _generateRoomCode() {
    final rand = Random();
    final digits = List.generate(4, (_) => rand.nextInt(10)).join();
    return 'STONE-$digits';
  }

  void _beginLocalGame(int boardSize) {
    _ref.read(gameSessionProvider.notifier).state =
        const GameSessionConfig(mode: GameMode.online);
    _ref.read(gameStateProvider.notifier).newGame(boardSize);
    _ref.read(moveHistoryProvider.notifier).clear();
    _ref.read(uiStateProvider.notifier).reset();
    _ref.read(animationStateProvider.notifier).reset();
    _ref.read(lastMoveProvider.notifier).state = null;
  }

  void _syncMovesWithLocalGame(OnlineGameSession session) {
    final applied = state.appliedMoveCount;
    if (session.moves.length < applied) {
      _beginLocalGame(session.boardSize);
      state = state.copyWith(appliedMoveCount: 0);
    }

    if (session.moves.length == state.appliedMoveCount) return;
    for (var i = state.appliedMoveCount; i < session.moves.length; i++) {
      final move = session.moves[i];
      final success = _applyNotation(move);
      if (!success) {
        state = state.copyWith(
          errorMessage: 'Failed to apply move ${move.notation}',
        );
        break;
      }
    }
    state = state.copyWith(appliedMoveCount: session.moves.length);
  }

  bool _applyNotation(OnlineGameMove move) {
    final notation = move.notation;
    final boardSize = _ref.read(gameStateProvider).boardSize;
    final gameNotifier = _ref.read(gameStateProvider.notifier);

    final placement = RegExp(r'^(S|C)?([a-z])(\d+)$');
    final stack = RegExp(r'^(\d+)?([a-z])(\d+)([<>+-])(\d+)?$');

    if (placement.hasMatch(notation)) {
      final match = placement.firstMatch(notation)!;
      final typePrefix = match.group(1);
      final col = match.group(2)!;
      final row = int.parse(match.group(3)!);
      final pos = _positionFromNotation(col, row, boardSize);
      final type = switch (typePrefix) {
        'S' => PieceType.standing,
        'C' => PieceType.capstone,
        _ => PieceType.flat,
      };
      final success = gameNotifier.placePiece(pos, type);
      if (success) {
        _consumeLastMove();
      }
      return success;
    }

    if (stack.hasMatch(notation)) {
      final match = stack.firstMatch(notation)!;
      final countPrefix = match.group(1);
      final col = match.group(2)!;
      final row = int.parse(match.group(3)!);
      final dirSymbol = match.group(4)!;
      final dropDigits = match.group(5);

      final totalPicked = countPrefix == null ? 1 : int.parse(countPrefix);
      final drops = dropDigits == null
          ? <int>[totalPicked]
          : dropDigits.split('').map(int.parse).toList();

      final from = _positionFromNotation(col, row, boardSize);
      final direction = _directionFromSymbol(dirSymbol);
      final success = gameNotifier.moveStack(from, direction, drops);
      if (success) {
        _consumeLastMove();
      }
      return success;
    }

    return false;
  }

  void _consumeLastMove() {
    final moveRecord = _ref.read(gameStateProvider.notifier).lastMoveRecord;
    if (moveRecord == null) return;
    _ref.read(moveHistoryProvider.notifier).addMove(moveRecord);
    _ref.read(lastMoveProvider.notifier).state = moveRecord.affectedPositions;
    _ref.read(animationStateProvider.notifier).reset();
    _ref.read(uiStateProvider.notifier).reset();
  }

  Position _positionFromNotation(String col, int rowNumber, int boardSize) {
    final colIndex = col.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rowIndex = boardSize - rowNumber;
    return Position(rowIndex, colIndex);
  }

  Direction _directionFromSymbol(String symbol) {
    return switch (symbol) {
      '+' => Direction.up,
      '-' => Direction.down,
      '<' => Direction.left,
      _ => Direction.right,
    };
  }

  bool _isOpponentInactive(OnlineGameSession session) {
    final updated = session.updatedAt;
    if (updated == null) return false;
    if (session.status != OnlineStatus.playing) return false;
    final now = DateTime.now();
    return now.difference(updated).inSeconds > 60;
  }
}

final onlineGameProvider =
    StateNotifierProvider<OnlineGameController, OnlineGameState>((ref) {
  return OnlineGameController(ref);
});

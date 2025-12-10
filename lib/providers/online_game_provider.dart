
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase_options.dart';
import '../models/models.dart';
import 'game_provider.dart';
import 'game_session_provider.dart';
import '../services/services.dart';
import 'ui_state_provider.dart';

void _debugLog(String message) {
  developer.log('[ONLINE] $message', name: 'multiplayer');
  // Also print to console for visibility
  // ignore: avoid_print
  print('[ONLINE] $message');
}

class OnlineGameState {
  final bool initializing;
  final bool creating;
  final bool joining;
  final OnlineGameSession? session;
  final String? roomCode;
  final PlayerColor? localColor;
  final bool opponentInactive;
  final bool opponentDisconnected;
  final bool reconnecting;
  final String? errorMessage;
  final int appliedMoveCount;
  final bool opponentJustJoined;
  final bool opponentJustMoved;

  const OnlineGameState({
    this.initializing = false,
    this.creating = false,
    this.joining = false,
    this.session,
    this.roomCode,
    this.localColor,
    this.opponentInactive = false,
    this.opponentDisconnected = false,
    this.reconnecting = false,
    this.errorMessage,
    this.appliedMoveCount = 0,
    this.opponentJustJoined = false,
    this.opponentJustMoved = false,
  });

  bool get isLocalTurn {
    final result = session != null && localColor != null && session!.currentTurn == localColor;
    _debugLog('isLocalTurn check: session=${session != null}, localColor=$localColor, '
        'sessionTurn=${session?.currentTurn}, result=$result');
    return result;
  }

  bool get waitingForOpponent => session?.status == OnlineStatus.waiting;

  OnlineGameState copyWith({
    bool? initializing,
    bool? creating,
    bool? joining,
    OnlineGameSession? session,
    String? roomCode,
    PlayerColor? localColor,
    bool? opponentInactive,
    bool? opponentDisconnected,
    bool? reconnecting,
    String? errorMessage,
    int? appliedMoveCount,
    bool clearError = false,
    bool? opponentJustJoined,
    bool? opponentJustMoved,
  }) {
    return OnlineGameState(
      initializing: initializing ?? this.initializing,
      creating: creating ?? this.creating,
      joining: joining ?? this.joining,
      session: session ?? this.session,
      roomCode: roomCode ?? this.roomCode,
      localColor: localColor ?? this.localColor,
      opponentInactive: opponentInactive ?? this.opponentInactive,
      opponentDisconnected: opponentDisconnected ?? this.opponentDisconnected,
      reconnecting: reconnecting ?? this.reconnecting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      appliedMoveCount: appliedMoveCount ?? this.appliedMoveCount,
      opponentJustJoined: opponentJustJoined ?? false,
      opponentJustMoved: opponentJustMoved ?? false,
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
    _debugLog('createGame() called with boardSize=$boardSize');
    await initialize();
    state = state.copyWith(creating: true, clearError: true);
    try {
      final user = FirebaseAuth.instance.currentUser ??
          (await _ensureAuth(force: true));
      if (user == null) {
        throw Exception('Unable to sign in. Please try again.');
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

      // Create with both createdAt and lastMoveAt fields
      final data = session.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['lastMoveAt'] = FieldValue.serverTimestamp();

      _debugLog('Creating game in Firestore with code=$code');
      await _firestore.collection('games').doc(code).set(data);
      _debugLog('Game created, setting up listener as WHITE');
      _listenToRoom(code, localColor: PlayerColor.white);
      state = state.copyWith(
        session: session,
        roomCode: code,
        localColor: PlayerColor.white,
        appliedMoveCount: 0,
      );
      _debugLog('State updated: localColor=white, appliedMoveCount=0');
      _beginLocalGame(boardSize);
    } catch (e) {
      _debugLog('createGame error: $e');
      final message = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(errorMessage: message);
    } finally {
      state = state.copyWith(creating: false);
    }
  }

  Future<void> joinGame(String roomCode) async {
    _debugLog('joinGame() called with roomCode=$roomCode');
    await initialize();
    state = state.copyWith(joining: true, clearError: true);
    final code = roomCode.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');

    // Validate room code format
    if (code.length != 6) {
      state = state.copyWith(
        joining: false,
        errorMessage: 'Room code must be 6 letters (e.g., ABCXYZ)',
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser ??
          (await _ensureAuth(force: true));
      if (user == null) {
        throw Exception('Unable to sign in. Please try again.');
      }

      final docRef = _firestore.collection('games').doc(code);
      OnlineGameSession? joinedSession;
      int existingMoveCount = 0;
      _debugLog('Starting Firestore transaction to join game');
      await _firestore.runTransaction((txn) async {
        final snapshot = await txn.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Game not found. Check the code and try again.');
        }
        final data = snapshot.data();
        if (data == null) throw Exception('Game data missing.');
        final existing = OnlineGameSession.fromSnapshot(code, data);
        existingMoveCount = existing.moves.length;
        _debugLog('Found game: boardSize=${existing.boardSize}, moves=$existingMoveCount, currentTurn=${existing.currentTurn}');

        if (existing.status == OnlineStatus.finished) {
          throw Exception('This game has already ended.');
        }

        if (existing.black != null && existing.black!.id != user.uid) {
          throw Exception('Game already has two players.');
        }

        final blackPlayer = existing.black ?? _playerFor(user);
        joinedSession = existing.copyWith(
          black: blackPlayer,
          status: OnlineStatus.playing,
        );
        _debugLog('Updating game status to playing');
        txn.update(docRef, {
          'black': blackPlayer.toMap(),
          'status': OnlineStatus.playing.name,
          'lastMoveAt': FieldValue.serverTimestamp(),
        });
      });

      if (joinedSession == null) {
        throw Exception('Failed to join game.');
      }

      _debugLog('Transaction complete, setting up listener as BLACK');
      _listenToRoom(code, localColor: PlayerColor.black);

      // IMPORTANT: Set session immediately so isLocalTurn works correctly
      state = state.copyWith(
        session: joinedSession,
        roomCode: code,
        localColor: PlayerColor.black,
        appliedMoveCount: 0, // Will be updated by _syncMovesWithLocalGame
      );
      _debugLog('State updated: localColor=black, roomCode=$code, session SET with ${joinedSession!.moves.length} moves');

      _beginLocalGame(joinedSession!.boardSize);
      _debugLog('Local game initialized with boardSize=${joinedSession!.boardSize}');
    } catch (e) {
      _debugLog('joinGame error: $e');
      final message = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(errorMessage: message);
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
    _debugLog('recordLocalMove() called: notation=${move.notation}, player=${move.player}');
    final activeSession = state.session;
    if (activeSession == null || state.localColor == null) {
      _debugLog('recordLocalMove: ABORT - session=${activeSession != null}, localColor=${state.localColor}');
      return;
    }

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

    _debugLog('recordLocalMove: Writing to Firestore - nextTurn=${latestState.currentPlayer.name}, status=$nextStatus');
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
        'lastMoveAt': FieldValue.serverTimestamp(),
      });
    });

    final newCount = state.appliedMoveCount + 1;
    _debugLog('recordLocalMove: Transaction complete, appliedMoveCount: ${state.appliedMoveCount} -> $newCount');
    state = state.copyWith(appliedMoveCount: newCount);
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
      'lastMoveAt': FieldValue.serverTimestamp(),
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
      'lastMoveAt': FieldValue.serverTimestamp(),
    });
    state = state.copyWith(appliedMoveCount: 0);
    _beginLocalGame(activeSession.boardSize);
  }

  Future<void> _listenToRoom(String roomCode, {required PlayerColor localColor}) async {
    _debugLog('_listenToRoom() called: roomCode=$roomCode, localColor=$localColor');
    await _subscription?.cancel();
    _subscription = _firestore
        .collection('games')
        .doc(roomCode)
        .snapshots()
        .listen((snapshot) {
      _debugLog('>>> FIRESTORE SNAPSHOT RECEIVED <<<');
      final data = snapshot.data();
      if (data == null) {
        _debugLog('Snapshot data is null, ignoring');
        return;
      }
      final session = OnlineGameSession.fromSnapshot(roomCode, data);
      final previousSession = state.session;

      _debugLog('Snapshot data: moves=${session.moves.length}, currentTurn=${session.currentTurn}, '
          'status=${session.status}, white=${session.white.displayName}, black=${session.black?.displayName}');
      _debugLog('Previous state: appliedMoveCount=${state.appliedMoveCount}, session=${previousSession != null}');

      // Detect opponent join (for sound trigger)
      final opponentJustJoined = previousSession != null &&
          previousSession.black == null &&
          session.black != null;

      // Detect opponent move (for sound trigger)
      final opponentJustMoved = previousSession != null &&
          session.moves.length > previousSession.moves.length &&
          session.moves.isNotEmpty &&
          session.moves.last.player != localColor;

      if (opponentJustJoined) _debugLog('EVENT: Opponent just joined!');
      if (opponentJustMoved) _debugLog('EVENT: Opponent just moved!');

      // Check activity status (2 minutes = inactive, 60 seconds = disconnected warning)
      final (opponentInactive, opponentDisconnected) = _checkOpponentActivity(session);

      _debugLog('Updating state with session, localColor=$localColor');
      state = state.copyWith(
        session: session,
        roomCode: roomCode,
        localColor: localColor,
        opponentInactive: opponentInactive,
        opponentDisconnected: opponentDisconnected,
        opponentJustJoined: opponentJustJoined,
        opponentJustMoved: opponentJustMoved,
        clearError: true,
      );
      _debugLog('State updated, now calling _syncMovesWithLocalGame');
      _syncMovesWithLocalGame(session);
    });
    _debugLog('Firestore listener setup complete');
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
    String displayName;
    if (playGames.player?.displayName != null) {
      displayName = playGames.player!.displayName;
    } else if (user.displayName != null && user.displayName!.isNotEmpty) {
      displayName = user.displayName!;
    } else {
      // Generate random "Player-XXXX" name for anonymous users
      final rand = Random();
      final digits = List.generate(4, (_) => rand.nextInt(10)).join();
      displayName = 'Player-$digits';
    }
    return OnlineGamePlayer(id: user.uid, displayName: displayName);
  }

  String _generateRoomCode() {
    final rand = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  void _beginLocalGame(int boardSize) {
    _debugLog('_beginLocalGame: Starting new local game with boardSize=$boardSize');
    _ref.read(gameSessionProvider.notifier).state =
        const GameSessionConfig(mode: GameMode.online);
    _ref.read(gameStateProvider.notifier).newGame(boardSize);
    _ref.read(moveHistoryProvider.notifier).clear();
    _ref.read(uiStateProvider.notifier).reset();
    _ref.read(animationStateProvider.notifier).reset();
    _ref.read(lastMoveProvider.notifier).state = null;
    _debugLog('_beginLocalGame: Local game initialized, gameSessionProvider mode=online');
  }

  void _syncMovesWithLocalGame(OnlineGameSession session) {
    final applied = state.appliedMoveCount;
    _debugLog('_syncMovesWithLocalGame: session.moves=${session.moves.length}, appliedMoveCount=$applied');

    if (session.moves.length < applied) {
      _debugLog('_syncMovesWithLocalGame: Moves decreased! Resetting local game.');
      _beginLocalGame(session.boardSize);
      state = state.copyWith(appliedMoveCount: 0);
    }

    if (session.moves.length == state.appliedMoveCount) {
      _debugLog('_syncMovesWithLocalGame: No new moves to apply (${session.moves.length} == ${state.appliedMoveCount})');
      return;
    }

    _debugLog('_syncMovesWithLocalGame: Applying moves from ${state.appliedMoveCount} to ${session.moves.length - 1}');
    for (var i = state.appliedMoveCount; i < session.moves.length; i++) {
      final move = session.moves[i];
      _debugLog('_syncMovesWithLocalGame: Applying move $i: ${move.notation} by ${move.player}');
      final success = _applyNotation(move);
      if (!success) {
        _debugLog('_syncMovesWithLocalGame: FAILED to apply move ${move.notation}!');
        state = state.copyWith(
          errorMessage: 'Failed to apply move ${move.notation}',
        );
        break;
      }
      _debugLog('_syncMovesWithLocalGame: Move applied successfully');
    }
    _debugLog('_syncMovesWithLocalGame: Done. appliedMoveCount: $applied -> ${session.moves.length}');
    state = state.copyWith(appliedMoveCount: session.moves.length);
  }

  bool _applyNotation(OnlineGameMove move) {
    final notation = move.notation;
    final boardSize = _ref.read(gameStateProvider).boardSize;
    final gameNotifier = _ref.read(gameStateProvider.notifier);
    final currentGameState = _ref.read(gameStateProvider);

    _debugLog('_applyNotation: notation=$notation, currentPlayer=${currentGameState.currentPlayer}, '
        'turnNumber=${currentGameState.turnNumber}, phase=${currentGameState.phase}');

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
      _debugLog('_applyNotation: Placing $type at $pos');
      final success = gameNotifier.placePiece(pos, type);
      _debugLog('_applyNotation: placePiece result=$success');
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
      _debugLog('_applyNotation: Moving stack from $from, direction=$direction, drops=$drops');
      final success = gameNotifier.moveStack(from, direction, drops);
      _debugLog('_applyNotation: moveStack result=$success');
      if (success) {
        _consumeLastMove();
      }
      return success;
    }

    _debugLog('_applyNotation: No regex match for notation=$notation');
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

  /// Returns (opponentInactive, opponentDisconnected)
  /// - opponentInactive: No move for 2+ minutes
  /// - opponentDisconnected: No move for 60+ seconds (warning state)
  (bool, bool) _checkOpponentActivity(OnlineGameSession session) {
    final lastMove = session.lastMoveAt;
    if (lastMove == null) return (false, false);
    if (session.status != OnlineStatus.playing) return (false, false);

    final now = DateTime.now();
    final secondsSinceLastMove = now.difference(lastMove).inSeconds;

    // Opponent inactive: 2+ minutes of no activity
    final opponentInactive = secondsSinceLastMove > 120;
    // Opponent disconnected warning: 60+ seconds of no activity
    final opponentDisconnected = secondsSinceLastMove > 60;

    return (opponentInactive, opponentDisconnected);
  }
}

final onlineGameProvider =
    StateNotifierProvider<OnlineGameController, OnlineGameState>((ref) {
  return OnlineGameController(ref);
});

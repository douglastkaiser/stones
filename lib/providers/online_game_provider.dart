
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase_options.dart';
import '../models/models.dart';
import 'chess_clock_provider.dart';
import 'game_provider.dart';
import 'game_session_provider.dart';
import '../services/services.dart';
import 'settings_provider.dart';
import 'ui_state_provider.dart';

void _debugLog(String message) {
  // Only log in debug mode to prevent exposing sensitive data in production
  if (kDebugMode) {
    developer.log('[ONLINE] $message', name: 'multiplayer');
  }
}

/// Sanitize error messages for user display to prevent information disclosure
String _sanitizeErrorMessage(Object error) {
  final errorStr = error.toString();

  // If it's an Exception with a message, extract it
  if (errorStr.startsWith('Exception: ')) {
    final message = errorStr.replaceFirst('Exception: ', '');
    // Only return the message if it doesn't contain internal details
    if (!message.contains('StackTrace') && !message.contains('firebase') &&
        !message.contains('Firestore') && message.length < 200) {
      return message;
    }
  }

  // For other errors, log the details but return a generic message
  _debugLog('Error occurred: $errorStr');
  return 'An error occurred. Please try again.';
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
  // Lazy access to Firestore - only accessed after Firebase is initialized
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  Future<void> initialize() async {
    if (state.initializing) return;
    state = state.copyWith(initializing: true, clearError: true);
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        // Activate Firebase App Check for rate limiting and abuse prevention
        await FirebaseAppCheck.instance.activate(
          // Use debug provider in debug mode for testing
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider: kDebugMode
              ? AppleProvider.debug
              : AppleProvider.appAttest,
          webProvider: ReCaptchaV3Provider('6LcddkcsAAAAAOg3-0rrUshkC6Tjk6VxzrBbK7YC'),
        );
        _debugLog('Firebase App Check activated');
      }
      // Don't auto-authenticate here - let user explicitly create/join game
      // Authentication happens in createGame() and joinGame() when needed
    } catch (e) {
      _debugLog('Firebase initialization failed: $e');
      state = state.copyWith(errorMessage: 'Failed to initialize. Please refresh the page.');
    } finally {
      state = state.copyWith(initializing: false);
    }
  }

  Future<void> createGame({
    required int boardSize,
    bool chessClockEnabled = false,
    int? chessClockSeconds,
    PlayerColor creatorColor = PlayerColor.white,
  }) async {
    _debugLog('createGame() called with boardSize=$boardSize, creatorColor=$creatorColor');
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
      // Creator is assigned to their chosen color
      final session = OnlineGameSession(
        roomCode: code,
        white: creatorColor == PlayerColor.white ? player : null,
        black: creatorColor == PlayerColor.black ? player : null,
        boardSize: boardSize,
        chessClockEnabled: chessClockEnabled,
        chessClockSeconds: chessClockSeconds,
        creatorColor: creatorColor,
      );

      // Create with both createdAt and lastMoveAt fields
      final data = session.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['lastMoveAt'] = FieldValue.serverTimestamp();

      _debugLog('Creating game in Firestore with code=$code');
      await _firestore.collection('games').doc(code).set(data);
      _debugLog('Game created, setting up listener as $creatorColor');
      await _listenToRoom(code, localColor: creatorColor);
      state = state.copyWith(
        session: session,
        roomCode: code,
        localColor: creatorColor,
        appliedMoveCount: 0,
      );
      _debugLog('State updated: localColor=$creatorColor, appliedMoveCount=0');
      _beginLocalGame(boardSize, session: session);
    } catch (e) {
      _debugLog('createGame error: $e');
      state = state.copyWith(errorMessage: _sanitizeErrorMessage(e));
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
      PlayerColor? joinerColor;
      _debugLog('Starting Firestore transaction to join game');
      await _firestore.runTransaction((txn) async {
        final snapshot = await txn.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Game not found. Check the code and try again.');
        }
        final data = snapshot.data();
        if (data == null) throw Exception('Game data missing.');
        final existing = OnlineGameSession.fromSnapshot(code, data);
        _debugLog('Found game: boardSize=${existing.boardSize}, moves=${existing.moves.length}, currentTurn=${existing.currentTurn}, creatorColor=${existing.creatorColor}');

        if (existing.status == OnlineStatus.finished) {
          throw Exception('This game has already ended.');
        }

        // Determine joiner's color (opposite of creator's color)
        joinerColor = existing.creatorColor == PlayerColor.white
            ? PlayerColor.black
            : PlayerColor.white;

        // Check if the slot for joiner's color is available
        final joinerPlayer = _playerFor(user);
        if (joinerColor == PlayerColor.white) {
          if (existing.white != null && existing.white!.id != user.uid) {
            throw Exception('Game already has two players.');
          }
          joinedSession = existing.copyWith(
            white: joinerPlayer,
            status: OnlineStatus.playing,
          );
          txn.update(docRef, {
            'white': joinerPlayer.toMap(),
            'status': OnlineStatus.playing.name,
            'lastMoveAt': FieldValue.serverTimestamp(),
          });
        } else {
          if (existing.black != null && existing.black!.id != user.uid) {
            throw Exception('Game already has two players.');
          }
          joinedSession = existing.copyWith(
            black: joinerPlayer,
            status: OnlineStatus.playing,
          );
          txn.update(docRef, {
            'black': joinerPlayer.toMap(),
            'status': OnlineStatus.playing.name,
            'lastMoveAt': FieldValue.serverTimestamp(),
          });
        }
        _debugLog('Updating game status to playing, joiner is $joinerColor');
      });

      if (joinedSession == null || joinerColor == null) {
        throw Exception('Failed to join game.');
      }

      _debugLog('Transaction complete, setting up listener as $joinerColor');
      _debugLog('>>> JOINER: About to call _listenToRoom <<<');
      await _listenToRoom(code, localColor: joinerColor!);

      // IMPORTANT: Set session immediately so isLocalTurn works correctly
      _debugLog('>>> JOINER: Setting state with session <<<');
      state = state.copyWith(
        session: joinedSession,
        roomCode: code,
        localColor: joinerColor,
        appliedMoveCount: 0, // Will be updated by _syncMovesWithLocalGame
      );
      _debugLog('>>> JOINER: State set: localColor=$joinerColor, roomCode=$code <<<');
      _debugLog('>>> JOINER: session.moves=${joinedSession!.moves.length}, session.currentTurn=${joinedSession!.currentTurn} <<<');

      _debugLog('>>> JOINER: About to call _beginLocalGame <<<');
      _beginLocalGame(joinedSession!.boardSize, session: joinedSession);
      _debugLog('>>> JOINER: Local game initialized with boardSize=${joinedSession!.boardSize} <<<');

      // Log the final state after joining
      final finalLocalState = _ref.read(gameStateProvider);
      _debugLog('>>> JOINER FINAL STATE <<<');
      _debugLog('gameStateProvider: currentPlayer=${finalLocalState.currentPlayer}, turnNumber=${finalLocalState.turnNumber}');
      _debugLog('gameStateProvider: board.occupiedPositions=${finalLocalState.board.occupiedPositions.length}');
      _debugLog('onlineGameState: session.moves=${state.session?.moves.length}, appliedMoveCount=${state.appliedMoveCount}');
    } catch (e) {
      _debugLog('joinGame error: $e');
      state = state.copyWith(errorMessage: _sanitizeErrorMessage(e));
    } finally {
      state = state.copyWith(joining: false);
    }
  }

  Future<void> leaveRoom() async {
    await _subscription?.cancel();
    _subscription = null;
    _ref.read(chessClockProvider.notifier).stop();
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

      // Convert existing moves to properly typed maps (Firestore web returns Map<Object?, Object?>)
      final rawMoves = data['moves'] as List? ?? [];
      final moves = rawMoves.map((m) {
        if (m is Map<String, dynamic>) return m;
        if (m is Map) return Map<String, dynamic>.from(m);
        return <String, dynamic>{};
      }).toList();

      // Add the new move as a properly serialized map
      final newMoveMap = OnlineGameMove(
        notation: move.notation,
        player: state.localColor!,
      ).toMap();
      moves.add(newMoveMap);

      final updateData = {
        'moves': moves,
        'currentTurn': latestState.currentPlayer.name,
        'status': nextStatus,
        'winner': winner,
        'lastMoveAt': FieldValue.serverTimestamp(),
      };

      _debugLog('recordLocalMove: Firestore update data: moves=${moves.length}, currentTurn=${updateData['currentTurn']}, status=${updateData['status']}');
      _debugLog('recordLocalMove: New move: $newMoveMap');

      txn.update(docRef, updateData);
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
    _beginLocalGame(activeSession.boardSize, session: activeSession);
  }

  Future<void> _listenToRoom(String roomCode, {required PlayerColor localColor}) async {
    _debugLog('_listenToRoom() called: roomCode=$roomCode, localColor=$localColor');
    await _subscription?.cancel();

    final docRef = _firestore.collection('games').doc(roomCode);
    _debugLog('>>> Subscribing to document path: ${docRef.path} <<<');

    _subscription = docRef.snapshots().listen((snapshot) {
      _debugLog('>>> FIRESTORE SNAPSHOT RECEIVED <<<');
      _debugLog('>>> connectionState: exists=${snapshot.exists}, metadata.isFromCache=${snapshot.metadata.isFromCache}, metadata.hasPendingWrites=${snapshot.metadata.hasPendingWrites} <<<');

      final data = snapshot.data();
      if (data == null) {
        _debugLog('Snapshot data is null, ignoring');
        return;
      }

      // Log raw Firestore data for debugging
      _debugLog('>>> RAW FIRESTORE DATA <<<');
      _debugLog('moves count: ${(data['moves'] as List?)?.length ?? 0}');
      _debugLog('currentTurn: ${data['currentTurn']}');
      _debugLog('status: ${data['status']}');
      _debugLog('white: ${data['white']}');
      _debugLog('black: ${data['black']}');
      _debugLog('>>> END RAW DATA <<<');

      // Try to deserialize with error catching
      OnlineGameSession session;
      try {
        session = OnlineGameSession.fromSnapshot(roomCode, data);
        _debugLog('Deserialization SUCCESS: moves=${session.moves.length}, currentTurn=${session.currentTurn}');
      } catch (e, stackTrace) {
        _debugLog('!!! DESERIALIZATION ERROR !!!');
        _debugLog('Error: $e');
        _debugLog('Stack trace: $stackTrace');
        _debugLog('Raw data that failed: $data');
        return;
      }
      final previousSession = state.session;

      _debugLog('Snapshot data: moves=${session.moves.length}, currentTurn=${session.currentTurn}, '
          'status=${session.status}, white=${session.white?.displayName}, black=${session.black?.displayName}');
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
    }, onError: (error, stackTrace) {
      _debugLog('!!! FIRESTORE LISTENER ERROR !!!');
      _debugLog('Error: $error');
      _debugLog('Stack trace: $stackTrace');
      state = state.copyWith(errorMessage: 'Connection error. Please check your internet connection.');
    });
    _debugLog('Firestore listener setup complete');
  }

  Future<User?> _ensureAuth({bool force = false}) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null && !force) return auth.currentUser;

    // Try Play Games sign-in first (optional, for display name on mobile)
    // This will fail on web - that's expected and OK
    if (!kIsWeb) {
      try {
        await _ref.read(playGamesServiceProvider.notifier).manualSignIn();
      } catch (e) {
        _debugLog('Play Games sign-in failed (optional): $e');
        // Continue to Firebase Auth - Play Games is just for display name
      }
    }

    // Firebase Auth is required for online play
    try {
      UserCredential credential;
      if (kIsWeb) {
        // On web, use signInWithPopup for better compatibility
        credential = await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        // On mobile, use signInWithProvider
        credential = await auth.signInWithProvider(GoogleAuthProvider());
      }
      return credential.user;
    } catch (e) {
      // Security: Require proper authentication for online play - no anonymous fallback
      // This ensures user accountability and prevents abuse
      _debugLog('Firebase authentication failed: $e');
      throw Exception('Please sign in with Google to play online.');
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
      final rand = Random.secure();
      final digits = List.generate(4, (_) => rand.nextInt(10)).join();
      displayName = 'Player-$digits';
    }
    // Sanitize display name for security
    displayName = OnlineGamePlayer.sanitize(displayName);
    return OnlineGamePlayer(id: user.uid, displayName: displayName);
  }

  String _generateRoomCode() {
    final rand = Random.secure();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  void _beginLocalGame(int boardSize, {OnlineGameSession? session}) {
    _debugLog('_beginLocalGame: Starting new local game with boardSize=$boardSize');
    final currentSession = _ref.read(gameSessionProvider);

    // Use chess clock settings from the online session if available (synced from creator)
    final useChessClock = session?.chessClockEnabled ?? false;
    final clockSeconds = session?.chessClockSeconds;

    _ref.read(gameSessionProvider.notifier).state = currentSession.copyWith(
      mode: GameMode.online,
      chessClockSecondsOverride: clockSeconds,
    );
    _ref.read(gameStateProvider.notifier).newGame(boardSize);
    _ref.read(moveHistoryProvider.notifier).clear();
    _ref.read(uiStateProvider.notifier).reset();
    _ref.read(animationStateProvider.notifier).reset();
    _ref.read(lastMoveProvider.notifier).state = null;

    // Enable chess clock based on the online session settings (synced from creator)
    if (useChessClock) {
      _ref.read(appSettingsProvider.notifier).setChessClockEnabled(true);
      _ref.read(chessClockProvider.notifier).initialize(
            boardSize,
            secondsOverride: clockSeconds,
          );
      _debugLog('_beginLocalGame: Chess clock enabled with ${clockSeconds ?? 'default'} seconds');
    } else {
      _ref.read(chessClockProvider.notifier).stop();
    }
    _debugLog('_beginLocalGame: Local game initialized, gameSessionProvider mode=online');
  }

  void _syncMovesWithLocalGame(OnlineGameSession session) {
    final applied = state.appliedMoveCount;
    _debugLog('>>> _syncMovesWithLocalGame START <<<');
    _debugLog('session.moves.length=${session.moves.length}, appliedMoveCount=$applied');

    // Log the LOCAL game state BEFORE sync
    final localStateBefore = _ref.read(gameStateProvider);
    _debugLog('LOCAL STATE BEFORE SYNC: currentPlayer=${localStateBefore.currentPlayer}, '
        'turnNumber=${localStateBefore.turnNumber}, '
        'occupiedCells=${localStateBefore.board.occupiedPositions.length}');

    if (session.moves.length < applied) {
      _debugLog('_syncMovesWithLocalGame: Moves decreased! Resetting local game.');
      _beginLocalGame(session.boardSize, session: session);
      state = state.copyWith(appliedMoveCount: 0);
    }

    if (session.moves.length == state.appliedMoveCount) {
      _debugLog('_syncMovesWithLocalGame: No new moves to apply (${session.moves.length} == ${state.appliedMoveCount})');
      _debugLog('>>> _syncMovesWithLocalGame END (no changes) <<<');
      return;
    }

    _debugLog('>>> APPLYING ${session.moves.length - state.appliedMoveCount} NEW MOVES <<<');
    for (var i = state.appliedMoveCount; i < session.moves.length; i++) {
      final move = session.moves[i];
      _debugLog('Applying move $i: notation="${move.notation}", player=${move.player}');
      final success = _applyNotation(move);
      if (!success) {
        _debugLog('!!! FAILED to apply move ${move.notation} !!!');
        state = state.copyWith(
          errorMessage: 'Failed to apply move ${move.notation}',
        );
        break;
      }
      _debugLog('Move $i applied successfully');
    }

    // Log the LOCAL game state AFTER sync
    final localStateAfter = _ref.read(gameStateProvider);
    _debugLog('LOCAL STATE AFTER SYNC: currentPlayer=${localStateAfter.currentPlayer}, '
        'turnNumber=${localStateAfter.turnNumber}, '
        'occupiedCells=${localStateAfter.board.occupiedPositions.length}');

    _debugLog('Updating appliedMoveCount: $applied -> ${session.moves.length}');
    state = state.copyWith(appliedMoveCount: session.moves.length);
    _debugLog('>>> _syncMovesWithLocalGame END <<<');
  }

  bool _applyNotation(OnlineGameMove move) {
    final notation = move.notation;

    // Validate move notation for security
    if (!OnlineGameMove.isValidNotation(notation)) {
      _debugLog('_applyNotation: Invalid notation format: $notation');
      return false;
    }

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

    final settings = _ref.read(appSettingsProvider);
    if (!settings.chessClockEnabled) return;
    final gameState = _ref.read(gameStateProvider);
    if (gameState.isGameOver) {
      _ref.read(chessClockProvider.notifier).stop();
      return;
    }
    _ref.read(chessClockProvider.notifier).start(gameState.currentPlayer);
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

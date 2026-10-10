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
import 'cosmetics_provider.dart';
import 'elo_provider.dart';
import 'game_provider.dart';
import 'game_session_provider.dart';
import '../services/services.dart';
import '../services/online_replay.dart';
import '../models/online_clock.dart';
import 'saved_rooms_provider.dart';
import 'account_provider.dart';
import 'settings_provider.dart';
import 'scenario_provider.dart';
import 'ui_state_provider.dart';

void _debugLog(String message) {
  // Log in debug mode for detailed debugging
  if (kDebugMode) {
    developer.log('[ONLINE] $message', name: 'multiplayer');
  }
  // Also print to console for web debugging (visible in browser console)
  if (kDebugMode && kIsWeb) {
    // ignore: avoid_print
    print('[ONLINE] $message');
  }
}

/// Sanitize error messages for user display to prevent information disclosure
String _sanitizeErrorMessage(Object error) {
  final errorStr = error.toString();

  // If it's an Exception with a message, extract it
  if (errorStr.startsWith('Exception: ')) {
    final message = errorStr.replaceFirst('Exception: ', '');
    // Only return the message if it doesn't contain internal details
    if (!message.contains('StackTrace') && message.length < 200) {
      return message;
    }
  }

  // Handle common Firebase Auth errors with user-friendly messages
  if (errorStr.contains('anonymous-auth-disabled') ||
      errorStr.contains('operation-not-allowed')) {
    return 'Anonymous sign-in is not enabled. Please contact support.';
  }
  if (errorStr.contains('network-request-failed')) {
    return 'Network error. Please check your connection.';
  }
  if (errorStr.contains('too-many-requests')) {
    return 'Too many requests. Please try again later.';
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
    final result = session != null &&
        session!.status == OnlineStatus.playing &&
        !reconnecting &&
        errorMessage == null &&
        localColor != null &&
        session!.currentTurn == localColor;
    _debugLog(
        'isLocalTurn check: session=${session != null}, localColor=$localColor, '
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
  bool _firebaseInitialized = false;
  bool get firebaseInitialized => _firebaseInitialized;
  Future<void>? _initialization;
  bool _appCheckActivated = false;
  int _roomEpoch = 0;
  bool _submitting = false;
  bool _endingOnTime = false;

  Future<void> initialize() async {
    if (_firebaseInitialized) return;
    if (_initialization != null) {
      await _initialization;
      return;
    }
    final work = _initialize();
    _initialization = work;
    try {
      await work;
    } finally {
      _initialization = null;
    }
  }

  Future<void> _initialize() async {
    // Already initialized successfully
    if (_firebaseInitialized) {
      _debugLog('initialize: Already initialized, skipping');
      return;
    }
    // Currently initializing
    if (state.initializing) {
      _debugLog('initialize: Currently initializing, skipping');
      return;
    }

    _debugLog('initialize: Starting Firebase initialization');
    state = state.copyWith(initializing: true);
    try {
      // Initialize Firebase - always try, catch if already initialized
      _debugLog('initialize: Calling Firebase.initializeApp');
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _debugLog('initialize: Firebase initialized successfully');
      } catch (e) {
        // Firebase might already be initialized - check if that's the case
        if (e.toString().contains('already been initialized') ||
            e.toString().contains('duplicate-app')) {
          _debugLog('initialize: Firebase was already initialized, continuing');
        } else {
          _debugLog('initialize: Firebase.initializeApp error: $e');
          rethrow;
        }
      }

      // Activate App Check only once
      if (!_appCheckActivated) {
        _debugLog('initialize: Activating Firebase App Check');
        try {
          await FirebaseAppCheck.instance.activate(
            // Use debug provider in debug mode for testing
            androidProvider: kDebugMode
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
            appleProvider:
                kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
            webProvider:
                ReCaptchaV3Provider('6LcddkcsAAAAAOg3-0rrUshkC6Tjk6VxzrBbK7YC'),
          );
          _appCheckActivated = true;
          _debugLog('initialize: Firebase App Check activated successfully');
        } catch (appCheckError) {
          // App Check activation might fail if already activated or other issues
          // Log but don't fail - App Check is for abuse prevention, not critical
          _debugLog(
              'initialize: App Check activation error (non-fatal): $appCheckError');
          _appCheckActivated = true; // Mark as activated to avoid retrying
        }
      } else {
        _debugLog('initialize: App Check already activated, skipping');
      }

      // Wait for restored authentication before considering anonymous sign-in.
      // The SDK persists web identities locally and native identities on device.
      await FirebaseAuth.instance.authStateChanges().first;
      _firebaseInitialized = true;
      _debugLog('initialize: Firebase initialization complete');
      // Clear any previous errors on successful initialization
      state = state.copyWith(clearError: true);
    } catch (e) {
      _debugLog('initialize: Firebase initialization failed: $e');
      state = state.copyWith(errorMessage: 'Failed to connect to server: $e');
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
    _debugLog(
        'createGame() called with boardSize=$boardSize, creatorColor=$creatorColor');
    _debugLog(
        'createGame: state.errorMessage=${state.errorMessage}, state.initializing=${state.initializing}');
    state = state.copyWith(clearError: true);
    await initialize();

    // Check if initialize() failed
    if (state.errorMessage != null) {
      _debugLog(
          'createGame: initialize() failed with error: ${state.errorMessage}');
      return;
    }

    _debugLog('createGame: initialize() succeeded, proceeding');
    await leaveRoom();
    final operation = _roomEpoch;
    state = state.copyWith(creating: true);
    try {
      _debugLog('createGame: checking currentUser');
      final existingUser = FirebaseAuth.instance.currentUser;
      _debugLog('createGame: currentUser=${existingUser?.uid}');

      final user = existingUser ?? (await _ensureAuth());
      _debugLog('createGame: got user=${user?.uid}');

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
        boardTheme: _ref.read(shareableBoardThemeProvider),
      );

      // Create with both createdAt and lastMoveAt fields
      final data = session.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['lastMoveAt'] = FieldValue.serverTimestamp();

      _debugLog('Creating game in Firestore with code=$code');
      // Save the pointer before sending the create request. A tab closed while
      // awaiting acknowledgement can still find a room the server committed.
      await _rememberRoom(code, user.uid);
      if (!mounted || operation != _roomEpoch) return;
      await _firestore.collection('games').doc(code).set(data);
      if (!mounted || operation != _roomEpoch) return;
      _debugLog('Game created, setting up listener as $creatorColor');
      state = state.copyWith(
        session: session,
        roomCode: code,
        localColor: creatorColor,
        appliedMoveCount: 0,
      );
      _debugLog('State updated: localColor=$creatorColor, appliedMoveCount=0');
      _beginLocalGame(boardSize, session: session);
      await _listenToRoom(code, localColor: creatorColor);
    } catch (e) {
      _debugLog('createGame error: $e');
      if (mounted && operation == _roomEpoch) {
        state = state.copyWith(errorMessage: _sanitizeErrorMessage(e));
      }
    } finally {
      if (mounted && operation == _roomEpoch) {
        state = state.copyWith(creating: false);
      }
    }
  }

  Future<void> joinGame(String roomCode, {String? expectedUid}) async {
    _debugLog('joinGame() called with roomCode=$roomCode');
    state = state.copyWith(clearError: true);
    await initialize();

    // Check if initialize() failed
    if (state.errorMessage != null) {
      _debugLog('joinGame: initialize() failed, aborting');
      return;
    }

    await leaveRoom();
    final operation = _roomEpoch;
    state = state.copyWith(joining: true);
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
      if (expectedUid != null &&
          FirebaseAuth.instance.currentUser?.uid != expectedUid) {
        throw Exception(
            'This room belongs to a different identity. Use the original browser profile or sign in with the original account.');
      }
      final user = FirebaseAuth.instance.currentUser ?? (await _ensureAuth());
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
        _debugLog(
            'Found game: boardSize=${existing.boardSize}, moves=${existing.moves.length}, currentTurn=${existing.currentTurn}, creatorColor=${existing.creatorColor}');

        // Reconnect without rewriting either participant's match cosmetics.
        if (existing.white?.id == user.uid || existing.black?.id == user.uid) {
          joinerColor = existing.white?.id == user.uid
              ? PlayerColor.white
              : PlayerColor.black;
          joinedSession = existing;
          await _rememberRoom(code, user.uid);
          return;
        }

        if (expectedUid != null) {
          throw Exception(
              'Your saved identity no longer owns a seat in this room.');
        }
        if (existing.status == OnlineStatus.finished) {
          throw Exception('This game has already ended.');
        }

        // Determine joiner's color (opposite of creator's color)
        joinerColor = existing.creatorColor == PlayerColor.white
            ? PlayerColor.black
            : PlayerColor.white;

        // Check if the slot for joiner's color is available
        final joinerPlayer = (joinerColor == PlayerColor.white
                ? existing.white
                : existing.black) ??
            _playerFor(user);
        if (joinerColor == PlayerColor.white) {
          if (existing.white != null && existing.white!.id != user.uid) {
            throw Exception('Game already has two players.');
          }
          joinedSession = existing.copyWith(
            white: joinerPlayer,
            status: OnlineStatus.playing,
          );
          await _rememberRoom(code, user.uid);
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
          await _rememberRoom(code, user.uid);
          txn.update(docRef, {
            'black': joinerPlayer.toMap(),
            'status': OnlineStatus.playing.name,
            'lastMoveAt': FieldValue.serverTimestamp(),
          });
        }
        _debugLog('Updating game status to playing, joiner is $joinerColor');
      });

      if (!mounted || operation != _roomEpoch) return;
      if (joinedSession == null || joinerColor == null) {
        throw Exception('Failed to join game.');
      }

      _debugLog('Transaction complete, setting up listener as $joinerColor');
      _debugLog('>>> JOINER: About to call _listenToRoom <<<');

      // IMPORTANT: Set session immediately so isLocalTurn works correctly
      _debugLog('>>> JOINER: Setting state with session <<<');
      state = state.copyWith(
        session: joinedSession,
        roomCode: code,
        localColor: joinerColor,
        appliedMoveCount: 0, // Will be updated by _syncMovesWithLocalGame
      );
      _debugLog(
          '>>> JOINER: State set: localColor=$joinerColor, roomCode=$code <<<');
      _debugLog(
          '>>> JOINER: session.moves=${joinedSession!.moves.length}, session.currentTurn=${joinedSession!.currentTurn} <<<');

      _debugLog('>>> JOINER: About to call _beginLocalGame <<<');
      rebuildFromSession(joinedSession!, joinerColor!);
      await _rememberRoom(code, user.uid);
      await _listenToRoom(code, localColor: joinerColor!);
      _debugLog(
          '>>> JOINER: Local game initialized with boardSize=${joinedSession!.boardSize} <<<');

      // Log the final state after joining
      final finalLocalState = _ref.read(gameStateProvider);
      _debugLog('>>> JOINER FINAL STATE <<<');
      _debugLog(
          'gameStateProvider: currentPlayer=${finalLocalState.currentPlayer}, turnNumber=${finalLocalState.turnNumber}');
      _debugLog(
          'gameStateProvider: board.occupiedPositions=${finalLocalState.board.occupiedPositions.length}');
      _debugLog(
          'onlineGameState: session.moves=${state.session?.moves.length}, appliedMoveCount=${state.appliedMoveCount}');
    } catch (e) {
      _debugLog('joinGame error: $e');
      if (mounted && operation == _roomEpoch) {
        state = state.copyWith(errorMessage: _sanitizeErrorMessage(e));
      }
    } finally {
      if (mounted && operation == _roomEpoch) {
        state = state.copyWith(joining: false);
      }
    }
  }

  Future<void> leaveRoom() async {
    _roomEpoch++;
    _submitting = false;
    _endingOnTime = false;
    final subscription = _subscription;
    _subscription = null;
    _ref.read(chessClockProvider.notifier).stop();
    state = const OnlineGameState();
    await subscription?.cancel();
  }

  Future<void> _rememberRoom(String code, String uid) async {
    try {
      await _ref
          .read(savedRoomsProvider.notifier)
          .remember(SavedRoom(code: code, uid: uid, hex: false));
    } catch (_) {
      state = state.copyWith(
          errorMessage:
              'Room is online, but this device could not save its shortcut. Keep code $code to return.');
    }
  }

  /// Rebuild from an authoritative room document without depending on previous
  /// widget state. Used by recovery and reconciliation, including final results.
  void rebuildFromSession(OnlineGameSession session, PlayerColor color) {
    state = OnlineGameState(
        session: session, roomCode: session.roomCode, localColor: color);
    _beginLocalGame(session.boardSize, session: session);
    _syncMovesWithLocalGame(session);
  }

  Future<void> recordLocalMove(MoveRecord move, GameState latestState) async {
    _debugLog(
        'recordLocalMove() called: notation=${move.notation}, player=${move.player}');
    final activeSession = state.session;
    if (activeSession == null || state.localColor == null) {
      _debugLog(
          'recordLocalMove: ABORT - session=${activeSession != null}, localColor=${state.localColor}');
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

    final expectedCount = state.appliedMoveCount;
    final color = state.localColor!;
    final epoch = _roomEpoch;
    if (_submitting || move.player != color) return;
    _submitting = true;
    // The UI already applied this move. Reserve its log index before snapshots
    // arrive, and lock input until the transaction has acknowledged it.
    state =
        state.copyWith(appliedMoveCount: expectedCount + 1, reconnecting: true);
    try {
      await _firestore.runTransaction((txn) async {
        final snapshot = await txn.get(docRef);
        if (!snapshot.exists) throw StateError('Room no longer exists');
        final remote = OnlineGameSession.fromSnapshot(
            activeSession.roomCode, snapshot.data()!);
        if (remote.status != OnlineStatus.playing ||
            remote.currentTurn != color ||
            remote.moves.length != expectedCount ||
            !_samePrefix(remote.moves, activeSession.moves, expectedCount)) {
          throw StateError(
              'The room changed. Reconnect to load the latest board.');
        }
        final moves = (snapshot.data()!['moves'] as List).toList();
        final clock = OnlineClockBalance.at(remote, DateTime.now());
        if (remote.chessClockEnabled &&
            (color == PlayerColor.white ? clock.white : clock.black) <= 0) {
          throw StateError('The move arrived after the clock expired.');
        }
        moves.add(OnlineGameMove(
                notation: move.notation,
                player: color,
                whiteSeconds: remote.chessClockEnabled ? clock.white : null,
                blackSeconds: remote.chessClockEnabled ? clock.black : null)
            .toMap());
        txn.update(docRef, {
          'moves': moves,
          'currentTurn': latestState.currentPlayer.name,
          'status': nextStatus,
          'winner': winner,
          'lastMoveAt': FieldValue.serverTimestamp(),
        });
      });
      if (mounted && epoch == _roomEpoch) {
        state = state.copyWith(reconnecting: false);
      }
    } catch (_) {
      if (mounted && epoch == _roomEpoch) {
        // A failed/unacknowledged move is never treated as a durable save.
        // Rebuild from the server if reachable; otherwise keep input locked.
        try {
          final snapshot =
              await docRef.get(const GetOptions(source: Source.server));
          if (!mounted || epoch != _roomEpoch) return;
          final remote = OnlineGameSession.fromSnapshot(
              activeSession.roomCode, snapshot.data()!);
          rebuildFromSession(remote, color);
        } catch (_) {
          if (!mounted || epoch != _roomEpoch) return;
          state = state.copyWith(reconnecting: true);
        }
        state = state.copyWith(
            errorMessage:
                'Move could not be confirmed. Return to the menu and resume this room to load its saved state.');
      }
    } finally {
      if (epoch == _roomEpoch) _submitting = false;
    }
  }

  bool _samePrefix(List<OnlineGameMove> a, List<OnlineGameMove> b, int count) {
    if (a.length < count || b.length < count) return false;
    for (var i = 0; i < count; i++) {
      if (a[i].notation != b[i].notation || a[i].player != b[i].player) {
        return false;
      }
    }
    return true;
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

  Future<void> _listenToRoom(String roomCode,
      {required PlayerColor localColor}) async {
    // Ratings sync belongs to authenticated online play, not offline startup.
    unawaited(_ref.read(eloProvider.notifier).initialize());
    _debugLog(
        '_listenToRoom() called: roomCode=$roomCode, localColor=$localColor');
    await _subscription?.cancel();
    final epoch = _roomEpoch;

    final docRef = _firestore.collection('games').doc(roomCode);
    _debugLog('>>> Subscribing to document path: ${docRef.path} <<<');

    _subscription =
        docRef.snapshots(includeMetadataChanges: true).listen((snapshot) {
      if (!mounted || epoch != _roomEpoch) return;
      _debugLog('>>> FIRESTORE SNAPSHOT RECEIVED <<<');
      _debugLog(
          '>>> connectionState: exists=${snapshot.exists}, metadata.isFromCache=${snapshot.metadata.isFromCache}, metadata.hasPendingWrites=${snapshot.metadata.hasPendingWrites} <<<');

      final data = snapshot.data();
      if (data == null) {
        state = state.copyWith(
            errorMessage: 'This room no longer exists.', reconnecting: true);
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
        _debugLog(
            'Deserialization SUCCESS: moves=${session.moves.length}, currentTurn=${session.currentTurn}');
      } catch (e, stackTrace) {
        _debugLog('!!! DESERIALIZATION ERROR !!!');
        _debugLog('Error: $e');
        _debugLog('Stack trace: $stackTrace');
        state = state.copyWith(
            errorMessage: 'Saved room data is invalid.', reconnecting: true);
        return;
      }
      final previousSession = state.session;
      if (previousSession != null &&
          !_samePrefix(
              session.moves,
              previousSession.moves,
              session.moves.length < previousSession.moves.length
                  ? session.moves.length
                  : previousSession.moves.length)) {
        state = state.copyWith(
            errorMessage: 'The saved move history changed unexpectedly.',
            reconnecting: true);
        return;
      }

      _debugLog(
          'Snapshot data: moves=${session.moves.length}, currentTurn=${session.currentTurn}, '
          'status=${session.status}, white=${session.white?.displayName}, black=${session.black?.displayName}');
      _debugLog(
          'Previous state: appliedMoveCount=${state.appliedMoveCount}, session=${previousSession != null}');

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
      final (opponentInactive, opponentDisconnected) =
          _checkOpponentActivity(session);

      _debugLog('Updating state with session, localColor=$localColor');
      state = state.copyWith(
        session: session,
        roomCode: roomCode,
        localColor: localColor,
        opponentInactive: opponentInactive,
        opponentDisconnected: opponentDisconnected,
        opponentJustJoined: opponentJustJoined,
        opponentJustMoved: opponentJustMoved,
        reconnecting: _submitting || snapshot.metadata.isFromCache,
        clearError: true,
      );
      _debugLog('State updated, now calling _syncMovesWithLocalGame');
      _syncMovesWithLocalGame(session);
    }, onError: (error, stackTrace) {
      if (!mounted || epoch != _roomEpoch) return;
      _debugLog('!!! FIRESTORE LISTENER ERROR !!!');
      _debugLog('Error: $error');
      _debugLog('Stack trace: $stackTrace');
      state = state.copyWith(
          reconnecting: true,
          errorMessage:
              'Connection error. Please check your internet connection.');
    });
    _debugLog('Firestore listener setup complete');
  }

  Future<User?> _ensureAuth() async {
    // Both modes share the same restored identity. Google is an optional
    // upgrade in Settings, never a surprise second chooser while joining.
    await _ref.read(accountProvider.notifier).ensurePlayer();
    return FirebaseAuth.instance.currentUser;
  }

  OnlineGamePlayer _playerFor(User user) {
    final playGames = _ref.read(playGamesServiceProvider);
    String displayName;
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      displayName = user.displayName!;
    } else if (playGames.player?.displayName != null) {
      displayName = playGames.player!.displayName;
    } else {
      // Generate random "Player-XXXX" name for anonymous users
      final rand = Random.secure();
      final digits = List.generate(4, (_) => rand.nextInt(10)).join();
      displayName = 'Player-$digits';
    }
    // Sanitize display name for security
    displayName = OnlineGamePlayer.sanitize(displayName);
    // Include ELO rating if available
    final eloState = _ref.read(eloProvider);
    final rating = eloState.localPlayerRating?.rating;
    return OnlineGamePlayer(
        id: user.uid,
        displayName: displayName,
        rating: rating,
        pieceStyle: _ref.read(shareablePieceStyleProvider));
  }

  String _generateRoomCode() {
    final rand = Random.secure();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  void _beginLocalGame(int boardSize, {OnlineGameSession? session}) {
    _debugLog(
        '_beginLocalGame: Starting new local game with boardSize=$boardSize');
    final currentSession = _ref.read(gameSessionProvider);
    _ref.read(scenarioStateProvider.notifier).clearScenario();

    // Use chess clock settings from the online session if available (synced from creator)
    final useChessClock = session?.chessClockEnabled ?? false;
    final clockSeconds = session?.chessClockSeconds;

    _ref.read(gameSessionProvider.notifier).state = currentSession.copyWith(
      mode: GameMode.online,
      clearScenario: true,
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
      _debugLog(
          '_beginLocalGame: Chess clock enabled with ${clockSeconds ?? 'default'} seconds');
    } else {
      _ref.read(chessClockProvider.notifier).stop();
    }
    _debugLog(
        '_beginLocalGame: Local game initialized, gameSessionProvider mode=online');
  }

  void _syncMovesWithLocalGame(OnlineGameSession session) {
    if (session.moves.length < state.appliedMoveCount) {
      _beginLocalGame(session.boardSize, session: session);
      state = state.copyWith(appliedMoveCount: 0);
    }
    for (var i = state.appliedMoveCount; i < session.moves.length; i++) {
      if (!applyOnlineMove(_ref.read(gameStateProvider.notifier),
          _ref.read(gameStateProvider), session.moves[i])) {
        state = state.copyWith(
            errorMessage:
                'Saved move ${i + 1} is invalid. This room cannot continue safely.');
        return;
      }
      _consumeLastMove();
      state = state.copyWith(appliedMoveCount: i + 1);
    }
    final game = _ref.read(gameStateProvider);
    if (game.currentPlayer != session.currentTurn) {
      state = state.copyWith(
          errorMessage:
              'The saved turn does not match the board. Reconnect to this room.');
      return;
    }
    if (session.status == OnlineStatus.finished && !game.isGameOver) {
      final result = switch (session.winner) {
        OnlineWinner.white => GameResult.whiteWins,
        OnlineWinner.black => GameResult.blackWins,
        OnlineWinner.draw => GameResult.draw,
        null => null,
      };
      if (result == null) {
        state = state.copyWith(errorMessage: 'The saved result is missing.');
        return;
      }
      _ref
          .read(gameStateProvider.notifier)
          .loadState(game.copyWith(phase: GamePhase.finished, result: result));
      _ref.read(chessClockProvider.notifier).stop();
    }
    if (session.chessClockEnabled &&
        !game.isGameOver &&
        session.status == OnlineStatus.playing) {
      final balance = OnlineClockBalance.at(session, DateTime.now());
      _ref.read(chessClockProvider.notifier).restore(
          balance.white, balance.black,
          active: session.moves.isEmpty ? null : session.currentTurn);
    }
  }

  Future<void> finishOnTimeout(PlayerColor expired) async {
    final room = state.session;
    if (_endingOnTime || room == null || !room.chessClockEnabled) return;
    final epoch = _roomEpoch;
    _endingOnTime = true;
    try {
      await _firestore.runTransaction((txn) async {
        final doc = _firestore.collection('games').doc(room.roomCode);
        final snapshot = await txn.get(doc);
        if (!snapshot.exists) return;
        final remote =
            OnlineGameSession.fromSnapshot(room.roomCode, snapshot.data()!);
        final balance = OnlineClockBalance.at(remote, DateTime.now());
        if (remote.status != OnlineStatus.playing ||
            remote.currentTurn != expired ||
            (expired == PlayerColor.white ? balance.white : balance.black) >
                0) {
          return;
        }
        txn.update(doc, {
          'status': OnlineStatus.finished.name,
          'winner': expired == PlayerColor.white
              ? OnlineWinner.black.name
              : OnlineWinner.white.name,
          'lastMoveAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {
      if (mounted && epoch == _roomEpoch) {
        state = state.copyWith(
            errorMessage:
                'Clock result could not be confirmed. Reconnect to this room.',
            reconnecting: true);
      }
    } finally {
      if (epoch == _roomEpoch) _endingOnTime = false;
    }
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

  @override
  void dispose() {
    _roomEpoch++;
    unawaited(_subscription?.cancel());
    super.dispose();
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
  final controller = OnlineGameController(ref);
  ref.listen<GameSessionConfig>(gameSessionProvider, (previous, next) {
    if (next.mode != GameMode.online) unawaited(controller.leaveRoom());
  });
  return controller;
});

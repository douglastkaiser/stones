import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/game_provider.dart';
import 'package:stones/providers/online_game_provider.dart';

class FakeAuthAdapter implements OnlineAuthAdapter {
  FakeAuthAdapter({this.user, this.initializeError});

  final OnlineAuthUser? user;
  final Object? initializeError;
  int initializeCalls = 0;

  @override
  OnlineAuthUser? get currentUser => user;

  @override
  Future<void> activateAppCheck() async {}

  @override
  Future<OnlineAuthUser?> ensureAuth(Ref ref, {bool force = false}) async => user;

  @override
  Future<void> initializeFirebase() async {
    initializeCalls++;
    if (initializeError != null) throw initializeError!;
  }
}

class FakeFirestoreAdapter implements OnlineFirestoreAdapter {
  final Map<String, Map<String, dynamic>> rooms = {};
  final Map<String, StreamController<Map<String, dynamic>?>> _controllers = {};
  int recordedMoveCalls = 0;

  StreamController<Map<String, dynamic>?> _controllerFor(String code) {
    return _controllers.putIfAbsent(code, () => StreamController<Map<String, dynamic>?>.broadcast());
  }

  @override
  Future<void> createRoom(String code, Map<String, dynamic> data) async {
    rooms[code] = Map<String, dynamic>.from(data);
    _controllerFor(code).add(rooms[code]);
  }

  @override
  Future<JoinRoomResult> joinRoom({required String code, required OnlineGamePlayer joiner}) async {
    final current = rooms[code];
    if (current == null) throw Exception('Game not found. Check the code and try again.');

    final existing = OnlineGameSession.fromSnapshot(code, current);
    final joinerColor = existing.creatorColor == PlayerColor.white ? PlayerColor.black : PlayerColor.white;

    OnlineGameSession joined;
    if (joinerColor == PlayerColor.white) {
      joined = existing.copyWith(white: joiner, status: OnlineStatus.playing, lastMoveAt: DateTime.now());
    } else {
      joined = existing.copyWith(black: joiner, status: OnlineStatus.playing, lastMoveAt: DateTime.now());
    }

    rooms[code] = joined.toMap()..['lastMoveAt'] = DateTime.now();
    _controllerFor(code).add(rooms[code]);
    return JoinRoomResult(session: joined, localColor: joinerColor);
  }

  @override
  Future<void> recordLocalMove({
    required String roomCode,
    required PlayerColor localColor,
    required MoveRecord move,
    required GameState latestState,
  }) async {
    recordedMoveCalls++;
  }

  @override
  Future<void> updateRoom(String roomCode, Map<String, dynamic> data) async {
    final existing = rooms[roomCode] ?? <String, dynamic>{};
    rooms[roomCode] = {...existing, ...data};
    _controllerFor(roomCode).add(rooms[roomCode]);
  }

  @override
  Stream<Map<String, dynamic>?> watchRoom(String code) => _controllerFor(code).stream;

  void emitSession(OnlineGameSession session) {
    rooms[session.roomCode] = session.toMap()..['lastMoveAt'] = session.lastMoveAt;
    _controllerFor(session.roomCode).add(rooms[session.roomCode]);
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }
}

final _testAuthAdapterProvider = Provider<OnlineAuthAdapter>((ref) {
  throw UnimplementedError('override in tests');
});

final _testFirestoreAdapterProvider = Provider<OnlineFirestoreAdapter>((ref) {
  throw UnimplementedError('override in tests');
});

final _testOnlineGameProvider =
    StateNotifierProvider<OnlineGameController, OnlineGameState>((ref) {
  return OnlineGameController(
    ref,
    authAdapter: ref.read(_testAuthAdapterProvider),
    firestoreAdapter: ref.read(_testFirestoreAdapterProvider),
  );
});

void main() {
  late ProviderContainer container;
  late FakeAuthAdapter auth;
  late FakeFirestoreAdapter store;
  late OnlineGameController controller;

  setUp(() {
    auth = FakeAuthAdapter(user: const OnlineAuthUser(uid: 'u1', displayName: 'Tester'));
    store = FakeFirestoreAdapter();
    container = ProviderContainer(
      overrides: [
        _testAuthAdapterProvider.overrideWithValue(auth),
        _testFirestoreAdapterProvider.overrideWithValue(store),
      ],
    );
    controller = container.read(_testOnlineGameProvider.notifier);
  });

  tearDown(() async {
    controller.dispose();
    await store.dispose();
    container.dispose();
  });

  group('initialize', () {
    test('success clears flags and error', () async {
      final states = <OnlineGameState>[];
      controller.addListener(states.add, fireImmediately: true);

      await controller.initialize();

      expect(states.any((s) => s.initializing), isTrue);
      expect(controller.state.initializing, isFalse);
      expect(controller.state.errorMessage, isNull);
      expect(auth.initializeCalls, 1);
    });

    test('failure sets sanitized error and resets initializing', () async {
      auth = FakeAuthAdapter(user: const OnlineAuthUser(uid: 'u1'), initializeError: Exception('boom'));
      container.dispose();
      container = ProviderContainer(
        overrides: [
          _testAuthAdapterProvider.overrideWithValue(auth),
          _testFirestoreAdapterProvider.overrideWithValue(store),
        ],
      );
      controller = container.read(_testOnlineGameProvider.notifier);

      await controller.initialize();

      expect(controller.state.initializing, isFalse);
      expect(controller.state.errorMessage, contains('Failed to connect to server'));
    });
  });

  group('create/join and transitions', () {
    test('create game toggles creating and sets local state', () async {
      final states = <OnlineGameState>[];
      controller.addListener(states.add, fireImmediately: true);

      await controller.createGame(boardSize: 5, creatorColor: PlayerColor.white);

      expect(states.any((s) => s.creating), isTrue);
      expect(controller.state.creating, isFalse);
      expect(controller.state.roomCode, hasLength(6));
      expect(controller.state.localColor, PlayerColor.white);
      expect(controller.state.session, isNotNull);
      expect(controller.state.errorMessage, isNull);
    });

    test('join game toggles joining and assigns opposite color', () async {
      await controller.createGame(boardSize: 5, creatorColor: PlayerColor.white);
      final code = controller.state.roomCode!;

      final joinerContainer = ProviderContainer(
        overrides: [
          _testAuthAdapterProvider.overrideWithValue(
            FakeAuthAdapter(user: const OnlineAuthUser(uid: 'u2', displayName: 'Joiner')),
          ),
          _testFirestoreAdapterProvider.overrideWithValue(store),
        ],
      );
      addTearDown(joinerContainer.dispose);
      final joiner = joinerContainer.read(_testOnlineGameProvider.notifier);

      final states = <OnlineGameState>[];
      joiner.addListener(states.add, fireImmediately: true);

      await joiner.joinGame(code);

      expect(states.any((s) => s.joining), isTrue);
      expect(joiner.state.joining, isFalse);
      expect(joiner.state.localColor, PlayerColor.black);
      expect(joiner.state.errorMessage, isNull);
    });
  });

  test('recordLocalMove only records on local turn', () async {
    await controller.createGame(boardSize: 5, creatorColor: PlayerColor.white);
    final stateBefore = container.read(gameStateProvider);

    final move = MoveRecord(
      notation: 'a1',
      player: PlayerColor.white,
      turnNumber: 1,
      affectedPositions: const {Position(4, 0)},
      stateBefore: stateBefore,
    );

    await controller.recordLocalMove(move, stateBefore);
    expect(store.recordedMoveCalls, 1);

    final session = controller.state.session!.copyWith(currentTurn: PlayerColor.black);
    store.emitSession(session);
    await Future<void>.delayed(Duration.zero);

    await controller.recordLocalMove(move, stateBefore);
    expect(store.recordedMoveCalls, 1);
  });

  test('sanitizeOnlineErrorMessage strips internal details', () {
    expect(
      sanitizeOnlineErrorMessage(Exception('friendly message')),
      'friendly message',
    );
    expect(
      sanitizeOnlineErrorMessage('network-request-failed'),
      'Network error. Please check your connection.',
    );
    expect(
      sanitizeOnlineErrorMessage(Exception('StackTrace: leak internal')),
      'An error occurred. Please try again.',
    );
  });

  test('stream updates disconnected and reconnecting flags', () async {
    await controller.createGame(boardSize: 5, creatorColor: PlayerColor.white);
    final code = controller.state.roomCode!;

    final stale = controller.state.session!.copyWith(
      roomCode: code,
      status: OnlineStatus.playing,
      black: const OnlineGamePlayer(id: 'u2', displayName: 'Opponent'),
      lastMoveAt: DateTime.now().subtract(const Duration(seconds: 130)),
    );
    store.emitSession(stale);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.opponentDisconnected, isTrue);
    expect(controller.state.opponentInactive, isTrue);
    expect(controller.state.reconnecting, isTrue);

    final active = stale.copyWith(lastMoveAt: DateTime.now());
    store.emitSession(active);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.opponentDisconnected, isFalse);
    expect(controller.state.opponentInactive, isFalse);
    expect(controller.state.reconnecting, isFalse);
  });
}

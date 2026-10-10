import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:games_services/games_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'play_games_save.dart';
import '../hex/hex_match_provider.dart';
import '../providers/providers.dart';

bool get playGamesAvailable =>
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.android &&
    const bool.fromEnvironment('STONES_PLAY_GAMES_ENABLED');

class PlayGamesState {
  final bool isSigningIn;
  final bool attemptedSilentSignIn;
  final PlayerData? player;
  final String? iconImage;
  final int resumedMoveCount;
  final String? errorMessage;

  const PlayGamesState({
    this.isSigningIn = false,
    this.attemptedSilentSignIn = false,
    this.player,
    this.iconImage,
    this.resumedMoveCount = 0,
    this.errorMessage,
  });

  bool get isSignedIn => player != null;

  PlayGamesState copyWith({
    bool? isSigningIn,
    bool? attemptedSilentSignIn,
    PlayerData? player,
    String? iconImage,
    int? resumedMoveCount,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlayGamesState(
      isSigningIn: isSigningIn ?? this.isSigningIn,
      attemptedSilentSignIn:
          attemptedSilentSignIn ?? this.attemptedSilentSignIn,
      player: player ?? this.player,
      iconImage: iconImage ?? this.iconImage,
      resumedMoveCount: resumedMoveCount ?? this.resumedMoveCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PlayGamesService extends StateNotifier<PlayGamesState> {
  PlayGamesService(this._ref) : super(const PlayGamesState()) {
    // Play Games Services is not available on web
    if (playGamesAvailable) {
      _listenToPlayer();
    }
  }

  final Ref _ref;
  StreamSubscription<PlayerData?>? _playerSubscription;
  static const _saveGameName = 'stones_current_game';

  Future<void> initialize() async {
    // Play Games Services is not available on web
    if (!playGamesAvailable) return;
    if (state.isSigningIn || state.isSignedIn || state.attemptedSilentSignIn) {
      return;
    }
    // Explicit opt-in only: GameAuth.signIn is interactive, not silent.
    // Native Play Games restores its own session without us opening a chooser.
    state = state.copyWith(attemptedSilentSignIn: true);
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    super.dispose();
  }

  Future<void> manualSignIn() async {
    if (!playGamesAvailable || state.isSigningIn) return;
    state = state.copyWith(isSigningIn: true, clearError: true);
    try {
      await GameAuth.signIn().timeout(const Duration(seconds: 30));
      if (mounted && !state.isSignedIn) {
        final player = await GameAuth.player
            .firstWhere((p) => p != null)
            .timeout(const Duration(seconds: 5));
        if (mounted) state = state.copyWith(player: player);
      }
      if (mounted) state = state.copyWith(clearError: true);
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
            errorMessage:
                'Play Games could not connect. Check your network and Play Games profile, then try again. Your Stones account and offline play are still available.');
      }
    } finally {
      if (mounted) state = state.copyWith(isSigningIn: false);
    }
  }

  Future<void> _syncQueue = Future<void>.value();

  Future<void> onGameStateChanged(GameState next,
      {GameState? previous, int moveCount = 0}) {
    final session = _ref.read(gameSessionProvider);
    final skip = session.mode == GameMode.online ||
        session.scenario != null ||
        session.isCourtMode ||
        session.chessClockSecondsOverride != null ||
        _ref.read(appSettingsProvider).chessClockEnabled;
    if (!mounted || !state.isSignedIn || skip) return Future<void>.value();
    final work = _syncQueue.then((_) => _syncGame(next,
        previous: previous, moveCount: moveCount, session: session));
    _syncQueue = work.catchError((Object _) {});
    return work;
  }

  Future<void> _syncGame(
    GameState next, {
    GameState? previous,
    int moveCount = 0,
    required GameSessionConfig session,
  }) async {
    if (!mounted || !state.isSignedIn) return;
    try {
      if (next.turnNumber == 1 && next.board.occupiedPositions.isEmpty) {
        if (state.resumedMoveCount != 0) {
          state = state.copyWith(resumedMoveCount: 0);
        }
        return; // Opening an empty board must not overwrite a resumable save.
      }

      final effectiveMoveCount = moveCount + state.resumedMoveCount;
      if (next.isGameOver) {
        if (previous?.isGameOver != true) {
          await _handleGameFinished(next,
              moveCount: effectiveMoveCount, session: session);
        }
        await _clearCloudSave();
        if (mounted) state = state.copyWith(resumedMoveCount: 0);
      } else {
        await _saveCloudGame(next,
            moveCount: effectiveMoveCount, session: session);
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
            errorMessage:
                'Play Games sync failed. Your current match is still available on this device.');
      }
    }
  }

  Future<void> _listenToPlayer() async {
    _playerSubscription = GameAuth.player.listen((playerData) async {
      if (!mounted) return;
      state = PlayGamesState(
          player: playerData,
          isSigningIn: state.isSigningIn,
          attemptedSilentSignIn: state.attemptedSilentSignIn,
          resumedMoveCount: state.resumedMoveCount);
      if (playerData != null) await _loadPlayerImage();
    }, onError: (Object _) {
      if (!mounted || (!state.isSignedIn && !state.isSigningIn)) return;
      if (mounted) {
        state = state.copyWith(
            errorMessage:
                'Play Games disconnected. You can retry from Settings.');
      }
    });
  }

  Future<void> _loadPlayerImage() async {
    final player = state.player;
    try {
      final icon = await GamesServices.getPlayerIconImage();
      if (mounted &&
          identical(state.player, player) &&
          icon != null &&
          icon.isNotEmpty) {
        state = state.copyWith(iconImage: icon.replaceAll('\n', ''));
      }
    } catch (_) {}
  }

  Future<void> _handleGameFinished(
    GameState state, {
    required int moveCount,
    required GameSessionConfig session,
  }) async {
    final humanWon = session.mode == GameMode.vsComputer &&
        (state.result == GameResult.whiteWins
                ? PlayerColor.white
                : PlayerColor.black) ==
            session.vsComputerPlayerColor;
    if (!humanWon || state.result == GameResult.draw) {
      await _resetCurrentStreak();
      return;
    }

    await _updateWinStats(state, moveCount: moveCount);
    await _unlockAchievements(state, moveCount: moveCount);
    await _submitLeaderboards(moveCount);
  }

  Future<void> _updateWinStats(
    GameState state, {
    required int moveCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final totalWins = (prefs.getInt(_PrefsKeys.totalWins) ?? 0) + 1;
    final currentStreak = (prefs.getInt(_PrefsKeys.currentStreak) ?? 0) + 1;
    final longestStreak =
        currentStreak > (prefs.getInt(_PrefsKeys.longestStreak) ?? 0)
            ? currentStreak
            : (prefs.getInt(_PrefsKeys.longestStreak) ?? 0);

    await prefs.setInt(_PrefsKeys.totalWins, totalWins);
    await prefs.setInt(_PrefsKeys.currentStreak, currentStreak);
    await prefs.setInt(_PrefsKeys.longestStreak, longestStreak);

    if (state.winReason == WinReason.road) {
      final roadWins = (prefs.getInt(_PrefsKeys.roadWins) ?? 0) + 1;
      await prefs.setInt(_PrefsKeys.roadWins, roadWins);
    }

    if (state.winReason == WinReason.flats) {
      final flatWins = (prefs.getInt(_PrefsKeys.flatWins) ?? 0) + 1;
      await prefs.setInt(_PrefsKeys.flatWins, flatWins);
    }

    await prefs.setInt(_PrefsKeys.lastMoveCount, moveCount);

    await _score(PlayGamesIds.leaderboards.totalWins, totalWins);

    await _score(PlayGamesIds.leaderboards.longestStreak, longestStreak);
  }

  Future<void> _unlockAchievements(GameState state,
      {required int moveCount}) async {
    await _unlock(PlayGamesIds.achievements.firstWin);
    if (state.winReason == WinReason.road) {
      await _increment(PlayGamesIds.achievements.roadBuilder);
    }
    if (state.winReason == WinReason.flats) {
      await _increment(PlayGamesIds.achievements.flatEarth);
    }
    if (state.boardSize == 8) {
      await _unlock(PlayGamesIds.achievements.giantSlayer);
    }
    if (moveCount > 0 && moveCount < 20) {
      await _unlock(PlayGamesIds.achievements.speedDemon);
    }
    if (state.winReason == WinReason.road && _roadHasCapstone(state)) {
      await _unlock(PlayGamesIds.achievements.capstoneMaster);
    }
  }

  Future<void> _unlock(String id) async {
    if (id.isNotEmpty) {
      await GamesServices.unlock(achievement: Achievement(androidID: id));
    }
  }

  Future<void> _increment(String id) async {
    if (id.isNotEmpty) {
      await GamesServices.increment(
          achievement: Achievement(androidID: id, steps: 1));
    }
  }

  Future<void> _score(String id, int value) async {
    if (id.isNotEmpty) {
      await GamesServices.submitScore(
          score: Score(androidLeaderboardID: id, value: value));
    }
  }

  Future<void> _submitLeaderboards(int moveCount) async {
    if (moveCount > 0) {
      await _score(PlayGamesIds.leaderboards.fastestWin, moveCount);
    }
  }

  bool _roadHasCapstone(GameState state) {
    final winner = state.result == GameResult.whiteWins
        ? PlayerColor.white
        : PlayerColor.black;
    final winningPath = _findWinningRoad(state, winner);
    if (winningPath == null) return false;

    for (final pos in winningPath) {
      final top = state.board.stackAt(pos).topPiece;
      if (top?.type == PieceType.capstone && top?.color == winner) {
        return true;
      }
    }
    return false;
  }

  Set<Position>? _findWinningRoad(GameState state, PlayerColor color) {
    final size = state.boardSize;
    final leftEdge = <Position>[];
    for (int r = 0; r < size; r++) {
      final pos = Position(r, 0);
      if (_controlsForRoad(state, pos, color)) {
        leftEdge.add(pos);
      }
    }

    for (final start in leftEdge) {
      final path =
          _findPathToEdge(state, start, color, (p) => p.col == size - 1);
      if (path != null) return path;
    }

    final topEdge = <Position>[];
    for (int c = 0; c < size; c++) {
      final pos = Position(0, c);
      if (_controlsForRoad(state, pos, color)) {
        topEdge.add(pos);
      }
    }

    for (final start in topEdge) {
      final path =
          _findPathToEdge(state, start, color, (p) => p.row == size - 1);
      if (path != null) return path;
    }

    return null;
  }

  Set<Position>? _findPathToEdge(
    GameState state,
    Position start,
    PlayerColor color,
    bool Function(Position) isTargetEdge,
  ) {
    final visited = <Position>{};
    final parent = <Position, Position?>{};
    final queue = [start];
    parent[start] = null;

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (visited.contains(current)) continue;
      visited.add(current);

      if (isTargetEdge(current)) {
        final path = <Position>{};
        var pos = current;
        while (true) {
          path.add(pos);
          final nextPos = parent[pos];
          if (nextPos == null) break;
          pos = nextPos;
        }
        return path;
      }

      for (final adj in current.adjacentPositions(state.boardSize)) {
        if (_controlsForRoad(state, adj, color) && !visited.contains(adj)) {
          parent[adj] = current;
          queue.add(adj);
        }
      }
    }
    return null;
  }

  bool _controlsForRoad(GameState state, Position pos, PlayerColor color) {
    final top = state.board.stackAt(pos).topPiece;
    if (top == null || top.color != color) return false;
    return top.type != PieceType.standing;
  }

  Future<void> _resetCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_PrefsKeys.currentStreak, 0);
  }

  Future<void> resetLocalStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_PrefsKeys.totalWins);
    await prefs.remove(_PrefsKeys.currentStreak);
    await prefs.remove(_PrefsKeys.longestStreak);
    await prefs.remove(_PrefsKeys.roadWins);
    await prefs.remove(_PrefsKeys.flatWins);
    await prefs.remove(_PrefsKeys.lastMoveCount);
    state = state.copyWith(resumedMoveCount: 0);
  }

  Future<void> _saveCloudGame(
    GameState gameState, {
    required int moveCount,
    required GameSessionConfig session,
  }) async {
    final payload = PlayGamesSave(
      state: gameState,
      moveCount: moveCount,
      session: session,
    );
    final data = jsonEncode(payload.toJson());
    await GamesServices.saveGame(data: data, name: _saveGameName);
  }

  Future<void> _clearCloudSave() async {
    try {
      await GamesServices.deleteGame(name: _saveGameName);
    } catch (_) {}
  }

  bool _canRestore() {
    final current = _ref.read(gameStateProvider);
    final session = _ref.read(gameSessionProvider);
    return (current.isGameOver || current.board.occupiedPositions.isEmpty) &&
        session.mode != GameMode.online &&
        session.scenario == null &&
        !session.isCourtMode &&
        session.chessClockSecondsOverride == null &&
        !_ref.read(appSettingsProvider).chessClockEnabled &&
        _ref.read(onlineGameProvider).session == null &&
        _ref.read(hexMatchProvider).room == null;
  }

  Future<bool> restoreCloudGame() async {
    if (!mounted || !playGamesAvailable || !state.isSignedIn) return false;
    if (!_canRestore()) {
      state = state.copyWith(
          errorMessage:
              'Finish or reset your current match before restoring a cloud save.');
      return false;
    }
    try {
      await _syncQueue;
      final raw = await GamesServices.loadGame(name: _saveGameName);
      if (raw == null || raw.isEmpty) return false;
      final bundle =
          PlayGamesSave.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!mounted || !_canRestore()) return false;
      _applyLoadedGame(bundle);
      return true;
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
            errorMessage:
                'This cloud save could not be restored safely. Your current match is unchanged.');
      }
      return false;
    }
  }

  void _applyLoadedGame(PlayGamesSave bundle) {
    final gameNotifier = _ref.read(gameStateProvider.notifier);
    _ref.read(gameSessionProvider.notifier).state = bundle.session;
    gameNotifier.loadState(bundle.state);
    _ref.read(uiStateProvider.notifier).reset();
    _ref.read(animationStateProvider.notifier).reset();
    _ref.read(moveHistoryProvider.notifier).clear();
    _ref.read(lastMoveProvider.notifier).state = null;
    state =
        state.copyWith(resumedMoveCount: bundle.moveCount, clearError: true);
  }
}

class _PrefsKeys {
  static const totalWins = 'play_games_total_wins';
  static const currentStreak = 'play_games_current_streak';
  static const longestStreak = 'play_games_longest_streak';
  static const roadWins = 'play_games_road_wins';
  static const flatWins = 'play_games_flat_wins';
  static const lastMoveCount = 'play_games_last_move_count';
}

class PlayGamesIds {
  static const achievements = _AchievementIds();
  static const leaderboards = _LeaderboardIds();
}

class _AchievementIds {
  const _AchievementIds();

  final String firstWin =
      const String.fromEnvironment('PLAY_GAMES_ACHIEVEMENT_FIRST_WIN');
  final String roadBuilder =
      const String.fromEnvironment('PLAY_GAMES_ACHIEVEMENT_ROAD_BUILDER');
  final String flatEarth =
      const String.fromEnvironment('PLAY_GAMES_ACHIEVEMENT_FLAT_EARTH');
  final String giantSlayer =
      const String.fromEnvironment('PLAY_GAMES_ACHIEVEMENT_GIANT_SLAYER');
  final String speedDemon =
      const String.fromEnvironment('PLAY_GAMES_ACHIEVEMENT_SPEED_DEMON');
  final String capstoneMaster =
      const String.fromEnvironment('PLAY_GAMES_ACHIEVEMENT_CAPSTONE_MASTER');
}

class _LeaderboardIds {
  const _LeaderboardIds();

  final String totalWins =
      const String.fromEnvironment('PLAY_GAMES_LEADERBOARD_TOTAL_WINS');
  final String longestStreak =
      const String.fromEnvironment('PLAY_GAMES_LEADERBOARD_LONGEST_STREAK');
  final String fastestWin =
      const String.fromEnvironment('PLAY_GAMES_LEADERBOARD_FASTEST_WIN');
}

final playGamesServiceProvider =
    StateNotifierProvider<PlayGamesService, PlayGamesState>((ref) {
  return PlayGamesService(ref);
});

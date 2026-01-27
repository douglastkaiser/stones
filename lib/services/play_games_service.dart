import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:games_services/games_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/providers.dart';

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
      attemptedSilentSignIn: attemptedSilentSignIn ?? this.attemptedSilentSignIn,
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
    if (!kIsWeb) {
      _listenToPlayer();
    }
  }

  final Ref _ref;
  StreamSubscription<PlayerData?>? _playerSubscription;
  static const _saveGameName = 'stones_current_game';

  Future<void> initialize() async {
    // Play Games Services is not available on web
    if (kIsWeb) return;
    if (state.isSigningIn || state.isSignedIn || state.attemptedSilentSignIn) {
      return;
    }
    await silentSignIn();
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    super.dispose();
  }

  Future<void> silentSignIn() async {
    // Play Games Services is not available on web
    if (kIsWeb) return;
    state = state.copyWith(isSigningIn: true, attemptedSilentSignIn: true);
    try {
      await GameAuth.signIn();
      // Clear any previous error on successful sign-in
      state = state.copyWith(clearError: true);
    } catch (e) {
      // Silent sign-in failure is expected if user hasn't signed in before
      // Don't show error for silent sign-in, but log it
      // User can manually sign in later if needed
    } finally {
      state = state.copyWith(isSigningIn: false);
    }
  }

  Future<void> manualSignIn() async {
    // Play Games Services is not available on web
    if (kIsWeb) return;
    state = state.copyWith(isSigningIn: true, clearError: true);
    try {
      await GameAuth.signIn();
      // Clear any previous error on successful sign-in
      state = state.copyWith(clearError: true);
    } catch (e) {
      // Store the error message for the UI to display
      state = state.copyWith(
        errorMessage: 'Failed to sign in with Google Play Games. Error: $e',
      );
    } finally {
      state = state.copyWith(isSigningIn: false);
    }
  }

  Future<void> onGameStateChanged(
    GameState next, {
    GameState? previous,
    int moveCount = 0,
  }) async {
    if (!state.isSignedIn) return;

    if (next.turnNumber == 1 && next.board.occupiedPositions.isEmpty) {
      if (state.resumedMoveCount != 0) {
        state = state.copyWith(resumedMoveCount: 0);
      }
    }

    final effectiveMoveCount = moveCount + state.resumedMoveCount;
    if (next.isGameOver) {
      if (previous?.isGameOver != true) {
        await _handleGameFinished(next, moveCount: effectiveMoveCount);
      }
      await _clearCloudSave();
      state = state.copyWith(resumedMoveCount: 0);
    } else {
      await _saveCloudGame(next, moveCount: effectiveMoveCount);
    }
  }

  Future<void> _listenToPlayer() async {
    _playerSubscription = GameAuth.player.listen((playerData) async {
      state = state.copyWith(player: playerData);
      if (playerData != null) {
        await _loadPlayerImage();
        await _maybeLoadCloudGame();
      }
    });
  }

  Future<void> _loadPlayerImage() async {
    try {
      final icon = await GamesServices.getPlayerIconImage();
      if (icon != null && icon.isNotEmpty) {
        state = state.copyWith(iconImage: icon.replaceAll('\n', ''));
      }
    } catch (_) {}
  }

  Future<void> _handleGameFinished(
    GameState state, {
    required int moveCount,
  }) async {
    if (state.result == GameResult.draw) {
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

    await GamesServices.submitScore(
      score: Score(
        androidLeaderboardID: PlayGamesIds.leaderboards.totalWins,
        value: totalWins,
      ),
    );

    await GamesServices.submitScore(
      score: Score(
        androidLeaderboardID: PlayGamesIds.leaderboards.longestStreak,
        value: longestStreak,
      ),
    );
  }

  Future<void> _unlockAchievements(
    GameState state, {
    required int moveCount,
  }) async {
    await GamesServices.unlock(
      achievement: Achievement(androidID: PlayGamesIds.achievements.firstWin),
    );

    if (state.winReason == WinReason.road) {
      await GamesServices.increment(
        achievement: Achievement(
          androidID: PlayGamesIds.achievements.roadBuilder,
          steps: 1,
        ),
      );
    }

    if (state.winReason == WinReason.flats) {
      await GamesServices.increment(
        achievement: Achievement(
          androidID: PlayGamesIds.achievements.flatEarth,
          steps: 1,
        ),
      );
    }

    if (state.boardSize == 8) {
      await GamesServices.unlock(
        achievement: Achievement(androidID: PlayGamesIds.achievements.giantSlayer),
      );
    }

    if (moveCount > 0 && moveCount < 20) {
      await GamesServices.unlock(
        achievement: Achievement(androidID: PlayGamesIds.achievements.speedDemon),
      );
    }

    if (state.winReason == WinReason.road && _roadHasCapstone(state)) {
      await GamesServices.unlock(
        achievement:
            Achievement(androidID: PlayGamesIds.achievements.capstoneMaster),
      );
    }
  }

  Future<void> _submitLeaderboards(int moveCount) async {
    await GamesServices.submitScore(
      score: Score(
        androidLeaderboardID: PlayGamesIds.leaderboards.fastestWin,
        value: moveCount,
      ),
    );
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
      final path = _findPathToEdge(state, start, color, (p) => p.col == size - 1);
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
      final path = _findPathToEdge(state, start, color, (p) => p.row == size - 1);
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
  }) async {
    final payload = _GameSaveBundle(
      state: gameState,
      moveCount: moveCount,
    );
    final data = jsonEncode(payload.toJson());
    await GamesServices.saveGame(data: data, name: _saveGameName);
  }

  Future<void> _clearCloudSave() async {
    try {
      await GamesServices.deleteGame(name: _saveGameName);
    } catch (_) {}
  }

  Future<void> _maybeLoadCloudGame() async {
    final gameState = _ref.read(gameStateProvider);
    final hasLocalProgress = !gameState.isGameOver &&
        (gameState.turnNumber > 1 || gameState.board.occupiedPositions.isNotEmpty);
    if (hasLocalProgress) return;

    final savedGames = await GamesServices.getSavedGames();
    if (savedGames == null || savedGames.isEmpty) return;

    savedGames.sort((a, b) => b.modificationDate.compareTo(a.modificationDate));
    final latest = savedGames.first;
    final raw = await GamesServices.loadGame(name: latest.name);
    if (raw == null || raw.isEmpty) return;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final bundle = _GameSaveBundle.fromJson(json);
      _applyLoadedGame(bundle);
    } catch (_) {}
  }

  void _applyLoadedGame(_GameSaveBundle bundle) {
    final gameNotifier = _ref.read(gameStateProvider.notifier);
    gameNotifier.loadState(bundle.state);
    _ref.read(uiStateProvider.notifier).reset();
    _ref.read(animationStateProvider.notifier).reset();
    _ref.read(moveHistoryProvider.notifier).clear();
    _ref.read(lastMoveProvider.notifier).state = null;
    state = state.copyWith(resumedMoveCount: bundle.moveCount);
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

  final String firstWin = 'achievement_first_win_placeholder';
  final String roadBuilder = 'achievement_road_builder_placeholder';
  final String flatEarth = 'achievement_flat_earth_placeholder';
  final String giantSlayer = 'achievement_giant_slayer_placeholder';
  final String speedDemon = 'achievement_speed_demon_placeholder';
  final String capstoneMaster = 'achievement_capstone_master_placeholder';
}

class _LeaderboardIds {
  const _LeaderboardIds();

  final String totalWins = 'leaderboard_total_wins_placeholder';
  final String longestStreak = 'leaderboard_longest_streak_placeholder';
  final String fastestWin = 'leaderboard_fastest_win_placeholder';
}

class _GameSaveBundle {
  const _GameSaveBundle({required this.state, required this.moveCount});

  final GameState state;
  final int moveCount;

  Map<String, dynamic> toJson() {
    return {
      'state': _GameStateCodec.toJson(state),
      'moveCount': moveCount,
    };
  }

  factory _GameSaveBundle.fromJson(Map<String, dynamic> json) {
    return _GameSaveBundle(
      state: _GameStateCodec.fromJson(json['state'] as Map<String, dynamic>),
      moveCount: json['moveCount'] as int? ?? 0,
    );
  }
}

class _GameStateCodec {
  static Map<String, dynamic> toJson(GameState state) {
    return {
      'boardSize': state.boardSize,
      'currentPlayer': state.currentPlayer.name,
      'whitePieces': _playerPiecesToJson(state.whitePieces),
      'blackPieces': _playerPiecesToJson(state.blackPieces),
      'turnNumber': state.turnNumber,
      'phase': state.phase.name,
      'result': state.result?.name,
      'winReason': state.winReason?.name,
      'cells': [
        for (int r = 0; r < state.boardSize; r++)
          [
            for (int c = 0; c < state.boardSize; c++)
              state.board.cells[r][c].pieces
                  .map(_pieceToJson)
                  .toList(),
          ]
      ],
    };
  }

  static GameState fromJson(Map<String, dynamic> json) {
    final size = json['boardSize'] as int;
    var board = Board.empty(size);
    final cells = (json['cells'] as List<dynamic>);
    for (int r = 0; r < size; r++) {
      final row = cells[r] as List<dynamic>;
      for (int c = 0; c < size; c++) {
        final pieces = (row[c] as List<dynamic>)
            .map((e) => _pieceFromJson(e as Map<String, dynamic>))
            .toList();
        board = board.setStack(Position(r, c), PieceStack(pieces));
      }
    }

    return GameState(
      board: board,
      currentPlayer:
          PlayerColor.values.firstWhere((e) => e.name == json['currentPlayer']),
      whitePieces: _playerPiecesFromJson(json['whitePieces'] as Map<String, dynamic>),
      blackPieces: _playerPiecesFromJson(json['blackPieces'] as Map<String, dynamic>),
      turnNumber: json['turnNumber'] as int,
      phase: GamePhase.values.firstWhere((e) => e.name == json['phase']),
      result: json['result'] == null
          ? null
          : GameResult.values.firstWhere((e) => e.name == json['result']),
      winReason: json['winReason'] == null
          ? null
          : WinReason.values.firstWhere((e) => e.name == json['winReason']),
    );
  }

  static Map<String, dynamic> _playerPiecesToJson(PlayerPieces pieces) {
    return {
      'color': pieces.color.name,
      'flat': pieces.flatStones,
      'cap': pieces.capstones,
    };
  }

  static PlayerPieces _playerPiecesFromJson(Map<String, dynamic> json) {
    return PlayerPieces(
      color: PlayerColor.values.firstWhere((e) => e.name == json['color']),
      flatStones: json['flat'] as int,
      capstones: json['cap'] as int,
    );
  }

  static Map<String, dynamic> _pieceToJson(Piece piece) {
    return {
      'type': piece.type.name,
      'color': piece.color.name,
    };
  }

  static Piece _pieceFromJson(Map<String, dynamic> json) {
    return Piece(
      type: PieceType.values.firstWhere((e) => e.name == json['type']),
      color: PlayerColor.values.firstWhere((e) => e.name == json['color']),
    );
  }
}

final playGamesServiceProvider =
    StateNotifierProvider<PlayGamesService, PlayGamesState>((ref) {
  return PlayGamesService(ref);
});

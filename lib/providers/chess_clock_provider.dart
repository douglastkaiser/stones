import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'settings_provider.dart';

/// State for the chess clock
class ChessClockState {
  final int whiteTimeRemaining; // in seconds
  final int blackTimeRemaining; // in seconds
  final PlayerColor? activePlayer;
  final bool isRunning;
  final bool isExpired;
  final PlayerColor? expiredPlayer;

  const ChessClockState({
    required this.whiteTimeRemaining,
    required this.blackTimeRemaining,
    this.activePlayer,
    this.isRunning = false,
    this.isExpired = false,
    this.expiredPlayer,
  });

  ChessClockState copyWith({
    int? whiteTimeRemaining,
    int? blackTimeRemaining,
    PlayerColor? activePlayer,
    bool? isRunning,
    bool? isExpired,
    PlayerColor? expiredPlayer,
    bool clearActivePlayer = false,
  }) {
    return ChessClockState(
      whiteTimeRemaining: whiteTimeRemaining ?? this.whiteTimeRemaining,
      blackTimeRemaining: blackTimeRemaining ?? this.blackTimeRemaining,
      activePlayer: clearActivePlayer ? null : (activePlayer ?? this.activePlayer),
      isRunning: isRunning ?? this.isRunning,
      isExpired: isExpired ?? this.isExpired,
      expiredPlayer: expiredPlayer ?? this.expiredPlayer,
    );
  }

  /// Format time as MM:SS
  String formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String get whiteTimeFormatted => formatTime(whiteTimeRemaining);
  String get blackTimeFormatted => formatTime(blackTimeRemaining);
}

/// Notifier for the chess clock
class ChessClockNotifier extends StateNotifier<ChessClockState> {
  Timer? _timer;

  ChessClockNotifier()
      : super(const ChessClockState(
          whiteTimeRemaining: 300,
          blackTimeRemaining: 300,
        ));

  /// Initialize the clock with time based on board size (fully resets state)
  void initialize(int boardSize) {
    _timer?.cancel();
    final time = ChessClockDefaults.getTimeForBoardSize(boardSize);
    // Create fresh state with all defaults (isRunning=false, isExpired=false, etc.)
    state = ChessClockState(
      whiteTimeRemaining: time,
      blackTimeRemaining: time,
      // All other fields use default values: activePlayer=null, isRunning=false, isExpired=false, expiredPlayer=null
    );
  }

  /// Start the clock for a player
  void start(PlayerColor player) {
    if (state.isExpired) return;

    _timer?.cancel();
    state = state.copyWith(
      activePlayer: player,
      isRunning: true,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  /// Pause the clock
  void pause() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
  }

  /// Stop the clock completely and reset to default state
  void stop() {
    _timer?.cancel();
    // Reset to default state (300 seconds is just a placeholder, won't be shown)
    state = const ChessClockState(
      whiteTimeRemaining: 300,
      blackTimeRemaining: 300,
    );
  }

  /// Switch to the other player
  void switchPlayer() {
    if (state.isExpired || state.activePlayer == null) return;

    final newPlayer = state.activePlayer == PlayerColor.white
        ? PlayerColor.black
        : PlayerColor.white;

    state = state.copyWith(activePlayer: newPlayer);
  }

  void _tick() {
    if (!state.isRunning || state.activePlayer == null) return;

    if (state.activePlayer == PlayerColor.white) {
      final newTime = state.whiteTimeRemaining - 1;
      if (newTime <= 0) {
        _timer?.cancel();
        state = state.copyWith(
          whiteTimeRemaining: 0,
          isRunning: false,
          isExpired: true,
          expiredPlayer: PlayerColor.white,
        );
      } else {
        state = state.copyWith(whiteTimeRemaining: newTime);
      }
    } else {
      final newTime = state.blackTimeRemaining - 1;
      if (newTime <= 0) {
        _timer?.cancel();
        state = state.copyWith(
          blackTimeRemaining: 0,
          isRunning: false,
          isExpired: true,
          expiredPlayer: PlayerColor.black,
        );
      } else {
        state = state.copyWith(blackTimeRemaining: newTime);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Provider for the chess clock
final chessClockProvider =
    StateNotifierProvider<ChessClockNotifier, ChessClockState>((ref) {
  return ChessClockNotifier();
});

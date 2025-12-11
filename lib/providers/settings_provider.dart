import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings keys for SharedPreferences
class SettingsKeys {
  static const String boardSize = 'board_size';
  static const String soundMuted = 'sound_muted';
  static const String themeMode = 'theme_mode';
  static const String chessClockEnabled = 'chess_clock_enabled';
}

/// Default chess clock times in seconds by board size
/// 4x4: 2 minutes, 5x5: 5 minutes, 6x6: 10 minutes
class ChessClockDefaults {
  static int getTimeForBoardSize(int boardSize) {
    switch (boardSize) {
      case 3:
        return 60; // 1 minute
      case 4:
        return 120; // 2 minutes
      case 5:
        return 300; // 5 minutes
      case 6:
        return 600; // 10 minutes
      case 7:
        return 900; // 15 minutes
      case 8:
        return 1200; // 20 minutes
      default:
        return 300; // 5 minutes default
    }
  }

  static String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

/// App settings state
class AppSettings {
  final int boardSize;
  final bool isSoundMuted;
  final ThemeMode themeMode;
  final bool chessClockEnabled;

  const AppSettings({
    this.boardSize = 5,
    this.isSoundMuted = false,
    this.themeMode = ThemeMode.system,
    this.chessClockEnabled = false,
  });

  AppSettings copyWith({
    int? boardSize,
    bool? isSoundMuted,
    ThemeMode? themeMode,
    bool? chessClockEnabled,
  }) {
    return AppSettings(
      boardSize: boardSize ?? this.boardSize,
      isSoundMuted: isSoundMuted ?? this.isSoundMuted,
      themeMode: themeMode ?? this.themeMode,
      chessClockEnabled: chessClockEnabled ?? this.chessClockEnabled,
    );
  }
}

/// Notifier for app settings with persistence
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings());

  /// Load settings from SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(SettingsKeys.themeMode);
    state = AppSettings(
      boardSize: prefs.getInt(SettingsKeys.boardSize) ?? 5,
      isSoundMuted: prefs.getBool(SettingsKeys.soundMuted) ?? false,
      themeMode: themeModeIndex != null
          ? ThemeMode.values[themeModeIndex]
          : ThemeMode.system,
      chessClockEnabled: prefs.getBool(SettingsKeys.chessClockEnabled) ?? false,
    );
  }

  /// Set board size and persist
  Future<void> setBoardSize(int size) async {
    state = state.copyWith(boardSize: size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SettingsKeys.boardSize, size);
  }

  /// Set sound muted and persist
  Future<void> setSoundMuted(bool muted) async {
    state = state.copyWith(isSoundMuted: muted);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.soundMuted, muted);
  }

  /// Toggle sound muted
  Future<void> toggleSoundMuted() async {
    await setSoundMuted(!state.isSoundMuted);
  }

  /// Set theme mode and persist
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SettingsKeys.themeMode, mode.index);
  }

  /// Set chess clock enabled and persist
  Future<void> setChessClockEnabled(bool enabled) async {
    state = state.copyWith(chessClockEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.chessClockEnabled, enabled);
  }
}

/// Provider for app settings
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});

/// Derived provider for board size only
final selectedBoardSizeProvider = Provider<int>((ref) {
  return ref.watch(appSettingsProvider).boardSize;
});

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings keys for SharedPreferences
class SettingsKeys {
  static const String boardSize = 'board_size';
  static const String soundMuted = 'sound_muted';
  static const String themeMode = 'theme_mode';
  static const String chessClockEnabled = 'chess_clock_enabled';
  static const String chessClockDefaults = 'chess_clock_defaults';
}

/// Default chess clock times in seconds by board size
/// 4x4: 2 minutes, 5x5: 5 minutes, 6x6: 10 minutes
class ChessClockDefaults {
  static const Map<int, int> defaultTimes = {
    3: 60,
    4: 120,
    5: 300,
    6: 600,
    7: 900,
    8: 1200,
  };

  static int getTimeForBoardSize(int boardSize) {
    return defaultTimes[boardSize] ?? 300; // 5 minutes default
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
  final Map<int, int> chessClockDefaults;

  const AppSettings({
    this.boardSize = 5,
    this.isSoundMuted = false,
    this.themeMode = ThemeMode.system,
    this.chessClockEnabled = false,
    this.chessClockDefaults = ChessClockDefaults.defaultTimes,
  });

  AppSettings copyWith({
    int? boardSize,
    bool? isSoundMuted,
    ThemeMode? themeMode,
    bool? chessClockEnabled,
    Map<int, int>? chessClockDefaults,
  }) {
    return AppSettings(
      boardSize: boardSize ?? this.boardSize,
      isSoundMuted: isSoundMuted ?? this.isSoundMuted,
      themeMode: themeMode ?? this.themeMode,
      chessClockEnabled: chessClockEnabled ?? this.chessClockEnabled,
      chessClockDefaults: chessClockDefaults ?? this.chessClockDefaults,
    );
  }

  int timeForBoardSize(int size) {
    return chessClockDefaults[size] ?? ChessClockDefaults.getTimeForBoardSize(size);
  }
}

/// Notifier for app settings with persistence
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings());

  /// Load settings from SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(SettingsKeys.themeMode);
    final defaultsJson = prefs.getString(SettingsKeys.chessClockDefaults);
    final defaultsMap = defaultsJson != null
        ? Map<String, dynamic>.from(jsonDecode(defaultsJson) as Map)
        : <String, dynamic>{};
    final parsedDefaults = <int, int>{
      for (final entry in ChessClockDefaults.defaultTimes.entries)
        entry.key: (defaultsMap['${entry.key}x${entry.key}'] as num?)?.toInt() ?? entry.value,
    };
    state = AppSettings(
      boardSize: prefs.getInt(SettingsKeys.boardSize) ?? 5,
      isSoundMuted: prefs.getBool(SettingsKeys.soundMuted) ?? false,
      themeMode: themeModeIndex != null
          ? ThemeMode.values[themeModeIndex]
          : ThemeMode.system,
      chessClockEnabled: prefs.getBool(SettingsKeys.chessClockEnabled) ?? false,
      chessClockDefaults: parsedDefaults,
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

  /// Set the default chess clock time (in seconds) for a board size and persist
  Future<void> setChessClockDefault(int boardSize, int seconds) async {
    final updatedDefaults = Map<int, int>.from(state.chessClockDefaults);
    updatedDefaults[boardSize] = seconds;
    state = state.copyWith(chessClockDefaults: updatedDefaults);

    final prefs = await SharedPreferences.getInstance();
    final serialized = jsonEncode({
      for (final entry in updatedDefaults.entries) '${entry.key}x${entry.key}': entry.value,
    });
    await prefs.setString(SettingsKeys.chessClockDefaults, serialized);
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

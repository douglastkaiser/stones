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
  static const Map<int, int> baseTimes = {
    3: 60,
    4: 120,
    5: 300,
    6: 600,
    7: 900,
    8: 1200,
  };

  static int getTimeForBoardSize(int boardSize) {
    return baseTimes[boardSize] ?? 300;
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
    this.chessClockDefaults = const {},
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

  int chessClockSecondsForSize(int boardSize) {
    return chessClockDefaults[boardSize] ?? ChessClockDefaults.getTimeForBoardSize(boardSize);
  }
}

/// Notifier for app settings with persistence
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings());

  /// Load settings from SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(SettingsKeys.themeMode);
    final defaults = _parseChessClockDefaults(
      prefs.getString(SettingsKeys.chessClockDefaults),
    );
    state = AppSettings(
      boardSize: prefs.getInt(SettingsKeys.boardSize) ?? 5,
      isSoundMuted: prefs.getBool(SettingsKeys.soundMuted) ?? false,
      themeMode: themeModeIndex != null
          ? ThemeMode.values[themeModeIndex]
          : ThemeMode.system,
      chessClockEnabled: prefs.getBool(SettingsKeys.chessClockEnabled) ?? false,
      chessClockDefaults: defaults,
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

  Future<void> setChessClockDefault(int boardSize, int seconds) async {
    final updated = Map<int, int>.from(state.chessClockDefaults);
    updated[boardSize] = seconds;
    state = state.copyWith(chessClockDefaults: Map.unmodifiable(updated));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SettingsKeys.chessClockDefaults, _encodeChessClockDefaults(updated));
  }

  Map<int, int> _parseChessClockDefaults(String? raw) {
    final defaults = Map<int, int>.from(ChessClockDefaults.baseTimes);
    if (raw == null || raw.isEmpty) {
      return defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final key = int.tryParse(entry.key.toString());
          final value = entry.value is int
              ? entry.value as int
              : int.tryParse(entry.value.toString());
          if (key != null && value != null) {
            defaults[key] = value;
          }
        }
      }
    } catch (_) {
      return defaults;
    }
    return defaults;
  }

  String _encodeChessClockDefaults(Map<int, int> defaults) {
    final data = defaults.map((key, value) => MapEntry(key.toString(), value));
    return jsonEncode(data);
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

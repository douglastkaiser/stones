import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings keys for SharedPreferences
class SettingsKeys {
  static const String boardSize = 'board_size';
  static const String soundMuted = 'sound_muted';
  static const String themeMode = 'theme_mode';
}

/// App settings state
class AppSettings {
  final int boardSize;
  final bool isSoundMuted;
  final ThemeMode themeMode;

  const AppSettings({
    this.boardSize = 5,
    this.isSoundMuted = false,
    this.themeMode = ThemeMode.system,
  });

  AppSettings copyWith({
    int? boardSize,
    bool? isSoundMuted,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      boardSize: boardSize ?? this.boardSize,
      isSoundMuted: isSoundMuted ?? this.isSoundMuted,
      themeMode: themeMode ?? this.themeMode,
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

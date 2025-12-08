import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings keys for SharedPreferences
class SettingsKeys {
  static const String boardSize = 'board_size';
  static const String soundMuted = 'sound_muted';
  static const String darkTheme = 'dark_theme';
}

/// App settings state
class AppSettings {
  final int boardSize;
  final bool isSoundMuted;
  final bool isDarkTheme;

  const AppSettings({
    this.boardSize = 5,
    this.isSoundMuted = false,
    this.isDarkTheme = false,
  });

  AppSettings copyWith({
    int? boardSize,
    bool? isSoundMuted,
    bool? isDarkTheme,
  }) {
    return AppSettings(
      boardSize: boardSize ?? this.boardSize,
      isSoundMuted: isSoundMuted ?? this.isSoundMuted,
      isDarkTheme: isDarkTheme ?? this.isDarkTheme,
    );
  }
}

/// Notifier for app settings with persistence
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings());

  /// Load settings from SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      boardSize: prefs.getInt(SettingsKeys.boardSize) ?? 5,
      isSoundMuted: prefs.getBool(SettingsKeys.soundMuted) ?? false,
      isDarkTheme: prefs.getBool(SettingsKeys.darkTheme) ?? false,
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

  /// Set dark theme and persist
  Future<void> setDarkTheme(bool dark) async {
    state = state.copyWith(isDarkTheme: dark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.darkTheme, dark);
  }

  /// Toggle dark theme
  Future<void> toggleDarkTheme() async {
    await setDarkTheme(!state.isDarkTheme);
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

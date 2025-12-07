import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Color theme options
enum ColorTheme {
  classic, // Cream vs Charcoal
  nature,  // Sage vs Rust
}

/// App settings
class AppSettings {
  final bool soundEnabled;
  final ColorTheme colorTheme;
  final int defaultBoardSize;

  const AppSettings({
    this.soundEnabled = true,
    this.colorTheme = ColorTheme.classic,
    this.defaultBoardSize = 5,
  });

  AppSettings copyWith({
    bool? soundEnabled,
    ColorTheme? colorTheme,
    int? defaultBoardSize,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      colorTheme: colorTheme ?? this.colorTheme,
      defaultBoardSize: defaultBoardSize ?? this.defaultBoardSize,
    );
  }
}

/// Settings notifier for managing app settings
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void setSoundEnabled(bool enabled) {
    state = state.copyWith(soundEnabled: enabled);
  }

  void setColorTheme(ColorTheme theme) {
    state = state.copyWith(colorTheme: theme);
  }

  void setDefaultBoardSize(int size) {
    state = state.copyWith(defaultBoardSize: size);
  }
}

/// Provider for app settings
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

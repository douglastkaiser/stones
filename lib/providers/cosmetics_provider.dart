import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/cosmetics.dart';
import 'achievements_provider.dart';

/// Keys for SharedPreferences
class CosmeticsKeys {
  static const String boardTheme = 'cosmetics_board_theme';
  static const String pieceStyle = 'cosmetics_piece_style';
}

/// Cosmetics state containing selected themes and styles
class CosmeticsState {
  final BoardTheme selectedBoardTheme;
  final PieceStyle selectedPieceStyle;

  const CosmeticsState({
    this.selectedBoardTheme = BoardTheme.classicWood,
    this.selectedPieceStyle = PieceStyle.standard,
  });

  CosmeticsState copyWith({
    BoardTheme? selectedBoardTheme,
    PieceStyle? selectedPieceStyle,
  }) {
    return CosmeticsState(
      selectedBoardTheme: selectedBoardTheme ?? this.selectedBoardTheme,
      selectedPieceStyle: selectedPieceStyle ?? this.selectedPieceStyle,
    );
  }

  /// Get the current board theme data
  BoardThemeData get boardThemeData =>
      BoardThemeData.forTheme(selectedBoardTheme);

  /// Get the current piece style data
  PieceStyleData get pieceStyleData =>
      PieceStyleData.forStyle(selectedPieceStyle);
}

/// Notifier for cosmetics state with persistence
class CosmeticsNotifier extends StateNotifier<CosmeticsState> {
  CosmeticsNotifier() : super(const CosmeticsState());

  /// Load cosmetics from SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Load board theme
    final boardThemeIndex = prefs.getInt(CosmeticsKeys.boardTheme);
    final boardTheme = boardThemeIndex != null &&
            boardThemeIndex >= 0 &&
            boardThemeIndex < BoardTheme.values.length
        ? BoardTheme.values[boardThemeIndex]
        : BoardTheme.classicWood;

    // Load piece style
    final pieceStyleIndex = prefs.getInt(CosmeticsKeys.pieceStyle);
    final pieceStyle = pieceStyleIndex != null &&
            pieceStyleIndex >= 0 &&
            pieceStyleIndex < PieceStyle.values.length
        ? PieceStyle.values[pieceStyleIndex]
        : PieceStyle.standard;

    state = CosmeticsState(
      selectedBoardTheme: boardTheme,
      selectedPieceStyle: pieceStyle,
    );
  }

  /// Set the board theme and persist
  Future<void> setBoardTheme(BoardTheme theme) async {
    state = state.copyWith(selectedBoardTheme: theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(CosmeticsKeys.boardTheme, theme.index);
  }

  /// Set the piece style and persist
  Future<void> setPieceStyle(PieceStyle style) async {
    state = state.copyWith(selectedPieceStyle: style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(CosmeticsKeys.pieceStyle, style.index);
  }
}

/// Provider for cosmetics state
final cosmeticsProvider =
    StateNotifierProvider<CosmeticsNotifier, CosmeticsState>((ref) {
  return CosmeticsNotifier();
});

/// Provider for current board theme data
final currentBoardThemeProvider = Provider<BoardThemeData>((ref) {
  return ref.watch(cosmeticsProvider).boardThemeData;
});

/// Provider for current piece style data
final currentPieceStyleProvider = Provider<PieceStyleData>((ref) {
  return ref.watch(cosmeticsProvider).pieceStyleData;
});

/// Provider for checking if a board theme is unlocked
final isBoardThemeUnlockedProvider =
    Provider.family<bool, BoardTheme>((ref, theme) {
  final themeData = BoardThemeData.forTheme(theme);
  if (themeData.requiredAchievement == null) return true;

  final achievements = ref.watch(achievementProvider);
  return achievements.isUnlocked(themeData.requiredAchievement!);
});

/// Provider for checking if a piece style is unlocked
final isPieceStyleUnlockedProvider =
    Provider.family<bool, PieceStyle>((ref, style) {
  final styleData = PieceStyleData.forStyle(style);
  if (styleData.requiredAchievement == null) return true;

  final achievements = ref.watch(achievementProvider);
  return achievements.isUnlocked(styleData.requiredAchievement!);
});

/// Provider for unlock requirement text for a board theme
final boardThemeUnlockRequirementProvider =
    Provider.family<String?, BoardTheme>((ref, theme) {
  final themeData = BoardThemeData.forTheme(theme);
  if (themeData.requiredAchievement == null) return null;

  final isUnlocked = ref.watch(isBoardThemeUnlockedProvider(theme));
  if (isUnlocked) return null;

  final achievement = Achievement.forType(themeData.requiredAchievement!);
  return 'Unlock: ${achievement.description}';
});

/// Provider for unlock requirement text for a piece style
final pieceStyleUnlockRequirementProvider =
    Provider.family<String?, PieceStyle>((ref, style) {
  final styleData = PieceStyleData.forStyle(style);
  if (styleData.requiredAchievement == null) return null;

  final isUnlocked = ref.watch(isPieceStyleUnlockedProvider(style));
  if (isUnlocked) return null;

  final achievement = Achievement.forType(styleData.requiredAchievement!);
  return 'Unlock: ${achievement.description}';
});

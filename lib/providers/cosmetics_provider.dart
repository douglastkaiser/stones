import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/cosmetics.dart';
import 'achievements_provider.dart';
import 'account_provider.dart';
import 'elite_theme_provider.dart';

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
  Future<void> setTheme(BoardTheme theme) async {
    final style = piecesForBoard(theme);
    state =
        CosmeticsState(selectedBoardTheme: theme, selectedPieceStyle: style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(CosmeticsKeys.boardTheme, theme.index);
    await prefs.setInt(CosmeticsKeys.pieceStyle, style.index);
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

  /// Reset cosmetics to defaults
  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CosmeticsKeys.boardTheme);
    await prefs.remove(CosmeticsKeys.pieceStyle);
    state = const CosmeticsState();
  }
}

/// Provider for cosmetics state
final cosmeticsProvider =
    StateNotifierProvider<CosmeticsNotifier, CosmeticsState>((ref) {
  return CosmeticsNotifier();
});

/// Both historical achievement routes continue to grant the whole city.
final isBoardThemeUnlockedProvider =
    Provider.family<bool, BoardTheme>((ref, theme) {
  if (theme == BoardTheme.celestial) {
    final identity = ref.watch(accountProvider).identity;
    return identity != null &&
        !identity.guest &&
        ref.watch(eliteThemeEligibilityProvider(identity.uid)).asData?.value ==
            true;
  }
  final boardAward = BoardThemeData.forTheme(theme).requiredAchievement;
  final pieceAward =
      PieceStyleData.forStyle(piecesForBoard(theme)).requiredAchievement;
  if (boardAward == null && pieceAward == null) return true;
  final achievements = ref.watch(achievementProvider);
  return (boardAward != null && achievements.isUnlocked(boardAward)) ||
      (pieceAward != null && achievements.isUnlocked(pieceAward));
});

final isPieceStyleUnlockedProvider = Provider.family<bool, PieceStyle>(
    (ref, style) =>
        ref.watch(isBoardThemeUnlockedProvider(boardForPieces(style))));

/// Requirements are visible even after earning a city; previewing grants nothing.
String cityUnlockRequirement(BoardTheme theme) {
  if (theme == BoardTheme.celestial) {
    return 'Be the current #1 established human player in Overall ratings. Access ends when you lose the top spot. Sign in to verify eligibility.';
  }
  final requirements = {
    BoardThemeData.forTheme(theme).requiredAchievement,
    PieceStyleData.forStyle(piecesForBoard(theme)).requiredAchievement,
  }
      .whereType<AchievementType>()
      .map((type) => GameAchievement.forType(type)
          .description
          .replaceFirst(RegExp(r'\.+$'), ''))
      .toList();
  if (requirements.isEmpty) return 'Available to everyone.';
  return 'Unlock by completing either: ${requirements.join(' OR ')}.';
}

final boardThemeUnlockRequirementProvider =
    Provider.family<String?, BoardTheme>(
        (ref, theme) => cityUnlockRequirement(theme));
final pieceStyleUnlockRequirementProvider =
    Provider.family<String?, PieceStyle>(
        (ref, style) => cityUnlockRequirement(boardForPieces(style)));

final shareablePieceStyleProvider = Provider<PieceStyle>((ref) {
  final style = ref.watch(cosmeticsProvider).selectedPieceStyle;
  return ref.watch(isPieceStyleUnlockedProvider(style))
      ? style
      : PieceStyle.standard;
});
final shareableBoardThemeProvider = Provider<BoardTheme>((ref) {
  final theme = ref.watch(cosmeticsProvider).selectedBoardTheme;
  return ref.watch(isBoardThemeUnlockedProvider(theme))
      ? theme
      : BoardTheme.classicWood;
});
final currentBoardThemeProvider = Provider<BoardThemeData>(
    (ref) => BoardThemeData.forTheme(ref.watch(shareableBoardThemeProvider)));
final currentPieceStyleProvider = Provider<PieceStyleData>(
    (ref) => PieceStyleData.forStyle(ref.watch(shareablePieceStyleProvider)));

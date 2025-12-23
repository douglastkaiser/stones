import 'package:flutter/material.dart';

import 'achievement.dart';
import '../theme/game_colors.dart';

/// Board theme types
enum BoardTheme {
  classicWood,
  darkStone,
  marble,
  minimalist,
  pixelArt,
}

/// Piece style types
enum PieceStyle {
  standard,
  polishedMarble,
  handCarved,
}

/// Board theme definition with colors and metadata
class BoardThemeData {
  final BoardTheme theme;
  final String name;
  final String description;
  final AchievementType? requiredAchievement;

  // Board colors
  final Color frameOuter;
  final Color frameInner;
  final Color background;
  final Color gridLine;
  final Color gridLineShadow;
  final Color gridLineHighlight;
  final Color cellBackground;
  final Color cellBackgroundLight;
  final Color cellBackgroundDark;
  final Color woodGrainAccent;

  // Placement sound identifier
  final String placementSound;

  const BoardThemeData({
    required this.theme,
    required this.name,
    required this.description,
    this.requiredAchievement,
    required this.frameOuter,
    required this.frameInner,
    required this.background,
    required this.gridLine,
    required this.gridLineShadow,
    required this.gridLineHighlight,
    required this.cellBackground,
    required this.cellBackgroundLight,
    required this.cellBackgroundDark,
    required this.woodGrainAccent,
    required this.placementSound,
  });

  /// Get theme data by type
  static BoardThemeData forTheme(BoardTheme theme) {
    return boardThemes.firstWhere((t) => t.theme == theme);
  }
}

/// All board themes
const List<BoardThemeData> boardThemes = [
  // Classic Wood - default, available to all
  BoardThemeData(
    theme: BoardTheme.classicWood,
    name: 'Classic Wood',
    description: 'Traditional wooden board',
    frameOuter: Color(0xFF5D4037),
    frameInner: Color(0xFF795548),
    background: Color(0xFF6D4C41),
    gridLine: Color(0xFF4E342E),
    gridLineShadow: Color(0xFF3E2723),
    gridLineHighlight: Color(0xFF8D6E63),
    cellBackground: Color(0xFFD7CCC8),
    cellBackgroundLight: Color(0xFFEFEBE9),
    cellBackgroundDark: Color(0xFFBCAAA4),
    woodGrainAccent: Color(0xFFC9B8A8),
    placementSound: 'piece_place_wood',
  ),
  // Dark Stone - unlocks with "Strategist" (Beat Hard AI)
  BoardThemeData(
    theme: BoardTheme.darkStone,
    name: 'Dark Stone',
    description: 'Slate and granite board',
    requiredAchievement: AchievementType.strategist,
    frameOuter: Color(0xFF263238),
    frameInner: Color(0xFF37474F),
    background: Color(0xFF455A64),
    gridLine: Color(0xFF1C313A),
    gridLineShadow: Color(0xFF102027),
    gridLineHighlight: Color(0xFF546E7A),
    cellBackground: Color(0xFF78909C),
    cellBackgroundLight: Color(0xFF90A4AE),
    cellBackgroundDark: Color(0xFF607D8B),
    woodGrainAccent: Color(0xFF62727B),
    placementSound: 'piece_place_stone',
  ),
  // Marble - unlocks with "Grandmaster" (Beat Expert AI)
  BoardThemeData(
    theme: BoardTheme.marble,
    name: 'Marble',
    description: 'Elegant marble surface',
    requiredAchievement: AchievementType.grandmaster,
    frameOuter: Color(0xFF757575),
    frameInner: Color(0xFF9E9E9E),
    background: Color(0xFFBDBDBD),
    gridLine: Color(0xFF616161),
    gridLineShadow: Color(0xFF424242),
    gridLineHighlight: Color(0xFFE0E0E0),
    cellBackground: Color(0xFFF5F5F5),
    cellBackgroundLight: Color(0xFFFFFFFF),
    cellBackgroundDark: Color(0xFFEEEEEE),
    woodGrainAccent: Color(0xFFE8E8E8),
    placementSound: 'piece_place_marble',
  ),
  // Minimalist - unlocks with "Student" (Complete all tutorials)
  BoardThemeData(
    theme: BoardTheme.minimalist,
    name: 'Minimalist',
    description: 'Clean, modern design',
    requiredAchievement: AchievementType.student,
    frameOuter: Color(0xFF212121),
    frameInner: Color(0xFF424242),
    background: Color(0xFF303030),
    gridLine: Color(0xFF1A1A1A),
    gridLineShadow: Color(0xFF0D0D0D),
    gridLineHighlight: Color(0xFF505050),
    cellBackground: Color(0xFFFAFAFA),
    cellBackgroundLight: Color(0xFFFFFFFF),
    cellBackgroundDark: Color(0xFFF0F0F0),
    woodGrainAccent: Color(0xFFF5F5F5),
    placementSound: 'piece_place_minimal',
  ),
  // Pixel Art - unlocks with "Veteran" (Win 50 games)
  BoardThemeData(
    theme: BoardTheme.pixelArt,
    name: 'Pixel Art',
    description: 'Retro pixel aesthetic',
    requiredAchievement: AchievementType.veteran,
    frameOuter: Color(0xFF1A1C2C),
    frameInner: Color(0xFF5D275D),
    background: Color(0xFFB13E53),
    gridLine: Color(0xFF0D0D0D),
    gridLineShadow: Color(0xFF000000),
    gridLineHighlight: Color(0xFFEF7D57),
    cellBackground: Color(0xFFFFCD75),
    cellBackgroundLight: Color(0xFFF4F4F4),
    cellBackgroundDark: Color(0xFFA7F070),
    woodGrainAccent: Color(0xFF38B764),
    placementSound: 'piece_place_pixel',
  ),
];

/// Piece style definition with colors and metadata
class PieceStyleData {
  final PieceStyle style;
  final String name;
  final String description;
  final AchievementType? requiredAchievement;

  // Light piece colors
  final Color lightPrimary;
  final Color lightSecondary;
  final Color lightBorder;

  // Dark piece colors
  final Color darkPrimary;
  final Color darkSecondary;
  final Color darkBorder;

  // Stack move sound identifier
  final String stackMoveSound;

  const PieceStyleData({
    required this.style,
    required this.name,
    required this.description,
    this.requiredAchievement,
    required this.lightPrimary,
    required this.lightSecondary,
    required this.lightBorder,
    required this.darkPrimary,
    required this.darkSecondary,
    required this.darkBorder,
    required this.stackMoveSound,
  });

  /// Get style data by type
  static PieceStyleData forStyle(PieceStyle style) {
    return pieceStyles.firstWhere((s) => s.style == style);
  }

  /// Get PieceColors for a player
  PieceColors colorsForPlayer(bool isLightPlayer) {
    if (isLightPlayer) {
      return PieceColors(
        primary: lightPrimary,
        secondary: lightSecondary,
        border: lightBorder,
      );
    } else {
      return PieceColors(
        primary: darkPrimary,
        secondary: darkSecondary,
        border: darkBorder,
      );
    }
  }

  /// Light player piece colors
  PieceColors get lightPlayerColors => PieceColors(
    primary: lightPrimary,
    secondary: lightSecondary,
    border: lightBorder,
  );

  /// Dark player piece colors
  PieceColors get darkPlayerColors => PieceColors(
    primary: darkPrimary,
    secondary: darkSecondary,
    border: darkBorder,
  );
}

/// All piece styles
const List<PieceStyleData> pieceStyles = [
  // Standard - default, available to all
  PieceStyleData(
    style: PieceStyle.standard,
    name: 'Standard',
    description: 'Classic wooden pieces',
    lightPrimary: Color(0xFFF5F0E6),
    lightSecondary: Color(0xFFE8E0D0),
    lightBorder: Color(0xFF8B7355),
    darkPrimary: Color(0xFF3D3D3D),
    darkSecondary: Color(0xFF4A4A4A),
    darkBorder: Color(0xFF6B6B6B),
    stackMoveSound: 'stack_move_wood',
  ),
  // Polished Marble - unlocks with "Puzzle Solver" (Complete all puzzles)
  PieceStyleData(
    style: PieceStyle.polishedMarble,
    name: 'Polished Marble',
    description: 'Smooth marble pieces',
    requiredAchievement: AchievementType.puzzleSolver,
    lightPrimary: Color(0xFFFFFBF0),
    lightSecondary: Color(0xFFEEE8DD),
    lightBorder: Color(0xFFB8A898),
    darkPrimary: Color(0xFF2A3540),
    darkSecondary: Color(0xFF3A4550),
    darkBorder: Color(0xFF5A6570),
    stackMoveSound: 'stack_move_marble',
  ),
  // Hand Carved - unlocks with "Connected" (Win first online game)
  PieceStyleData(
    style: PieceStyle.handCarved,
    name: 'Hand Carved',
    description: 'Rustic carved pieces',
    requiredAchievement: AchievementType.connected,
    lightPrimary: Color(0xFFDEB887),
    lightSecondary: Color(0xFFD2A86E),
    lightBorder: Color(0xFF8B4513),
    darkPrimary: Color(0xFF4A3728),
    darkSecondary: Color(0xFF5C4533),
    darkBorder: Color(0xFF8B7355),
    stackMoveSound: 'stack_move_carved',
  ),
];

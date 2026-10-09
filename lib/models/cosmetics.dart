import 'package:flutter/material.dart';

import 'achievement.dart';
import '../theme/game_colors.dart';

/// Board theme types
enum BoardTheme {
  classicWood,
  darkStone,
  marble,
  morocco,
  kyoto,
}

/// Piece style types - each matches a board theme
enum PieceStyle {
  standard, // Matches Classic Wood
  stone, // Matches Dark Stone
  polishedMarble, // Matches Marble
  morocco, // Glazed ceramic
  kyoto, // Lacquer and bamboo
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
    cellBackground: Color(0xFFDAC8A5),
    cellBackgroundLight: Color(0xFFEADCC0),
    cellBackgroundDark: Color(0xFFBBA27A),
    woodGrainAccent: Color(0xFF9A7750),
    placementSound: 'piece_place_wood',
  ),
  // Dark Stone - unlocks with "Strategist" (Beat Hard AI)
  BoardThemeData(
    theme: BoardTheme.darkStone,
    name: 'Slate',
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
  // Morocco - unlocks with "Student" (Complete all tutorials)
  BoardThemeData(
    theme: BoardTheme.morocco,
    name: 'Morocco',
    description: 'Zellige tiles, cedar and brass',
    requiredAchievement: AchievementType.student,
    frameOuter: Color(0xFF164E50),
    frameInner: Color(0xFFB98946),
    background: Color(0xFF246568),
    gridLine: Color(0xFF164E50),
    gridLineShadow: Color(0xFF12393C),
    gridLineHighlight: Color(0xFFDEC498),
    cellBackground: Color(0xFFE7D9BA),
    cellBackgroundLight: Color(0xFFF4EBD7),
    cellBackgroundDark: Color(0xFFCDBE9C),
    woodGrainAccent: Color(0xFF2B7778),
    placementSound: 'piece_place_minimal',
  ),
  // Kyoto - unlocks with "Veteran" (Win 50 games)
  BoardThemeData(
    theme: BoardTheme.kyoto,
    name: 'Kyoto',
    description: 'Bamboo, indigo and lacquer',
    requiredAchievement: AchievementType.veteran,
    frameOuter: Color(0xFF202E49),
    frameInner: Color(0xFF8D6947),
    background: Color(0xFF364764),
    gridLine: Color(0xFF162238),
    gridLineShadow: Color(0xFF10192B),
    gridLineHighlight: Color(0xFFCFB485),
    cellBackground: Color(0xFFD5C6A0),
    cellBackgroundLight: Color(0xFFE5D8BA),
    cellBackgroundDark: Color(0xFFBCAD89),
    woodGrainAccent: Color(0xFF957A50),
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

/// All piece styles - each matches a board theme
const List<PieceStyleData> pieceStyles = [
  // Standard - default, matches Classic Wood
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
  // Stone - matches Dark Stone board, unlocks with "Connected"
  PieceStyleData(
    style: PieceStyle.stone,
    name: 'Chiseled Stone',
    description: 'Hewn stone pieces',
    requiredAchievement: AchievementType.connected,
    lightPrimary: Color(0xFFB0BEC5),
    lightSecondary: Color(0xFF90A4AE),
    lightBorder: Color(0xFF546E7A),
    darkPrimary: Color(0xFF37474F),
    darkSecondary: Color(0xFF455A64),
    darkBorder: Color(0xFF263238),
    stackMoveSound: 'stack_move_stone',
  ),
  // Polished Marble - matches Marble board, unlocks with "Puzzle Solver"
  PieceStyleData(
    style: PieceStyle.polishedMarble,
    name: 'Polished Marble',
    description: 'Smooth marble pieces',
    requiredAchievement: AchievementType.puzzleSolver,
    lightPrimary: Color(0xFFFFFBF0),
    lightSecondary: Color(0xFFEEE8DD),
    lightBorder: Color(0xFF78654F),
    darkPrimary: Color(0xFF2A3540),
    darkSecondary: Color(0xFF3A4550),
    darkBorder: Color(0xFF5A6570),
    stackMoveSound: 'stack_move_marble',
  ),
  // Morocco - matches Morocco board, unlocks with "First Steps"
  PieceStyleData(
    style: PieceStyle.morocco,
    name: 'Morocco',
    description: 'Ivory and teal glazed ceramic',
    requiredAchievement: AchievementType.firstSteps,
    lightPrimary: Color(0xFFFFF1D7),
    lightSecondary: Color(0xFFE7CDA4),
    lightBorder: Color(0xFF886333),
    darkPrimary: Color(0xFF16777A),
    darkSecondary: Color(0xFF164A52),
    darkBorder: Color(0xFF092F36),
    stackMoveSound: 'stack_move_minimal',
  ),
  // Kyoto - matches Kyoto board, unlocks with "Competitor"
  PieceStyleData(
    style: PieceStyle.kyoto,
    name: 'Kyoto',
    description: 'Cream and indigo lacquer',
    requiredAchievement: AchievementType.competitor,
    lightPrimary: Color(0xFFFFF4DD),
    lightSecondary: Color(0xFFD9C9A4),
    lightBorder: Color(0xFF826F4D),
    darkPrimary: Color(0xFF293F67),
    darkSecondary: Color(0xFF162743),
    darkBorder: Color(0xFF9DABC5),
    stackMoveSound: 'stack_move_pixel',
  ),
];

/// Unknown or legacy wire names fall back to the base set.
PieceStyle pieceStyleFromWire(Object? value) =>
    PieceStyle.values.where((style) => style.name == value).firstOrNull ??
    PieceStyle.standard;

BoardTheme boardThemeFromWire(Object? value) =>
    BoardTheme.values.where((theme) => theme.name == value).firstOrNull ??
    BoardTheme.classicWood;

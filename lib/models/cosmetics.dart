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
  celestial,
}

/// Piece style types - each matches a board theme
enum PieceStyle {
  standard, // Matches Classic Wood
  stone, // Matches Dark Stone
  polishedMarble, // Matches Marble
  morocco, // Glazed ceramic
  kyoto, // Lacquer and bamboo
  celestial, // Jaipur; append to preserve saved indices.
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
  BoardThemeData(
    theme: BoardTheme.celestial,
    name: 'Jaipur',
    description: 'Observatory stone, brass instruments and midnight stars',
    frameOuter: Color(0xFF090C24),
    frameInner: Color(0xFF7371B9),
    background: Color(0xFF101632),
    gridLine: Color(0xFFB5995F),
    gridLineShadow: Color(0xFF080B20),
    gridLineHighlight: Color(0xFFF5DCA3),
    cellBackground: Color(0xFF202545),
    cellBackgroundLight: Color(0xFF34365E),
    cellBackgroundDark: Color(0xFF171C38),
    woodGrainAccent: Color(0xFFEEDAA5),
    placementSound: 'piece_place_marble',
  ),

  // Classic Wood - default, available to all
  BoardThemeData(
    theme: BoardTheme.classicWood,
    name: 'Porto',
    description: 'Carved oak, cooperage bands and Atlantic engraving',
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
    name: 'Edinburgh',
    description: 'Hand-cut stone panels and carved interlace borders',
    requiredAchievement: AchievementType.strategist,
    frameOuter: Color(0xFF263238),
    frameInner: Color(0xFF37474F),
    background: Color(0xFF455A64),
    gridLine: Color(0xFF1C313A),
    gridLineShadow: Color(0xFF102027),
    gridLineHighlight: Color(0xFFC4C8B5),
    cellBackground: Color(0xFF93A19E),
    cellBackgroundLight: Color(0xFFB4BEB4),
    cellBackgroundDark: Color(0xFF7A8C88),
    woodGrainAccent: Color(0xFF62727B),
    placementSound: 'piece_place_stone',
  ),
  // Marble - unlocks with "Grandmaster" (Beat Expert AI)
  BoardThemeData(
    theme: BoardTheme.marble,
    name: 'Florence',
    description: 'Duomo marble geometry, green inlays and rose accents',
    requiredAchievement: AchievementType.grandmaster,
    frameOuter: Color(0xFF294B40),
    frameInner: Color(0xFFB9A581),
    background: Color(0xFFDDD7C9),
    gridLine: Color(0xFF386657),
    gridLineShadow: Color(0xFF424242),
    gridLineHighlight: Color(0xFFE8D7AA),
    cellBackground: Color(0xFFF5EFE2),
    cellBackgroundLight: Color(0xFFFFFFFF),
    cellBackgroundDark: Color(0xFFE0D9C8),
    woodGrainAccent: Color(0xFF82958B),
    placementSound: 'piece_place_marble',
  ),
  // Morocco - unlocks with "Student" (Complete all tutorials)
  BoardThemeData(
    theme: BoardTheme.morocco,
    name: 'Marrakesh',
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
    placementSound: 'piece_place_stone',
  ),
  // Kyoto - unlocks with "Veteran" (Win 50 games)
  BoardThemeData(
    theme: BoardTheme.kyoto,
    name: 'Kyoto',
    description: 'Indigo wave fans, bamboo and wooden lattice borders',
    requiredAchievement: AchievementType.veteran,
    frameOuter: Color(0xFF202E49),
    frameInner: Color(0xFF8D6947),
    background: Color(0xFF364764),
    gridLine: Color(0xFF80603D),
    gridLineShadow: Color(0xFF10192B),
    gridLineHighlight: Color(0xFFCFB485),
    cellBackground: Color(0xFFE9DFC6),
    cellBackgroundLight: Color(0xFFF3EBD7),
    cellBackgroundDark: Color(0xFFC7B58D),
    woodGrainAccent: Color(0xFF957A50),
    placementSound: 'piece_place_wood',
  ),
];

/// Stable visual identities, independent of serialized seats and city material.
enum PieceIdentity {
  trapezoid('Trapezoid'),
  rounded('Rounded'),
  diamond('Diamond'),
  hexagonal('Hexagonal');

  const PieceIdentity(this.label);
  final String label;
}

class PiecePalette {
  const PiecePalette(this.name, this.primary, this.border);
  final String name;
  final Color primary, border;
  PieceColors get colors => PieceColors(
        primary: primary,
        secondary: Color.lerp(primary, border, .24)!,
        border: border,
      );
}

/// Every city supplies all four ownership palettes from one source of truth.
class PieceStyleData {
  const PieceStyleData(
      {required this.style,
      required this.name,
      required this.description,
      this.requiredAchievement,
      required this.palettes,
      required this.stackMoveSound});
  final PieceStyle style;
  final String name, description, stackMoveSound;
  final AchievementType? requiredAchievement;
  final List<PiecePalette> palettes;
  static PieceStyleData forStyle(PieceStyle style) =>
      pieceStyles.firstWhere((data) => data.style == style);
  PieceColors colorsForIdentity(PieceIdentity identity) =>
      palettes[identity.index].colors;
  // Legacy square adapters retain their two original ownership slots.
  PieceColors colorsForPlayer(bool light) => palettes[light ? 0 : 1].colors;
  PieceColors get lightPlayerColors => palettes[0].colors;
  PieceColors get darkPlayerColors => palettes[1].colors;
}

const pieceStyles = [
  PieceStyleData(
      style: PieceStyle.standard,
      name: 'Porto',
      description: 'Carved wood and maritime engraving',
      stackMoveSound: 'stack_move_wood',
      palettes: [
        PiecePalette('Oak', Color(0xFFE9CE93), Color(0xFF75502E)),
        PiecePalette('Charred Oak', Color(0xFF45382F), Color(0xFF211B18)),
        PiecePalette('Port Wine', Color(0xFFA74761), Color(0xFF522139)),
        PiecePalette('Atlantic Blue', Color(0xFF4E9DBB), Color(0xFF174762)),
      ]),
  PieceStyleData(
      style: PieceStyle.stone,
      name: 'Edinburgh',
      description: 'Hewn slate and interlaced carving',
      requiredAchievement: AchievementType.connected,
      stackMoveSound: 'stack_move_stone',
      palettes: [
        PiecePalette('Limestone', Color(0xFFE1DED1), Color(0xFF76756C)),
        PiecePalette('Basalt', Color(0xFF36414A), Color(0xFF151F29)),
        PiecePalette('Heather', Color(0xFFAB77AE), Color(0xFF563958)),
        PiecePalette('Moss', Color(0xFF8CA46A), Color(0xFF40552F)),
      ]),
  PieceStyleData(
      style: PieceStyle.polishedMarble,
      name: 'Florence',
      description: 'Polished marble and Florentine lilies',
      requiredAchievement: AchievementType.puzzleSolver,
      stackMoveSound: 'stack_move_marble',
      palettes: [
        PiecePalette('Carrara', Color(0xFFFFF9EB), Color(0xFF9F8E72)),
        PiecePalette('Serpentine', Color(0xFF254F46), Color(0xFF102C29)),
        PiecePalette('Terracotta', Color(0xFFCA7353), Color(0xFF773D29)),
        PiecePalette('Lapis', Color(0xFF5276BC), Color(0xFF24365F)),
      ]),
  PieceStyleData(
      style: PieceStyle.morocco,
      name: 'Marrakesh',
      description: 'Glazed ceramic and brass zellige rosettes',
      requiredAchievement: AchievementType.firstSteps,
      stackMoveSound: 'stack_move_stone',
      palettes: [
        PiecePalette('Sand', Color(0xFFF4DEAD), Color(0xFF8A6636)),
        PiecePalette('Majorelle', Color(0xFF3345A5), Color(0xFF171F5C)),
        PiecePalette('Ochre', Color(0xFFD4952C), Color(0xFF7B4B16)),
        PiecePalette('Palm', Color(0xFF389276), Color(0xFF164839)),
      ]),
  PieceStyleData(
      style: PieceStyle.kyoto,
      name: 'Kyoto',
      description: 'Lacquer, bamboo, waves and plum blossom',
      requiredAchievement: AchievementType.competitor,
      stackMoveSound: 'stack_move_wood',
      palettes: [
        PiecePalette('Rice Paper', Color(0xFFFFF4DD), Color(0xFF95815F)),
        PiecePalette('Indigo', Color(0xFF293F67), Color(0xFF111F3B)),
        PiecePalette('Vermilion', Color(0xFFD95D43), Color(0xFF762D23)),
        PiecePalette('Matcha', Color(0xFF8EAA62), Color(0xFF435B2F)),
      ]),
  PieceStyleData(
      style: PieceStyle.celestial,
      name: 'Jaipur',
      description: 'Observatory stone and brass star charts',
      stackMoveSound: 'stack_move_marble',
      palettes: [
        PiecePalette('Moonstone', Color(0xFFF2EADB), Color(0xFFB49A64)),
        PiecePalette('Midnight', Color(0xFF34305D), Color(0xFF15132D)),
        PiecePalette('Pink Sandstone', Color(0xFFE49691), Color(0xFF97524F)),
        PiecePalette('Turquoise', Color(0xFF48B9BB), Color(0xFF1D626E)),
      ]),
];

/// Explicit pairing avoids relying on enum order or metadata list order.
PieceStyle piecesForBoard(BoardTheme theme) => switch (theme) {
      BoardTheme.classicWood => PieceStyle.standard,
      BoardTheme.darkStone => PieceStyle.stone,
      BoardTheme.marble => PieceStyle.polishedMarble,
      BoardTheme.morocco => PieceStyle.morocco,
      BoardTheme.kyoto => PieceStyle.kyoto,
      BoardTheme.celestial => PieceStyle.celestial,
    };
BoardTheme boardForPieces(PieceStyle style) => switch (style) {
      PieceStyle.standard => BoardTheme.classicWood,
      PieceStyle.stone => BoardTheme.darkStone,
      PieceStyle.polishedMarble => BoardTheme.marble,
      PieceStyle.morocco => BoardTheme.morocco,
      PieceStyle.kyoto => BoardTheme.kyoto,
      PieceStyle.celestial => BoardTheme.celestial,
    };

PieceStyle pieceStyleFromWire(Object? value) =>
    PieceStyle.values.where((style) => style.name == value).firstOrNull ??
    PieceStyle.standard;
BoardTheme boardThemeFromWire(Object? value) =>
    BoardTheme.values.where((theme) => theme.name == value).firstOrNull ??
    BoardTheme.classicWood;

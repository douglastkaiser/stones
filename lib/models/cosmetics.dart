import 'package:flutter/material.dart';

import 'achievements.dart';

/// Palette information for rendering the board.
class BoardPalette {
  final Color boardFrameOuter;
  final Color boardFrameInner;
  final Color boardBackground;
  final Color gridLine;
  final Color gridLineShadow;
  final Color gridLineHighlight;
  final Color cellBackground;
  final Color cellBackgroundLight;
  final Color cellBackgroundDark;
  final Color cellSelected;
  final Color cellSelectedGlow;
  final Color cellSelectedBorder;
  final Color cellDropPath;
  final Color cellDropPathGlow;
  final Color cellDropPathBorder;
  final Color cellNextDrop;
  final Color cellNextDropGlow;
  final Color cellNextDropBorder;
  final Color lastMoveBorder;
  final Color lastMoveGlow;
  final Color cellLegalMove;
  final Color cellLegalMoveGlow;
  final Color cellLegalMoveBorder;

  const BoardPalette({
    required this.boardFrameOuter,
    required this.boardFrameInner,
    required this.boardBackground,
    required this.gridLine,
    required this.gridLineShadow,
    required this.gridLineHighlight,
    required this.cellBackground,
    required this.cellBackgroundLight,
    required this.cellBackgroundDark,
    required this.cellSelected,
    required this.cellSelectedGlow,
    required this.cellSelectedBorder,
    required this.cellDropPath,
    required this.cellDropPathGlow,
    required this.cellDropPathBorder,
    required this.cellNextDrop,
    required this.cellNextDropGlow,
    required this.cellNextDropBorder,
    required this.lastMoveBorder,
    required this.lastMoveGlow,
    required this.cellLegalMove,
    required this.cellLegalMoveGlow,
    required this.cellLegalMoveBorder,
  });
}

/// Piece material values including optional hatch/texture tone.
class PieceMaterial {
  final Color primary;
  final Color secondary;
  final Color border;
  final Color? accent;
  final bool hatch;

  const PieceMaterial({
    required this.primary,
    required this.secondary,
    required this.border,
    this.accent,
    this.hatch = false,
  });

  List<Color> get gradientColors => [primary, secondary];
}

/// Definition of a board theme including palette and sound variant.
class BoardThemeDefinition {
  final String id;
  final String name;
  final String description;
  final BoardPalette palette;
  final String placementSound;
  final AchievementType? unlockRequirement;

  const BoardThemeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.palette,
    required this.placementSound,
    this.unlockRequirement,
  });
}

/// Definition of a piece style and its audio flavor.
class PieceStyleDefinition {
  final String id;
  final String name;
  final String description;
  final PieceMaterial lightMaterial;
  final PieceMaterial darkMaterial;
  final String stackSound;
  final AchievementType? unlockRequirement;

  const PieceStyleDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.lightMaterial,
    required this.darkMaterial,
    required this.stackSound,
    this.unlockRequirement,
  });
}

/// Stable identifiers for board themes.
class BoardThemeIds {
  static const classicWood = 'classic_wood';
  static const darkStone = 'dark_stone';
  static const marble = 'marble';
  static const minimalist = 'minimalist';
  static const pixelArt = 'pixel_art';
}

/// Stable identifiers for piece styles.
class PieceStyleIds {
  static const standard = 'standard';
  static const polishedMarble = 'polished_marble';
  static const handCarved = 'hand_carved';
}

/// Available board themes.
final List<BoardThemeDefinition> boardThemes = [
  BoardThemeDefinition(
    id: BoardThemeIds.classicWood,
    name: 'Classic Wood',
    description: 'Warm wood with soft grain.',
    palette: BoardPalette(
      boardFrameOuter: const Color(0xFF5D4037),
      boardFrameInner: const Color(0xFF795548),
      boardBackground: const Color(0xFF6D4C41),
      gridLine: const Color(0xFF4E342E),
      gridLineShadow: const Color(0xFF3E2723),
      gridLineHighlight: const Color(0xFF8D6E63),
      cellBackground: const Color(0xFFD7CCC8),
      cellBackgroundLight: const Color(0xFFEFEBE9),
      cellBackgroundDark: const Color(0xFFBCAAA4),
      cellSelected: const Color(0xFFFFE082),
      cellSelectedGlow: const Color(0xFFFFD54F),
      cellSelectedBorder: const Color(0xFFFFA000),
      cellDropPath: const Color(0xFFBBDEFB),
      cellDropPathGlow: const Color(0xFF90CAF9),
      cellDropPathBorder: const Color(0xFF42A5F5),
      cellNextDrop: const Color(0xFFC8E6C9),
      cellNextDropGlow: const Color(0xFFA5D6A7),
      cellNextDropBorder: const Color(0xFF66BB6A),
      lastMoveBorder: const Color(0xFF9575CD),
      lastMoveGlow: const Color(0xFFB39DDB),
      cellLegalMove: const Color(0xFFB2EBF2),
      cellLegalMoveGlow: const Color(0xFF80DEEA),
      cellLegalMoveBorder: const Color(0xFF26C6DA),
    ),
    placementSound: 'assets/sounds/piece_place.wav',
  ),
  BoardThemeDefinition(
    id: BoardThemeIds.darkStone,
    name: 'Dark Stone',
    description: 'Obsidian tiles with cool highlights.',
    palette: BoardPalette(
      boardFrameOuter: const Color(0xFF1F1F1F),
      boardFrameInner: const Color(0xFF2B2E32),
      boardBackground: const Color(0xFF292C30),
      gridLine: const Color(0xFF3A3E44),
      gridLineShadow: const Color(0xFF0E0F11),
      gridLineHighlight: const Color(0xFF4F5A64),
      cellBackground: const Color(0xFF4B4F57),
      cellBackgroundLight: const Color(0xFF5A5F69),
      cellBackgroundDark: const Color(0xFF3C3F45),
      cellSelected: const Color(0xFF89A7FF),
      cellSelectedGlow: const Color(0xFF6F8CFF),
      cellSelectedBorder: const Color(0xFF3F5ACB),
      cellDropPath: const Color(0xFF5168A1),
      cellDropPathGlow: const Color(0xFF5B74B5),
      cellDropPathBorder: const Color(0xFF3B4C7C),
      cellNextDrop: const Color(0xFF4E8B73),
      cellNextDropGlow: const Color(0xFF5FA58C),
      cellNextDropBorder: const Color(0xFF3A7A66),
      lastMoveBorder: const Color(0xFFB3A0FF),
      lastMoveGlow: const Color(0xFF7E6DF2),
      cellLegalMove: const Color(0xFF7AAFC4),
      cellLegalMoveGlow: const Color(0xFF5E98B0),
      cellLegalMoveBorder: const Color(0xFF40758C),
    ),
    placementSound: 'assets/sounds/piece_place.wav',
    unlockRequirement: AchievementType.strategist,
  ),
  BoardThemeDefinition(
    id: BoardThemeIds.marble,
    name: 'Marble',
    description: 'Cool marble inlay with subtle veins.',
    palette: BoardPalette(
      boardFrameOuter: const Color(0xFFADB3C0),
      boardFrameInner: const Color(0xFFC9CEDA),
      boardBackground: const Color(0xFFD5D9E3),
      gridLine: const Color(0xFFBCC3D1),
      gridLineShadow: const Color(0xFF8E94A3),
      gridLineHighlight: const Color(0xFFE0E4ED),
      cellBackground: const Color(0xFFF2F4F8),
      cellBackgroundLight: const Color(0xFFFFFFFF),
      cellBackgroundDark: const Color(0xFFE4E7EF),
      cellSelected: const Color(0xFFDFE7FF),
      cellSelectedGlow: const Color(0xFFC3D3FF),
      cellSelectedBorder: const Color(0xFF8FA7FF),
      cellDropPath: const Color(0xFFCDE7FF),
      cellDropPathGlow: const Color(0xFFB2D8FF),
      cellDropPathBorder: const Color(0xFF7FB8F6),
      cellNextDrop: const Color(0xFFDCF1E4),
      cellNextDropGlow: const Color(0xFFC7E5D4),
      cellNextDropBorder: const Color(0xFF8BC7A7),
      lastMoveBorder: const Color(0xFFA4A4FF),
      lastMoveGlow: const Color(0xFFCCCBFF),
      cellLegalMove: const Color(0xFFBFE7F2),
      cellLegalMoveGlow: const Color(0xFFA9D6E6),
      cellLegalMoveBorder: const Color(0xFF7CB5CB),
    ),
    placementSound: 'assets/sounds/piece_place.wav',
    unlockRequirement: AchievementType.grandmaster,
  ),
  BoardThemeDefinition(
    id: BoardThemeIds.minimalist,
    name: 'Minimalist',
    description: 'Clean, high-contrast grid for focus.',
    palette: BoardPalette(
      boardFrameOuter: const Color(0xFF3A3F4B),
      boardFrameInner: const Color(0xFF4D5563),
      boardBackground: const Color(0xFF353944),
      gridLine: const Color(0xFF9BA4B5),
      gridLineShadow: const Color(0xFF2C3039),
      gridLineHighlight: const Color(0xFFD8DEE9),
      cellBackground: const Color(0xFFF6F7FB),
      cellBackgroundLight: const Color(0xFFFFFFFF),
      cellBackgroundDark: const Color(0xFFE6E9EE),
      cellSelected: const Color(0xFFBDE0FF),
      cellSelectedGlow: const Color(0xFF9CCAF5),
      cellSelectedBorder: const Color(0xFF5B9BE3),
      cellDropPath: const Color(0xFFE7DFFF),
      cellDropPathGlow: const Color(0xFFC8BBFF),
      cellDropPathBorder: const Color(0xFF8D7BFF),
      cellNextDrop: const Color(0xFFD4F1DC),
      cellNextDropGlow: const Color(0xFFAEDFB9),
      cellNextDropBorder: const Color(0xFF6DBF82),
      lastMoveBorder: const Color(0xFF5CC9D8),
      lastMoveGlow: const Color(0xFFB3EEF4),
      cellLegalMove: const Color(0xFFE3F4FF),
      cellLegalMoveGlow: const Color(0xFFC9E8FF),
      cellLegalMoveBorder: const Color(0xFF8FC4F4),
    ),
    placementSound: 'assets/sounds/piece_place.wav',
    unlockRequirement: AchievementType.student,
  ),
  BoardThemeDefinition(
    id: BoardThemeIds.pixelArt,
    name: 'Pixel Art',
    description: 'Chunky retro tiles with neon pops.',
    palette: BoardPalette(
      boardFrameOuter: const Color(0xFF4B3A7A),
      boardFrameInner: const Color(0xFF5D4A96),
      boardBackground: const Color(0xFF3A305C),
      gridLine: const Color(0xFF6D62A8),
      gridLineShadow: const Color(0xFF2C254A),
      gridLineHighlight: const Color(0xFF9D90E5),
      cellBackground: const Color(0xFF7167B9),
      cellBackgroundLight: const Color(0xFF8E86D6),
      cellBackgroundDark: const Color(0xFF5A4EA0),
      cellSelected: const Color(0xFF8BF0FF),
      cellSelectedGlow: const Color(0xFF69D6EB),
      cellSelectedBorder: const Color(0xFF3AA7C6),
      cellDropPath: const Color(0xFF8ED2FF),
      cellDropPathGlow: const Color(0xFF6ABCF1),
      cellDropPathBorder: const Color(0xFF3C8AC7),
      cellNextDrop: const Color(0xFFFFE8A3),
      cellNextDropGlow: const Color(0xFFFBD479),
      cellNextDropBorder: const Color(0xFFE0A832),
      lastMoveBorder: const Color(0xFFFF90E8),
      lastMoveGlow: const Color(0xFFDA7DD1),
      cellLegalMove: const Color(0xFFC3FFF6),
      cellLegalMoveGlow: const Color(0xFFA0EDE3),
      cellLegalMoveBorder: const Color(0xFF5BCDBF),
    ),
    placementSound: 'assets/sounds/piece_place.wav',
    unlockRequirement: AchievementType.veteran,
  ),
];

/// Available piece styles.
final List<PieceStyleDefinition> pieceStyles = [
  PieceStyleDefinition(
    id: PieceStyleIds.standard,
    name: 'Standard',
    description: 'Classic wood-and-slate pairing.',
    lightMaterial: const PieceMaterial(
      primary: Color(0xFFF5F0E6),
      secondary: Color(0xFFE8E0D0),
      border: Color(0xFF8B7355),
      accent: Color(0xFF8B7355),
    ),
    darkMaterial: const PieceMaterial(
      primary: Color(0xFF3D3D3D),
      secondary: Color(0xFF4A4A4A),
      border: Color(0xFF6B6B6B),
      accent: Color(0xFF2F2F2F),
    ),
    stackSound: 'assets/sounds/stack_move.wav',
  ),
  PieceStyleDefinition(
    id: PieceStyleIds.polishedMarble,
    name: 'Polished Marble',
    description: 'Glassy white and ink-dark stone.',
    lightMaterial: const PieceMaterial(
      primary: Color(0xFFEAEAEA),
      secondary: Color(0xFFD8D8E0),
      border: Color(0xFFADB3C0),
      accent: Color(0xFF8FA0C2),
      hatch: true,
    ),
    darkMaterial: const PieceMaterial(
      primary: Color(0xFF1F2330),
      secondary: Color(0xFF2D3242),
      border: Color(0xFF7A869A),
      accent: Color(0xFF9FB3D8),
      hatch: true,
    ),
    stackSound: 'assets/sounds/stack_move.wav',
    unlockRequirement: AchievementType.puzzleSolver,
  ),
  PieceStyleDefinition(
    id: PieceStyleIds.handCarved,
    name: 'Hand Carved',
    description: 'Rugged cedar and charcoal etching.',
    lightMaterial: const PieceMaterial(
      primary: Color(0xFFF3E3D6),
      secondary: Color(0xFFE1C7B3),
      border: Color(0xFF9C6B43),
      accent: Color(0xFFB88357),
      hatch: true,
    ),
    darkMaterial: const PieceMaterial(
      primary: Color(0xFF3A2C26),
      secondary: Color(0xFF4A3730),
      border: Color(0xFF6B4A3A),
      accent: Color(0xFFB47B56),
      hatch: true,
    ),
    stackSound: 'assets/sounds/stack_move.wav',
    unlockRequirement: AchievementType.connected,
  ),
];

BoardThemeDefinition boardThemeById(String id) {
  return boardThemes.firstWhere(
    (t) => t.id == id,
    orElse: () => boardThemes.first,
  );
}

PieceStyleDefinition pieceStyleById(String id) {
  return pieceStyles.firstWhere(
    (s) => s.id == id,
    orElse: () => pieceStyles.first,
  );
}

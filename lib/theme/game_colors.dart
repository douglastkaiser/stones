import 'package:flutter/material.dart';

/// Game color theme - all colors are centralized here for easy customization.
class GameColors {
  GameColors._();

  // ==========================================================================
  // Player Piece Colors
  // ==========================================================================

  /// Light player primary color (cream/ivory)
  static const Color lightPiece = Color(0xFFF5F0E6);

  /// Light player secondary color (slightly darker for gradients)
  static const Color lightPieceSecondary = Color(0xFFE8E0D0);

  /// Light player border/accent color
  static const Color lightPieceBorder = Color(0xFF8B7355);

  /// Dark player primary color (charcoal/slate)
  static const Color darkPiece = Color(0xFF3D3D3D);

  /// Dark player secondary color (slightly lighter for gradients)
  static const Color darkPieceSecondary = Color(0xFF4A4A4A);

  /// Dark player border/accent color
  static const Color darkPieceBorder = Color(0xFF6B6B6B);

  // ==========================================================================
  // Board Colors - Wooden Theme
  // ==========================================================================

  /// Board frame outer color (dark wood)
  static const Color boardFrameOuter = Color(0xFF5D4037);

  /// Board frame inner color (medium wood)
  static const Color boardFrameInner = Color(0xFF795548);

  /// Board background (outer frame) - warm brown
  static const Color boardBackground = Color(0xFF6D4C41);

  /// Grid line color (darker inset wood grain)
  static const Color gridLine = Color(0xFF4E342E);

  /// Grid line shadow (for inset effect)
  static const Color gridLineShadow = Color(0xFF3E2723);

  /// Grid line highlight (for inset effect)
  static const Color gridLineHighlight = Color(0xFF8D6E63);

  /// Cell background (empty cell) - warm tan wood
  static const Color cellBackground = Color(0xFFD7CCC8);

  /// Cell background light (for gradient)
  static const Color cellBackgroundLight = Color(0xFFEFEBE9);

  /// Cell background dark (for gradient)
  static const Color cellBackgroundDark = Color(0xFFBCAAA4);

  /// Wood grain accent color
  static const Color woodGrainAccent = Color(0xFFC9B8A8);

  /// Cell background when selected (golden glow)
  static const Color cellSelected = Color(0xFFFFE082);

  /// Cell selected outer glow
  static const Color cellSelectedGlow = Color(0xFFFFD54F);

  /// Cell border when selected
  static const Color cellSelectedBorder = Color(0xFFFFA000);

  /// Cell background for drop path (soft blue)
  static const Color cellDropPath = Color(0xFFBBDEFB);

  /// Cell drop path glow
  static const Color cellDropPathGlow = Color(0xFF90CAF9);

  /// Cell border for drop path
  static const Color cellDropPathBorder = Color(0xFF42A5F5);

  /// Cell background for next drop position (soft green)
  static const Color cellNextDrop = Color(0xFFC8E6C9);

  /// Cell next drop glow
  static const Color cellNextDropGlow = Color(0xFFA5D6A7);

  /// Cell border for next drop position
  static const Color cellNextDropBorder = Color(0xFF66BB6A);

  // ==========================================================================
  // UI Colors
  // ==========================================================================

  /// Stack height badge background
  static const Color stackBadge = Color(0xFF5D4037);

  /// Stack height badge text
  static const Color stackBadgeText = Colors.white;

  /// Current player indicator background (light player turn)
  static const Color turnIndicatorLight = Color(0xFFEEEEEE);

  /// Current player indicator background (dark player turn)
  static const Color turnIndicatorDark = Color(0xFF424242);

  /// Control panel background
  static const Color controlPanelBg = Color(0xFFFAF8F5);

  /// Control panel border
  static const Color controlPanelBorder = Color(0xFFD7CCC8);

  /// Current player highlight
  static const Color currentPlayerHighlight = Color(0xFFFFF8E1);

  // ==========================================================================
  // Piece Icon Colors (for UI buttons, neutral representation)
  // ==========================================================================

  /// Piece icon fill color
  static const Color pieceIconFill = Color(0xFFD7CCC8);

  /// Piece icon border color
  static const Color pieceIconBorder = Color(0xFF795548);

  // ==========================================================================
  // Piece Shadows
  // ==========================================================================

  /// Shadow color for flat stones (subtle)
  static Color get flatStoneShadow => Colors.black.withValues(alpha: 0.15);

  /// Shadow color for standing stones (more prominent)
  static Color get standingStoneShadow => Colors.black.withValues(alpha: 0.35);

  /// Shadow color for capstones
  static Color get capstoneShadow => Colors.black.withValues(alpha: 0.25);

  // ==========================================================================
  // App Theme Colors
  // ==========================================================================

  /// Primary theme seed color
  static const Color themeSeed = Color(0xFF795548);

  /// Title text color
  static const Color titleColor = Color(0xFF4E342E);

  /// Subtitle text color
  static const Color subtitleColor = Color(0xFF6D4C41);

  // ==========================================================================
  // Helper Methods
  // ==========================================================================

  /// Get piece colors for a player
  static PieceColors forPlayer(bool isLightPlayer) {
    return isLightPlayer ? lightPlayerColors : darkPlayerColors;
  }

  /// Light player piece colors
  static const PieceColors lightPlayerColors = PieceColors(
    primary: lightPiece,
    secondary: lightPieceSecondary,
    border: lightPieceBorder,
  );

  /// Dark player piece colors
  static const PieceColors darkPlayerColors = PieceColors(
    primary: darkPiece,
    secondary: darkPieceSecondary,
    border: darkPieceBorder,
  );
}

/// Holds the color scheme for a player's pieces.
class PieceColors {
  final Color primary;
  final Color secondary;
  final Color border;

  const PieceColors({
    required this.primary,
    required this.secondary,
    required this.border,
  });

  /// Create gradient colors for piece rendering
  List<Color> get gradientColors => [primary, secondary];
}

import 'package:flutter/material.dart';

/// App color constants
class AppColors {
  AppColors._();

  // Board colors - warm wood tones
  static const Color boardBackground = Color(0xFF8B7355);
  static const Color boardCell = Color(0xFFD4B896);
  static const Color boardCellAlt = Color(0xFFC9A882);
  static const Color boardBorder = Color(0xFF5D4037);
  static const Color boardGrain = Color(0xFFB8956E);

  // Player colors - cream vs charcoal
  static const Color player1Primary = Color(0xFFF5EBE0); // Cream
  static const Color player1Border = Color(0xFF8B8178);
  static const Color player1Shadow = Color(0xFFD4CAC0);

  static const Color player2Primary = Color(0xFF3C3733); // Charcoal
  static const Color player2Border = Color(0xFF1A1816);
  static const Color player2Shadow = Color(0xFF2A2724);

  // Alternative theme - sage vs rust
  static const Color player1AltPrimary = Color(0xFFA8B5A0); // Sage
  static const Color player1AltBorder = Color(0xFF6B7A63);

  static const Color player2AltPrimary = Color(0xFFB5594A); // Rust
  static const Color player2AltBorder = Color(0xFF7A3A30);

  // UI colors
  static const Color primary = Color(0xFF795548);
  static const Color primaryDark = Color(0xFF5D4037);
  static const Color primaryLight = Color(0xFFA1887F);
  static const Color accent = Color(0xFFFFB74D);

  // Highlight colors
  static const Color selected = Color(0xFFFFF3E0);
  static const Color selectedBorder = Color(0xFFFFB74D);
  static const Color lastMove = Color(0xFFE3F2FD);
  static const Color lastMoveBorder = Color(0xFF64B5F6);
  static const Color legalMove = Color(0xFFE8F5E9);
  static const Color legalMoveBorder = Color(0xFF81C784);
  static const Color dropPath = Color(0xFFE3F2FD);
  static const Color dropPathBorder = Color(0xFF90CAF9);
  static const Color nextDrop = Color(0xFFC8E6C9);
  static const Color nextDropBorder = Color(0xFF66BB6A);

  // Road highlight (win animation)
  static const Color roadHighlight = Color(0xFFFFD54F);
  static const Color roadGlow = Color(0xFFFFF176);

  // Text colors
  static const Color textPrimary = Color(0xFF3E2723);
  static const Color textSecondary = Color(0xFF5D4037);
  static const Color textLight = Color(0xFFBCAAA4);
}

/// App text styles
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle title = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    letterSpacing: 12,
    color: AppColors.primaryDark,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static const TextStyle notation = TextStyle(
    fontSize: 14,
    fontFamily: 'monospace',
    color: AppColors.textPrimary,
  );
}

/// App dimensions and spacing
class AppDimens {
  AppDimens._();

  static const double paddingSmall = 8;
  static const double paddingMedium = 16;
  static const double paddingLarge = 24;
  static const double paddingXLarge = 32;

  static const double borderRadius = 8;
  static const double borderRadiusLarge = 16;

  static const double cellSpacing = 4;
  static const double boardPadding = 12;

  static const double pieceCornerRadius = 6;
  static const double stackOffset = 3;

  static const double iconSizeSmall = 20;
  static const double iconSizeMedium = 24;
  static const double iconSizeLarge = 32;
}

/// Animation durations
class AppAnimations {
  AppAnimations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration pulse = Duration(milliseconds: 800);
}

/// App theme data
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.paddingLarge,
            vertical: AppDimens.paddingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.borderRadius),
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.borderRadiusLarge),
        ),
      ),
    );
  }
}

/// Piece visual configuration based on theme
class PieceTheme {
  final Color primaryColor;
  final Color borderColor;
  final Color shadowColor;

  const PieceTheme({
    required this.primaryColor,
    required this.borderColor,
    required this.shadowColor,
  });

  static const PieceTheme player1Default = PieceTheme(
    primaryColor: AppColors.player1Primary,
    borderColor: AppColors.player1Border,
    shadowColor: AppColors.player1Shadow,
  );

  static const PieceTheme player2Default = PieceTheme(
    primaryColor: AppColors.player2Primary,
    borderColor: AppColors.player2Border,
    shadowColor: AppColors.player2Shadow,
  );

  static const PieceTheme player1Alt = PieceTheme(
    primaryColor: AppColors.player1AltPrimary,
    borderColor: AppColors.player1AltBorder,
    shadowColor: AppColors.player1AltPrimary,
  );

  static const PieceTheme player2Alt = PieceTheme(
    primaryColor: AppColors.player2AltPrimary,
    borderColor: AppColors.player2AltBorder,
    shadowColor: AppColors.player2AltPrimary,
  );
}

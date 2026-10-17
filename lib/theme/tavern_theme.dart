import 'package:flutter/material.dart';

/// Candidate design tokens. Production adopts these only after visual review.
class TavernTheme {
  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF995433),
      brightness: brightness,
    ).copyWith(
      primary: dark ? const Color(0xFFF0B782) : const Color(0xFF88401F),
      onPrimary: dark ? const Color(0xFF302015) : const Color(0xFFFFF8E8),
      surface: dark ? const Color(0xFF292522) : const Color(0xFFF7F1E4),
      onSurface: dark ? const Color(0xFFF3E9D5) : const Color(0xFF322B25),
      onSurfaceVariant:
          dark ? const Color(0xFFD0C4B8) : const Color(0xFF685B50),
      outline: dark ? const Color(0xFFA69584) : const Color(0xFF877568),
    );
    final base = ThemeData(
        colorScheme: scheme, fontFamily: 'StonesSans', useMaterial3: true);
    TextStyle heading(TextStyle? style) =>
        style!.copyWith(fontFamily: 'StonesLora', height: 1.18);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: base.textTheme.copyWith(
        displayLarge: heading(base.textTheme.displayLarge),
        displayMedium: heading(base.textTheme.displayMedium),
        headlineLarge: heading(base.textTheme.headlineLarge),
        headlineMedium: heading(base.textTheme.headlineMedium),
        headlineSmall: heading(base.textTheme.headlineSmall),
        titleLarge: heading(base.textTheme.titleLarge),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.onSurface.withValues(alpha: .04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme:
          DividerThemeData(color: scheme.onSurface.withValues(alpha: .16)),
    );
  }
}

/// Static, bounded decoration: no images, blur filters or animation loop.
class TavernBackdrop extends StatelessWidget {
  const TavernBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? const Color(0xFF1B1816) : const Color(0xFFEDE5D7),
      child: child,
    );
  }
}

class TavernPanel extends StatelessWidget {
  const TavernPanel({super.key, required this.child, this.padding = 24});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 3,
      shadowColor: const Color(0x30000000),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outline.withValues(alpha: .30))),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }
}

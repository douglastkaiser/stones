import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Candidate design tokens. Production adopts these only after visual review.
class TavernTheme {
  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF355D49),
      brightness: brightness,
    ).copyWith(
      primary: dark ? const Color(0xFFE4BC77) : const Color(0xFF315540),
      onPrimary: dark ? const Color(0xFF272015) : const Color(0xFFFFF8E8),
      surface: dark ? const Color(0xFF202B25) : const Color(0xFFF7F1E4),
      onSurface: dark ? const Color(0xFFF3E9D5) : const Color(0xFF263A2E),
      onSurfaceVariant: dark ? const Color(0xFFC6C9BC) : const Color(0xFF566356),
      outline: dark ? const Color(0xFF899584) : const Color(0xFF7F8977),
    );
    final base = ThemeData(colorScheme: scheme, fontFamily: 'StonesSans',
      useMaterial3: true);
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.onSurface.withValues(alpha: .04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
          color: scheme.onSurface.withValues(alpha: .16)),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-.75, -.85),
          radius: 1.7,
          colors: dark
              ? const [Color(0xFF394233), Color(0xFF18251E), Color(0xFF101A16)]
              : const [Color(0xFFFFF8E8), Color(0xFFEBE5D5), Color(0xFFD8DECD)],
        ),
      ),
      child: CustomPaint(painter: _Panelling(dark), child: child),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: .30)),
        boxShadow: const [
          BoxShadow(color: Color(0x18000000), blurRadius: 24, offset: Offset(0, 8))
        ],
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }
}

class _Panelling extends CustomPainter {
  const _Panelling(this.dark);
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? Colors.white : const Color(0xFF536745))
          .withValues(alpha: .035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 7; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final radius = math.min(size.width * .4, 360.0);
    for (final x in [0.0, size.width]) {
      canvas.drawCircle(Offset(x, 180), radius, paint);
      canvas.drawCircle(Offset(x, 180), radius + 12, paint);
    }
  }
  @override
  bool shouldRepaint(_Panelling oldDelegate) => oldDelegate.dark != dark;
}

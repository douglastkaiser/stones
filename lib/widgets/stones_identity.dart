import 'package:flutter/material.dart';

import 'stones_mark_geometry.dart';

/// Theme-aware rendering of the shared, background-free geometric mark.
class StonesMark extends StatelessWidget {
  const StonesMark({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _MarkPainter(scheme.onSurface, scheme.primary),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.foreground, this.accent);
  final Color foreground;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    paintStonesMark(canvas, foreground, accent);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.foreground != foreground || oldDelegate.accent != accent;
}

class StonesWordmark extends StatelessWidget {
  const StonesWordmark({super.key, this.fontSize = 26});
  final double fontSize;

  @override
  Widget build(BuildContext context) => Text('STONES',
      maxLines: 1,
      style: TextStyle(
          fontFamily: 'StonesSans',
          fontSize: fontSize,
          letterSpacing: 3,
          color: Theme.of(context).colorScheme.onSurface));
}

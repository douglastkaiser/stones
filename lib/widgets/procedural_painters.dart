import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cosmetics.dart';
import '../theme/game_colors.dart';

// =============================================================================
// NOISE AND PATTERN UTILITIES
// =============================================================================

/// Simple seeded random for deterministic patterns
class SeededRandom {
  int _seed;

  SeededRandom(this._seed);

  double next() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }

  double range(double min, double max) => min + next() * (max - min);
}

/// Perlin-like noise for smooth procedural textures
class SimplexNoise {
  final int seed;
  late final List<int> _perm;

  SimplexNoise({this.seed = 0}) {
    final random = SeededRandom(seed);
    _perm = List.generate(512, (i) => i < 256 ? i : _perm[i - 256]);
    // Shuffle first 256
    for (var i = 255; i > 0; i--) {
      final j = (random.next() * (i + 1)).floor();
      final temp = _perm[i];
      _perm[i] = _perm[j];
      _perm[j] = temp;
    }
    // Duplicate
    for (var i = 0; i < 256; i++) {
      _perm[i + 256] = _perm[i];
    }
  }

  double noise2D(double x, double y) {
    // Simple value noise implementation
    final xi = x.floor();
    final yi = y.floor();
    final xf = x - xi;
    final yf = y - yi;

    // Smooth interpolation
    final u = xf * xf * (3 - 2 * xf);
    final v = yf * yf * (3 - 2 * yf);

    final aa = _hash(xi, yi);
    final ab = _hash(xi, yi + 1);
    final ba = _hash(xi + 1, yi);
    final bb = _hash(xi + 1, yi + 1);

    final x1 = _lerp(aa, ba, u);
    final x2 = _lerp(ab, bb, u);

    return _lerp(x1, x2, v);
  }

  double _hash(int x, int y) {
    return _perm[(_perm[x & 255] + y) & 255] / 255.0;
  }

  double _lerp(double a, double b, double t) => a + t * (b - a);

  /// Fractal Brownian Motion - layered noise for natural textures
  double fbm(double x, double y, {int octaves = 4, double persistence = 0.5}) {
    double total = 0;
    double frequency = 1;
    double amplitude = 1;
    double maxValue = 0;

    for (var i = 0; i < octaves; i++) {
      total += noise2D(x * frequency, y * frequency) * amplitude;
      maxValue += amplitude;
      amplitude *= persistence;
      frequency *= 2;
    }

    return total / maxValue;
  }
}

// =============================================================================
// BOARD TEXTURE PAINTERS
// =============================================================================

/// Wood grain texture painter
class WoodGrainPainter extends CustomPainter {
  final Color baseColor;
  final Color grainColor;
  final Color knotColor;
  final int seed;

  WoodGrainPainter({
    required this.baseColor,
    required this.grainColor,
    required this.knotColor,
    this.seed = 42,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final noise = SimplexNoise(seed: seed);
    final random = SeededRandom(seed);

    // Base color
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = baseColor,
    );

    // Draw wood grain lines
    final grainPaint = Paint()
      ..color = grainColor.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < size.height; i += 3) {
      final path = Path();
      path.moveTo(0, i.toDouble());

      for (var x = 0.0; x < size.width; x += 2) {
        final wobble = noise.noise2D(x * 0.02, i * 0.1) * 4;
        path.lineTo(x, i + wobble);
      }

      canvas.drawPath(path, grainPaint);
    }

    // Add some wood knots
    final knotPaint = Paint()..color = knotColor.withValues(alpha: 0.2);
    final numKnots = (size.width * size.height / 10000).round().clamp(1, 5);

    for (var i = 0; i < numKnots; i++) {
      final x = random.range(size.width * 0.1, size.width * 0.9);
      final y = random.range(size.height * 0.1, size.height * 0.9);
      final radius = random.range(3, 8);

      // Draw concentric rings for knot
      for (var r = radius; r > 0; r -= 1.5) {
        canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..color = knotColor.withValues(alpha: 0.1 + (radius - r) / radius * 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
      canvas.drawCircle(Offset(x, y), 2, knotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WoodGrainPainter oldDelegate) =>
      baseColor != oldDelegate.baseColor ||
      grainColor != oldDelegate.grainColor ||
      seed != oldDelegate.seed;
}

/// Marble texture painter with veins
class MarbleTexturePainter extends CustomPainter {
  final Color baseColor;
  final Color veinColor;
  final Color accentColor;
  final int seed;

  MarbleTexturePainter({
    required this.baseColor,
    required this.veinColor,
    required this.accentColor,
    this.seed = 42,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final noise = SimplexNoise(seed: seed);

    // Base gradient
    final baseGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        baseColor,
        Color.lerp(baseColor, veinColor, 0.1)!,
        baseColor,
      ],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = baseGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Draw marble veins
    final veinPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Primary veins
    for (var v = 0; v < 3; v++) {
      final path = Path();
      final startX = noise.noise2D(v * 10.0, 0) * size.width;
      final startY = noise.noise2D(0, v * 10.0) * size.height * 0.3;

      path.moveTo(startX, startY);

      var x = startX;
      var y = startY;

      while (y < size.height && x >= 0 && x <= size.width) {
        final dx = noise.fbm(x * 0.01, y * 0.01 + v * 100, octaves: 3) * 30 - 15;
        final dy = 5 + noise.noise2D(x * 0.02, y * 0.02) * 3;

        x += dx;
        y += dy;

        path.lineTo(x, y);
      }

      // Draw with varying thickness
      veinPaint.color = veinColor.withValues(alpha: 0.3);
      veinPaint.strokeWidth = 2.0;
      canvas.drawPath(path, veinPaint);

      veinPaint.color = veinColor.withValues(alpha: 0.15);
      veinPaint.strokeWidth = 4.0;
      canvas.drawPath(path, veinPaint);
    }

    // Secondary thinner veins
    for (var v = 0; v < 5; v++) {
      final path = Path();
      final startX = noise.noise2D(v * 20.0, 100) * size.width;
      final startY = noise.noise2D(100, v * 20.0) * size.height;

      path.moveTo(startX, startY);

      var x = startX;
      var y = startY;
      final angle = noise.noise2D(v.toDouble(), v.toDouble()) * math.pi;

      for (var i = 0; i < 20; i++) {
        final dx = math.cos(angle) * 8 + noise.noise2D(x * 0.05, y * 0.05) * 6;
        final dy = math.sin(angle) * 8 + noise.noise2D(y * 0.05, x * 0.05) * 6;
        x += dx;
        y += dy;
        path.lineTo(x, y);
      }

      veinPaint.color = accentColor.withValues(alpha: 0.2);
      veinPaint.strokeWidth = 1.0;
      canvas.drawPath(path, veinPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MarbleTexturePainter oldDelegate) =>
      baseColor != oldDelegate.baseColor ||
      veinColor != oldDelegate.veinColor ||
      seed != oldDelegate.seed;
}

/// Stone/slate texture painter
class StoneTexturePainter extends CustomPainter {
  final Color baseColor;
  final Color highlightColor;
  final Color shadowColor;
  final int seed;

  StoneTexturePainter({
    required this.baseColor,
    required this.highlightColor,
    required this.shadowColor,
    this.seed = 42,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final noise = SimplexNoise(seed: seed);
    final random = SeededRandom(seed);

    // Base with subtle noise variation
    for (var y = 0.0; y < size.height; y += 2) {
      for (var x = 0.0; x < size.width; x += 2) {
        final n = noise.fbm(x * 0.05, y * 0.05, octaves: 3);
        final color = Color.lerp(
          shadowColor,
          Color.lerp(baseColor, highlightColor, n)!,
          0.5 + n * 0.5,
        )!;

        canvas.drawRect(
          Rect.fromLTWH(x, y, 2, 2),
          Paint()..color = color,
        );
      }
    }

    // Add subtle cracks
    final crackPaint = Paint()
      ..color = shadowColor.withValues(alpha: 0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (var c = 0; c < 4; c++) {
      final path = Path();
      var x = random.range(0, size.width);
      var y = random.range(0, size.height);
      path.moveTo(x, y);

      for (var i = 0; i < 10; i++) {
        x += random.range(-8, 8);
        y += random.range(-8, 8);
        path.lineTo(x.clamp(0, size.width), y.clamp(0, size.height));
      }

      canvas.drawPath(path, crackPaint);
    }

    // Add some lichen/mineral spots
    final spotPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 8; i++) {
      final x = random.range(0, size.width);
      final y = random.range(0, size.height);
      final radius = random.range(1, 4);

      spotPaint.color = Color.lerp(highlightColor, baseColor, random.next())!
          .withValues(alpha: 0.2);
      canvas.drawCircle(Offset(x, y), radius, spotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant StoneTexturePainter oldDelegate) =>
      baseColor != oldDelegate.baseColor || seed != oldDelegate.seed;
}

/// Minimalist geometric pattern painter
class MinimalistPatternPainter extends CustomPainter {
  final Color baseColor;
  final Color lineColor;

  MinimalistPatternPainter({
    required this.baseColor,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Clean base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = baseColor,
    );

    // Subtle grid pattern
    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;

    const spacing = 8.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant MinimalistPatternPainter oldDelegate) =>
      baseColor != oldDelegate.baseColor || lineColor != oldDelegate.lineColor;
}

/// Pixel art retro pattern painter
class PixelArtPatternPainter extends CustomPainter {
  final Color baseColor;
  final Color color1;
  final Color color2;
  final int seed;

  PixelArtPatternPainter({
    required this.baseColor,
    required this.color1,
    required this.color2,
    this.seed = 42,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = SeededRandom(seed);
    const pixelSize = 4.0;

    for (var y = 0.0; y < size.height; y += pixelSize) {
      for (var x = 0.0; x < size.width; x += pixelSize) {
        final r = random.next();
        Color color;
        if (r < 0.7) {
          color = baseColor;
        } else if (r < 0.85) {
          color = color1;
        } else {
          color = color2;
        }

        canvas.drawRect(
          Rect.fromLTWH(x, y, pixelSize, pixelSize),
          Paint()..color = color,
        );
      }
    }

    // Add a dithered edge effect
    final edgePaint = Paint()..color = color2.withValues(alpha: 0.3);
    for (var i = 0.0; i < size.width; i += pixelSize * 2) {
      canvas.drawRect(Rect.fromLTWH(i, 0, pixelSize, pixelSize), edgePaint);
      canvas.drawRect(
        Rect.fromLTWH(i + pixelSize, size.height - pixelSize, pixelSize, pixelSize),
        edgePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PixelArtPatternPainter oldDelegate) =>
      baseColor != oldDelegate.baseColor || seed != oldDelegate.seed;
}

// =============================================================================
// PIECE PAINTERS - STANDARD STYLE
// =============================================================================

/// Standard flat stone - trapezoid for light, rounded for dark
class StandardFlatPainter extends CustomPainter {
  final PieceColors colors;
  final bool isLightPlayer;

  StandardFlatPainter({required this.colors, required this.isLightPlayer});

  @override
  void paint(Canvas canvas, Size size) {
    if (isLightPlayer) {
      _paintTrapezoid(canvas, size);
    } else {
      _paintRoundedFlat(canvas, size);
    }
  }

  void _paintTrapezoid(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final inset = w * 0.15;

    path.moveTo(inset, 0);
    path.lineTo(w - inset, 0);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(2, 2)),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Main body with gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [colors.primary, colors.secondary],
    );

    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Highlight
    canvas.drawLine(
      Offset(inset + 2, 2),
      Offset(w - inset - 2, 2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintRoundedFlat(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Almost a full circle with just a small sliver cut off at the bottom
    // The chord line is below the diameter, showing most of the circle
    final centerX = w / 2;
    final radius = w * 0.44; // Circle radius
    final chordY = h * 0.85; // Where the flat bottom cuts the circle (below center)
    // Calculate how wide the chord is at this Y position
    // For a circle centered at (centerX, centerY), chord half-width = sqrt(r^2 - d^2)
    // where d is distance from center to chord
    final centerY = h * 0.5; // Circle center
    final distFromCenter = chordY - centerY; // How far chord is below center
    final chordHalfWidth = (radius * radius - distFromCenter * distFromCenter);
    final halfWidth = chordHalfWidth > 0 ? math.sqrt(chordHalfWidth) : radius * 0.3;

    final path = Path();
    path.moveTo(centerX - halfWidth, chordY);
    // Arc going UP and around (the long way) to create almost-full circle
    path.arcToPoint(
      Offset(centerX + halfWidth, chordY),
      radius: Radius.circular(radius),
      largeArc: true, // Take the long way around (>180 degrees)
    );
    path.close();

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(2, 2)),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Main body - simple flat gradient like trapezoid
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [colors.primary, colors.secondary],
    );

    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Border only - no highlight
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant StandardFlatPainter oldDelegate) =>
      colors != oldDelegate.colors || isLightPlayer != oldDelegate.isLightPlayer;
}

/// Standard standing stone (wall) - diagonal bar
class StandardWallPainter extends CustomPainter {
  final PieceColors colors;

  StandardWallPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final thickness = w * 0.25;

    final path = Path();
    path.moveTo(w * 0.15, h);
    path.lineTo(w * 0.15 + thickness, h);
    path.lineTo(w * 0.85, 0);
    path.lineTo(w * 0.85 - thickness, 0);
    path.close();

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(2, 2)),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Main body
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [colors.primary, colors.secondary],
    );

    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Highlight edge
    canvas.drawLine(
      Offset(w * 0.85 - thickness + 2, 2),
      Offset(w * 0.85 - 2, 2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant StandardWallPainter oldDelegate) =>
      colors != oldDelegate.colors;
}

/// Standard capstone - domed cylinder
class StandardCapstonePainter extends CustomPainter {
  final PieceColors colors;

  StandardCapstonePainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX + 2, h * 0.85 + 2), width: w * 0.8, height: h * 0.3),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Base ellipse
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX, h * 0.85), width: w * 0.8, height: h * 0.3),
      Paint()..color = colors.secondary,
    );

    // Dome
    final domePath = Path();
    domePath.moveTo(w * 0.1, h * 0.85);
    domePath.quadraticBezierTo(w * 0.1, h * 0.2, centerX, h * 0.1);
    domePath.quadraticBezierTo(w * 0.9, h * 0.2, w * 0.9, h * 0.85);
    domePath.close();

    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.5),
      radius: 1.2,
      colors: [colors.primary, colors.secondary],
    );

    canvas.drawPath(
      domePath,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Border
    canvas.drawPath(
      domePath,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Highlight
    canvas.drawArc(
      Rect.fromLTWH(w * 0.25, h * 0.15, w * 0.4, h * 0.4),
      -math.pi * 0.8,
      math.pi * 0.5,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant StandardCapstonePainter oldDelegate) =>
      colors != oldDelegate.colors;
}

// =============================================================================
// PIECE PAINTERS - POLISHED MARBLE STYLE
// =============================================================================

/// Polished marble flat - smooth oval shapes with shine
/// Both players use the same elegant oval shape (different colors)
/// Enhanced contrast for visibility against marble board
class MarbleFlatPainter extends CustomPainter {
  final PieceColors colors;
  final bool isLightPlayer;

  MarbleFlatPainter({required this.colors, required this.isLightPlayer});

  @override
  void paint(Canvas canvas, Size size) {
    // Both light and dark use the same elegant oval shape
    _paintOvalFlat(canvas, size);
  }

  void _paintOvalFlat(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Elongated horizontal oval
    final rect = Rect.fromLTWH(w * 0.05, h * 0.15, w * 0.9, h * 0.7);

    // Strong shadow for visibility
    canvas.drawOval(
      rect.shift(const Offset(2, 3)),
      Paint()..color = colors.border.withValues(alpha: 0.5),
    );

    // Main body - smooth oval with enhanced gradient
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 1.0,
      colors: [
        Color.lerp(colors.primary, Colors.white, isLightPlayer ? 0.3 : 0.2)!,
        colors.primary,
        colors.secondary,
      ],
      stops: const [0.0, 0.4, 1.0],
    );

    canvas.drawOval(rect, Paint()..shader = gradient.createShader(rect));

    // Strong border for pop/visibility
    canvas.drawOval(
      rect,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Polished shine highlight
    canvas.drawOval(
      Rect.fromLTWH(w * 0.15, h * 0.2, w * 0.35, h * 0.25),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: isLightPlayer ? 0.7 : 0.5),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(w * 0.15, h * 0.2, w * 0.35, h * 0.25)),
    );

    // Secondary small highlight for extra polish
    canvas.drawOval(
      Rect.fromLTWH(w * 0.55, h * 0.35, w * 0.15, h * 0.12),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(w * 0.55, h * 0.35, w * 0.15, h * 0.12)),
    );
  }

  @override
  bool shouldRepaint(covariant MarbleFlatPainter oldDelegate) =>
      colors != oldDelegate.colors || isLightPlayer != oldDelegate.isLightPlayer;
}

/// Polished marble wall - smooth diagonal slab
class MarbleWallPainter extends CustomPainter {
  final PieceColors colors;

  MarbleWallPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final thickness = w * 0.22;

    // Rounded rectangle rotated
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, h / 2), width: thickness, height: h * 0.95),
      Radius.circular(thickness * 0.3),
    );

    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-math.pi / 6);
    canvas.translate(-w / 2, -h / 2);

    // Shadow
    canvas.drawRRect(
      rect.shift(const Offset(3, 3)),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Main body
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(colors.primary, Colors.white, 0.15)!,
        colors.primary,
        colors.secondary,
      ],
    );

    canvas.drawRRect(
      rect,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Border
    canvas.drawRRect(
      rect,
      Paint()
        ..color = colors.border.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MarbleWallPainter oldDelegate) =>
      colors != oldDelegate.colors;
}

/// Polished marble capstone - smooth sphere
class MarbleCapstonePainter extends CustomPainter {
  final PieceColors colors;

  MarbleCapstonePainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;
    final centerY = h / 2;
    final radius = math.min(w, h) * 0.4;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX + 2, h * 0.85), width: radius * 2, height: radius * 0.5),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Sphere with 3D shading
    final sphereGradient = RadialGradient(
      center: const Alignment(-0.4, -0.4),
      radius: 0.9,
      colors: [
        Color.lerp(colors.primary, Colors.white, 0.4)!,
        colors.primary,
        colors.secondary,
        Color.lerp(colors.secondary, Colors.black, 0.2)!,
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );

    canvas.drawCircle(
      Offset(centerX, centerY),
      radius,
      Paint()..shader = sphereGradient.createShader(
        Rect.fromCenter(center: Offset(centerX, centerY), width: radius * 2, height: radius * 2),
      ),
    );

    // Highlight
    canvas.drawCircle(
      Offset(centerX - radius * 0.3, centerY - radius * 0.3),
      radius * 0.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.7),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(centerX - radius * 0.3, centerY - radius * 0.3),
          radius: radius * 0.2,
        )),
    );
  }

  @override
  bool shouldRepaint(covariant MarbleCapstonePainter oldDelegate) =>
      colors != oldDelegate.colors;
}

// =============================================================================
// PIECE PAINTERS - CHISELED STONE STYLE
// =============================================================================

/// Stone flat - angular faceted shapes
/// Light: hexagonal prism top-down view
/// Dark: pentagon/angular shield shape
class StoneFlatPainter extends CustomPainter {
  final PieceColors colors;
  final bool isLightPlayer;

  StoneFlatPainter({required this.colors, required this.isLightPlayer});

  @override
  void paint(Canvas canvas, Size size) {
    if (isLightPlayer) {
      _paintHexagonFlat(canvas, size);
    } else {
      _paintShieldFlat(canvas, size);
    }
  }

  void _paintHexagonFlat(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;
    final centerY = h / 2;

    // Hexagon shape (stretched horizontally)
    final path = Path();
    final radiusX = w * 0.45;
    final radiusY = h * 0.42;
    for (var i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * math.pi - math.pi / 2;
      final x = centerX + math.cos(angle) * radiusX;
      final y = centerY + math.sin(angle) * radiusY;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(2, 2)),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Main body with stone gradient
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(colors.primary, Colors.white, 0.1)!,
        colors.primary,
        colors.secondary,
      ],
    );

    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Facet lines for 3D effect
    final facetPaint = Paint()
      ..color = colors.border.withValues(alpha: 0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(centerX, centerY), Offset(centerX, h * 0.08), facetPaint);
    canvas.drawLine(Offset(centerX, centerY), Offset(w * 0.08, h * 0.3), facetPaint);
    canvas.drawLine(Offset(centerX, centerY), Offset(w * 0.92, h * 0.3), facetPaint);

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Highlight
    canvas.drawLine(
      Offset(w * 0.15, h * 0.35),
      Offset(centerX - 2, h * 0.1),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintShieldFlat(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;

    // Shield/pentagon shape - pointed at TOP (flat bottom sits on table)
    final path = Path();
    path.moveTo(centerX, h * 0.08); // Top point
    path.lineTo(w * 0.92, h * 0.45); // Right upper
    path.lineTo(w * 0.92, h * 0.88); // Right lower
    path.lineTo(w * 0.08, h * 0.88); // Left lower
    path.lineTo(w * 0.08, h * 0.45); // Left upper
    path.close();

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(2, 2)),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Main body with stone gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(colors.primary, Colors.white, 0.05)!,
        colors.primary,
        colors.secondary,
      ],
    );

    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Central ridge line from point to base
    final ridgePaint = Paint()
      ..color = colors.border.withValues(alpha: 0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(centerX, h * 0.12), Offset(centerX, h * 0.85), ridgePaint);

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Top edge highlight (from point to sides)
    canvas.drawLine(
      Offset(centerX, h * 0.1),
      Offset(w * 0.88, h * 0.43),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant StoneFlatPainter oldDelegate) =>
      colors != oldDelegate.colors || isLightPlayer != oldDelegate.isLightPlayer;
}

/// Stone wall - angular slab with chiseled edges
class StoneWallPainter extends CustomPainter {
  final PieceColors colors;

  StoneWallPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final thickness = w * 0.26;

    // Angular slab shape with beveled edges
    final path = Path();
    path.moveTo(w * 0.12, h);
    path.lineTo(w * 0.12 + thickness, h);
    path.lineTo(w * 0.88, h * 0.05);
    path.lineTo(w * 0.88 - thickness, 0);
    path.lineTo(w * 0.12, h * 0.03);
    path.close();

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(2, 2)),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Main body with stone gradient
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(colors.primary, Colors.white, 0.1)!,
        colors.primary,
        colors.secondary,
      ],
    );

    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Chisel marks texture
    final chiselPaint = Paint()
      ..color = colors.border.withValues(alpha: 0.12)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 4; i++) {
      final y = h * 0.25 + i * h * 0.18;
      final startX = w * 0.25 + i * w * 0.05;
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + w * 0.25, y - h * 0.08),
        chiselPaint,
      );
    }

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Highlight edge
    canvas.drawLine(
      Offset(w * 0.88 - thickness + 3, 2),
      Offset(w * 0.88 - 3, h * 0.06),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant StoneWallPainter oldDelegate) =>
      colors != oldDelegate.colors;
}

/// Stone capstone - angular obelisk/pyramid top
class StoneCapstonePainter extends CustomPainter {
  final PieceColors colors;

  StoneCapstonePainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;

    // Obelisk shape - tapered with flat top
    final path = Path();
    path.moveTo(w * 0.15, h * 0.9); // Bottom left
    path.lineTo(w * 0.85, h * 0.9); // Bottom right
    path.lineTo(w * 0.7, h * 0.15); // Top right
    path.lineTo(centerX, h * 0.05); // Peak
    path.lineTo(w * 0.3, h * 0.15); // Top left
    path.close();

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(2, 3)),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Main body with stone gradient
    final gradient = RadialGradient(
      center: const Alignment(-0.2, -0.4),
      radius: 1.2,
      colors: [
        Color.lerp(colors.primary, Colors.white, 0.15)!,
        colors.primary,
        colors.secondary,
      ],
    );

    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Facet lines
    final facetPaint = Paint()
      ..color = colors.border.withValues(alpha: 0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(centerX, h * 0.05), Offset(centerX, h * 0.88), facetPaint);
    canvas.drawLine(Offset(centerX, h * 0.05), Offset(w * 0.3, h * 0.15), facetPaint);
    canvas.drawLine(Offset(centerX, h * 0.05), Offset(w * 0.7, h * 0.15), facetPaint);

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Highlight on left face
    canvas.drawLine(
      Offset(w * 0.32, h * 0.18),
      Offset(centerX - 2, h * 0.08),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant StoneCapstonePainter oldDelegate) =>
      colors != oldDelegate.colors;
}

// =============================================================================
// PIECE PAINTERS - MINIMALIST STYLE
// =============================================================================

/// Minimalist flat - clean geometric shapes
/// Both players use the same rounded square shape (different colors)
class MinimalistFlatPainter extends CustomPainter {
  final PieceColors colors;
  final bool isLightPlayer;

  MinimalistFlatPainter({required this.colors, required this.isLightPlayer});

  @override
  void paint(Canvas canvas, Size size) {
    // Both light and dark use the same rounded square shape
    _paintSquareFlat(canvas, size);
  }

  void _paintSquareFlat(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final inset = w * 0.1;
    final cornerRadius = w * 0.12;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, w - inset * 2, h - inset * 2),
      Radius.circular(cornerRadius),
    );

    // Subtle shadow
    canvas.drawRRect(
      rect.shift(const Offset(1.5, 1.5)),
      Paint()..color = colors.border.withValues(alpha: 0.2),
    );

    // Clean solid fill
    canvas.drawRRect(
      rect,
      Paint()..color = colors.primary,
    );

    // Thin precise border
    canvas.drawRRect(
      rect,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant MinimalistFlatPainter oldDelegate) =>
      colors != oldDelegate.colors || isLightPlayer != oldDelegate.isLightPlayer;
}

/// Minimalist wall - clean diagonal rectangle
class MinimalistWallPainter extends CustomPainter {
  final PieceColors colors;

  MinimalistWallPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final thickness = w * 0.2;

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, h / 2), width: thickness, height: h * 0.9),
      Radius.circular(thickness * 0.15),
    );

    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-math.pi / 6);
    canvas.translate(-w / 2, -h / 2);

    // Subtle shadow
    canvas.drawRRect(
      rect.shift(const Offset(1.5, 1.5)),
      Paint()..color = colors.border.withValues(alpha: 0.2),
    );

    // Clean solid fill
    canvas.drawRRect(
      rect,
      Paint()..color = colors.primary,
    );

    // Thin precise border
    canvas.drawRRect(
      rect,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MinimalistWallPainter oldDelegate) =>
      colors != oldDelegate.colors;
}

/// Minimalist capstone - clean cylinder
class MinimalistCapstonePainter extends CustomPainter {
  final PieceColors colors;

  MinimalistCapstonePainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;
    final radius = w * 0.32;

    // Cylinder body
    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(centerX - radius, h * 0.25, radius * 2, h * 0.65),
      topLeft: Radius.circular(radius * 0.1),
      topRight: Radius.circular(radius * 0.1),
    );

    // Shadow
    canvas.drawRRect(
      bodyRect.shift(const Offset(1.5, 1.5)),
      Paint()..color = colors.border.withValues(alpha: 0.2),
    );

    // Body fill
    canvas.drawRRect(
      bodyRect,
      Paint()..color = colors.secondary,
    );

    // Top ellipse
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX, h * 0.28), width: radius * 2, height: h * 0.2),
      Paint()..color = colors.primary,
    );

    // Body border
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Top ellipse border
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX, h * 0.28), width: radius * 2, height: h * 0.2),
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant MinimalistCapstonePainter oldDelegate) =>
      colors != oldDelegate.colors;
}

// =============================================================================
// PIECE PAINTERS - PIXEL ART STYLE
// =============================================================================

/// Pixel art flat - blocky 8-bit shapes
/// Light: pixelated diamond
/// Dark: pixelated cross/plus
class PixelFlatPainter extends CustomPainter {
  final PieceColors colors;
  final bool isLightPlayer;

  PixelFlatPainter({required this.colors, required this.isLightPlayer});

  @override
  void paint(Canvas canvas, Size size) {
    if (isLightPlayer) {
      _paintPixelDiamond(canvas, size);
    } else {
      _paintPixelCross(canvas, size);
    }
  }

  void _paintPixelDiamond(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final px = w / 8; // Pixel size
    final py = h / 8;

    // Diamond shape made of pixels
    const pixels = <Offset>[
      // Row 0 (top)
      Offset(3, 0),
      Offset(4, 0),
      // Row 1
      Offset(2, 1), Offset(3, 1), Offset(4, 1), Offset(5, 1),
      // Row 2
      Offset(1, 2), Offset(2, 2), Offset(3, 2), Offset(4, 2), Offset(5, 2), Offset(6, 2),
      // Row 3 (middle)
      Offset(0, 3), Offset(1, 3), Offset(2, 3), Offset(3, 3), Offset(4, 3), Offset(5, 3), Offset(6, 3), Offset(7, 3),
      // Row 4
      Offset(0, 4), Offset(1, 4), Offset(2, 4), Offset(3, 4), Offset(4, 4), Offset(5, 4), Offset(6, 4), Offset(7, 4),
      // Row 5
      Offset(1, 5), Offset(2, 5), Offset(3, 5), Offset(4, 5), Offset(5, 5), Offset(6, 5),
      // Row 6
      Offset(2, 6), Offset(3, 6), Offset(4, 6), Offset(5, 6),
      // Row 7 (bottom)
      Offset(3, 7),
      Offset(4, 7),
    ];

    // Black outline pixels for visibility (1 pixel larger border)
    const outlinePixels = <Offset>[
      // Top outline
      Offset(2, -1), Offset(3, -1), Offset(4, -1), Offset(5, -1),
      // Left side outline
      Offset(-1, 3), Offset(-1, 4),
      Offset(0, 2), Offset(0, 5),
      Offset(1, 1), Offset(1, 6),
      Offset(2, 0), Offset(2, 7),
      // Right side outline
      Offset(8, 3), Offset(8, 4),
      Offset(7, 2), Offset(7, 5),
      Offset(6, 1), Offset(6, 6),
      Offset(5, 0), Offset(5, 7),
      // Bottom outline
      Offset(2, 8), Offset(3, 8), Offset(4, 8), Offset(5, 8),
    ];

    // Draw black outline first
    final outlinePaint = Paint()..color = const Color(0xFF1A1C2C);
    for (final p in outlinePixels) {
      if (p.dx >= 0 && p.dx < 8 && p.dy >= 0 && p.dy < 8) {
        canvas.drawRect(
          Rect.fromLTWH(p.dx * px, p.dy * py, px, py),
          outlinePaint,
        );
      }
    }

    // Shadow pixels
    final shadowPaint = Paint()..color = colors.border.withValues(alpha: 0.4);
    for (final p in pixels) {
      canvas.drawRect(
        Rect.fromLTWH(p.dx * px + 2, p.dy * py + 2, px, py),
        shadowPaint,
      );
    }

    // Main pixels with slight color variation for retro feel
    for (final p in pixels) {
      final isHighlight = p.dy < 3;
      final color = isHighlight
          ? Color.lerp(colors.primary, Colors.white, 0.1)!
          : (p.dy > 5 ? colors.secondary : colors.primary);
      canvas.drawRect(
        Rect.fromLTWH(p.dx * px, p.dy * py, px, py),
        Paint()..color = color,
      );
    }

    // Strong pixel border effect on edges
    final borderPaint = Paint()..color = colors.border;
    // Top edge
    canvas.drawRect(Rect.fromLTWH(3 * px, 0, px * 2, 2), borderPaint);
    // Bottom edge
    canvas.drawRect(Rect.fromLTWH(3 * px, h - 2, px * 2, 2), borderPaint);
    // Left edge
    canvas.drawRect(Rect.fromLTWH(0, 3 * py, 2, py * 2), borderPaint);
    // Right edge
    canvas.drawRect(Rect.fromLTWH(w - 2, 3 * py, 2, py * 2), borderPaint);
  }

  void _paintPixelCross(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final px = w / 8; // Pixel size
    final py = h / 8;

    // Cross/plus shape made of pixels
    const pixels = <Offset>[
      // Vertical bar
      Offset(3, 0), Offset(4, 0),
      Offset(3, 1), Offset(4, 1),
      Offset(3, 2), Offset(4, 2),
      Offset(3, 5), Offset(4, 5),
      Offset(3, 6), Offset(4, 6),
      Offset(3, 7), Offset(4, 7),
      // Horizontal bar (middle section)
      Offset(0, 3), Offset(1, 3), Offset(2, 3), Offset(3, 3), Offset(4, 3), Offset(5, 3), Offset(6, 3), Offset(7, 3),
      Offset(0, 4), Offset(1, 4), Offset(2, 4), Offset(3, 4), Offset(4, 4), Offset(5, 4), Offset(6, 4), Offset(7, 4),
    ];

    // Shadow pixels
    final shadowPaint = Paint()..color = colors.border.withValues(alpha: 0.3);
    for (final p in pixels) {
      canvas.drawRect(
        Rect.fromLTWH(p.dx * px + 2, p.dy * py + 2, px, py),
        shadowPaint,
      );
    }

    // Main pixels
    for (final p in pixels) {
      final isCenter = p.dx >= 2 && p.dx <= 5 && p.dy >= 2 && p.dy <= 5;
      final color = isCenter ? colors.primary : colors.secondary;
      canvas.drawRect(
        Rect.fromLTWH(p.dx * px, p.dy * py, px, py),
        Paint()..color = color,
      );
    }

    // Pixel border effect
    final borderPaint = Paint()..color = colors.border;
    canvas.drawRect(Rect.fromLTWH(3 * px, 0, px * 2, 1), borderPaint);
    canvas.drawRect(Rect.fromLTWH(0, 3 * py, 1, py * 2), borderPaint);
    canvas.drawRect(Rect.fromLTWH(w - 1, 3 * py, 1, py * 2), borderPaint);
    canvas.drawRect(Rect.fromLTWH(3 * px, h - 1, px * 2, 1), borderPaint);
  }

  @override
  bool shouldRepaint(covariant PixelFlatPainter oldDelegate) =>
      colors != oldDelegate.colors || isLightPlayer != oldDelegate.isLightPlayer;
}

/// Pixel art wall - blocky diagonal bar
class PixelWallPainter extends CustomPainter {
  final PieceColors colors;

  PixelWallPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final px = w / 8;
    final py = h / 8;

    // Diagonal bar made of stair-step pixels
    const pixels = <Offset>[
      // Bottom left to top right diagonal
      Offset(0, 6), Offset(0, 7), Offset(1, 6), Offset(1, 7),
      Offset(1, 5), Offset(2, 5), Offset(2, 6),
      Offset(2, 4), Offset(3, 4), Offset(3, 5),
      Offset(3, 3), Offset(4, 3), Offset(4, 4),
      Offset(4, 2), Offset(5, 2), Offset(5, 3),
      Offset(5, 1), Offset(6, 1), Offset(6, 2),
      Offset(6, 0), Offset(7, 0), Offset(7, 1),
    ];

    // Shadow
    final shadowPaint = Paint()..color = colors.border.withValues(alpha: 0.3);
    for (final p in pixels) {
      canvas.drawRect(
        Rect.fromLTWH(p.dx * px + 2, p.dy * py + 2, px, py),
        shadowPaint,
      );
    }

    // Main pixels
    for (final p in pixels) {
      final isTop = p.dy < 3;
      final color = isTop
          ? Color.lerp(colors.primary, Colors.white, 0.1)!
          : colors.primary;
      canvas.drawRect(
        Rect.fromLTWH(p.dx * px, p.dy * py, px, py),
        Paint()..color = color,
      );
    }

    // Pixel border on edges
    final borderPaint = Paint()..color = colors.border;
    canvas.drawRect(Rect.fromLTWH(6 * px, 0, px * 2, 1), borderPaint);
    canvas.drawRect(Rect.fromLTWH(0, h - 1, px * 2, 1), borderPaint);
  }

  @override
  bool shouldRepaint(covariant PixelWallPainter oldDelegate) =>
      colors != oldDelegate.colors;
}

/// Pixel art capstone - blocky tower/castle piece
class PixelCapstonePainter extends CustomPainter {
  final PieceColors colors;

  PixelCapstonePainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final px = w / 8;
    final py = h / 8;

    // Castle tower shape
    const pixels = <Offset>[
      // Battlements (top)
      Offset(1, 0), Offset(2, 0), Offset(5, 0), Offset(6, 0),
      Offset(1, 1), Offset(2, 1), Offset(3, 1), Offset(4, 1), Offset(5, 1), Offset(6, 1),
      // Tower body
      Offset(2, 2), Offset(3, 2), Offset(4, 2), Offset(5, 2),
      Offset(2, 3), Offset(3, 3), Offset(4, 3), Offset(5, 3),
      Offset(2, 4), Offset(3, 4), Offset(4, 4), Offset(5, 4),
      Offset(2, 5), Offset(3, 5), Offset(4, 5), Offset(5, 5),
      // Base (wider)
      Offset(1, 6), Offset(2, 6), Offset(3, 6), Offset(4, 6), Offset(5, 6), Offset(6, 6),
      Offset(1, 7), Offset(2, 7), Offset(3, 7), Offset(4, 7), Offset(5, 7), Offset(6, 7),
    ];

    // Shadow
    final shadowPaint = Paint()..color = colors.border.withValues(alpha: 0.3);
    for (final p in pixels) {
      canvas.drawRect(
        Rect.fromLTWH(p.dx * px + 2, p.dy * py + 2, px, py),
        shadowPaint,
      );
    }

    // Main pixels with shading
    for (final p in pixels) {
      Color color;
      if (p.dy <= 1) {
        color = Color.lerp(colors.primary, Colors.white, 0.15)!;
      } else if (p.dy >= 6) {
        color = colors.secondary;
      } else {
        color = colors.primary;
      }
      canvas.drawRect(
        Rect.fromLTWH(p.dx * px, p.dy * py, px, py),
        Paint()..color = color,
      );
    }

    // Window detail
    canvas.drawRect(
      Rect.fromLTWH(3 * px, 3 * py, px * 2, py * 2),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Pixel border
    final borderPaint = Paint()..color = colors.border;
    canvas.drawRect(Rect.fromLTWH(1 * px, 0, px * 2, 1), borderPaint);
    canvas.drawRect(Rect.fromLTWH(5 * px, 0, px * 2, 1), borderPaint);
    canvas.drawRect(Rect.fromLTWH(1 * px, h - 1, px * 6, 1), borderPaint);
  }

  @override
  bool shouldRepaint(covariant PixelCapstonePainter oldDelegate) =>
      colors != oldDelegate.colors;
}

// =============================================================================
// BOARD DECORATION PAINTERS
// =============================================================================

/// Corner ornament painter for decorative board corners
class CornerOrnamentPainter extends CustomPainter {
  final Color color;
  final BoardTheme theme;

  CornerOrnamentPainter({required this.color, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    switch (theme) {
      case BoardTheme.classicWood:
        _paintWoodCorner(canvas, size, paint);
      case BoardTheme.darkStone:
        _paintStoneCorner(canvas, size, paint);
      case BoardTheme.marble:
        _paintMarbleCorner(canvas, size, paint);
      case BoardTheme.minimalist:
        _paintMinimalistCorner(canvas, size, paint);
      case BoardTheme.pixelArt:
        _paintPixelCorner(canvas, size, paint);
    }
  }

  void _paintWoodCorner(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;

    // Celtic knot style corner with interlacing curves
    // Outer curve
    var path = Path();
    path.moveTo(0, h * 0.6);
    path.cubicTo(w * 0.25, h * 0.6, w * 0.6, h * 0.25, w * 0.6, 0);
    canvas.drawPath(path, paint);

    // Inner curve
    path = Path();
    path.moveTo(0, h * 0.35);
    path.cubicTo(w * 0.15, h * 0.35, w * 0.35, h * 0.15, w * 0.35, 0);
    canvas.drawPath(path, paint);

    // Decorative leaf/acorn shape
    paint.style = PaintingStyle.stroke;
    path = Path();
    path.moveTo(w * 0.12, h * 0.12);
    path.quadraticBezierTo(w * 0.2, h * 0.05, w * 0.18, h * 0.18);
    path.quadraticBezierTo(w * 0.05, h * 0.2, w * 0.12, h * 0.12);
    canvas.drawPath(path, paint);

    // Small dot detail
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.15, h * 0.15), 1.5, paint);
  }

  void _paintStoneCorner(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;

    // Runic/Norse style corner with angular patterns
    // Main angular frame
    final path = Path();
    path.moveTo(0, h * 0.5);
    path.lineTo(w * 0.15, h * 0.35);
    path.lineTo(w * 0.35, h * 0.15);
    path.lineTo(w * 0.5, 0);
    canvas.drawPath(path, paint);

    // Inner angular line
    canvas.drawLine(Offset(0, h * 0.3), Offset(w * 0.3, 0), paint);

    // Runic symbol detail (simplified Algiz rune)
    final runePath = Path();
    runePath.moveTo(w * 0.1, h * 0.25);
    runePath.lineTo(w * 0.15, h * 0.1);
    runePath.moveTo(w * 0.1, h * 0.15);
    runePath.lineTo(w * 0.2, h * 0.12);
    runePath.moveTo(w * 0.1, h * 0.15);
    runePath.lineTo(w * 0.05, h * 0.08);
    paint.strokeWidth = 1.2;
    canvas.drawPath(runePath, paint);

    // Stone dots
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.25, h * 0.25), 2, paint);
    canvas.drawCircle(Offset(w * 0.4, h * 0.1), 1.5, paint);
  }

  void _paintMarbleCorner(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;

    // Elegant baroque-style scroll with flourishes
    // Main scroll curve
    var path = Path();
    path.moveTo(0, h * 0.55);
    path.cubicTo(w * 0.2, h * 0.55, w * 0.55, h * 0.2, w * 0.55, 0);
    canvas.drawPath(path, paint);

    // Inner accent curve
    path = Path();
    path.moveTo(0, h * 0.35);
    path.cubicTo(w * 0.12, h * 0.35, w * 0.35, h * 0.12, w * 0.35, 0);
    canvas.drawPath(path, paint);

    // Decorative spiral flourish
    path = Path();
    path.moveTo(w * 0.15, h * 0.15);
    path.quadraticBezierTo(w * 0.25, h * 0.08, w * 0.2, h * 0.18);
    path.quadraticBezierTo(w * 0.12, h * 0.22, w * 0.18, h * 0.12);
    canvas.drawPath(path, paint);

    // Small decorative circles
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.0;
    canvas.drawCircle(Offset(w * 0.08, h * 0.08), 3, paint);
    canvas.drawCircle(Offset(w * 0.08, h * 0.08), 1.5, paint..style = PaintingStyle.fill);

    // Leaf accent
    path = Path();
    path.moveTo(w * 0.28, h * 0.28);
    path.quadraticBezierTo(w * 0.35, h * 0.22, w * 0.32, h * 0.32);
    path.quadraticBezierTo(w * 0.22, h * 0.35, w * 0.28, h * 0.28);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.0;
    canvas.drawPath(path, paint);
  }

  void _paintMinimalistCorner(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;

    // Clean geometric corner with precise lines
    paint.strokeWidth = 1.0;

    // L-shaped frame
    canvas.drawLine(Offset(0, h * 0.4), Offset(w * 0.4, h * 0.4), paint);
    canvas.drawLine(Offset(w * 0.4, 0), Offset(w * 0.4, h * 0.4), paint);

    // Inner accent line
    paint.color = paint.color.withValues(alpha: 0.2);
    canvas.drawLine(Offset(0, h * 0.25), Offset(w * 0.25, h * 0.25), paint);
    canvas.drawLine(Offset(w * 0.25, 0), Offset(w * 0.25, h * 0.25), paint);

    // Small square accent
    paint.color = color.withValues(alpha: 0.35);
    paint.style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.08, h * 0.08),
      paint,
    );
  }

  void _paintPixelCorner(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final px = w / 12; // Pixel size

    paint.style = PaintingStyle.fill;

    // Retro pixel art corner bracket pattern
    // Outer pixels
    canvas.drawRect(Rect.fromLTWH(0, 0, px, px * 5), paint);
    canvas.drawRect(Rect.fromLTWH(0, 0, px * 5, px), paint);

    // Inner detail pixels
    paint.color = color.withValues(alpha: 0.25);
    canvas.drawRect(Rect.fromLTWH(px * 2, px * 2, px, px), paint);
    canvas.drawRect(Rect.fromLTWH(px, px * 3, px, px), paint);
    canvas.drawRect(Rect.fromLTWH(px * 3, px, px, px), paint);

    // Highlight pixel
    paint.color = color.withValues(alpha: 0.5);
    canvas.drawRect(Rect.fromLTWH(px, px, px, px), paint);

    // Secondary bracket (smaller)
    paint.color = color.withValues(alpha: 0.2);
    canvas.drawRect(Rect.fromLTWH(px * 6, 0, px, px * 3), paint);
    canvas.drawRect(Rect.fromLTWH(0, px * 6, px * 3, px), paint);
  }

  @override
  bool shouldRepaint(covariant CornerOrnamentPainter oldDelegate) =>
      color != oldDelegate.color || theme != oldDelegate.theme;
}

// =============================================================================
// HELPER FUNCTION TO GET PAINTERS
// =============================================================================

/// Get the appropriate flat stone painter for a piece style
CustomPainter getFlatPainter({
  required PieceStyle style,
  required PieceColors colors,
  required bool isLightPlayer,
}) {
  switch (style) {
    case PieceStyle.standard:
      return StandardFlatPainter(colors: colors, isLightPlayer: isLightPlayer);
    case PieceStyle.stone:
      return StoneFlatPainter(colors: colors, isLightPlayer: isLightPlayer);
    case PieceStyle.polishedMarble:
      return MarbleFlatPainter(colors: colors, isLightPlayer: isLightPlayer);
    case PieceStyle.minimalist:
      return MinimalistFlatPainter(colors: colors, isLightPlayer: isLightPlayer);
    case PieceStyle.pixel:
      return PixelFlatPainter(colors: colors, isLightPlayer: isLightPlayer);
  }
}

/// Get the appropriate wall painter for a piece style
CustomPainter getWallPainter({
  required PieceStyle style,
  required PieceColors colors,
}) {
  switch (style) {
    case PieceStyle.standard:
      return StandardWallPainter(colors: colors);
    case PieceStyle.stone:
      return StoneWallPainter(colors: colors);
    case PieceStyle.polishedMarble:
      return MarbleWallPainter(colors: colors);
    case PieceStyle.minimalist:
      return MinimalistWallPainter(colors: colors);
    case PieceStyle.pixel:
      return PixelWallPainter(colors: colors);
  }
}

/// Get the appropriate capstone painter for a piece style
CustomPainter getCapstonePainter({
  required PieceStyle style,
  required PieceColors colors,
}) {
  switch (style) {
    case PieceStyle.standard:
      return StandardCapstonePainter(colors: colors);
    case PieceStyle.stone:
      return StoneCapstonePainter(colors: colors);
    case PieceStyle.polishedMarble:
      return MarbleCapstonePainter(colors: colors);
    case PieceStyle.minimalist:
      return MinimalistCapstonePainter(colors: colors);
    case PieceStyle.pixel:
      return PixelCapstonePainter(colors: colors);
  }
}

/// Get the appropriate board texture painter for a theme
CustomPainter getBoardTexturePainter({
  required BoardThemeData theme,
  int seed = 42,
}) {
  switch (theme.theme) {
    case BoardTheme.classicWood:
      return WoodGrainPainter(
        baseColor: theme.cellBackground,
        grainColor: theme.gridLine,
        knotColor: theme.gridLineShadow,
        seed: seed,
      );
    case BoardTheme.darkStone:
      return StoneTexturePainter(
        baseColor: theme.cellBackground,
        highlightColor: theme.cellBackgroundLight,
        shadowColor: theme.gridLineShadow,
        seed: seed,
      );
    case BoardTheme.marble:
      return MarbleTexturePainter(
        baseColor: theme.cellBackground,
        veinColor: theme.gridLine,
        accentColor: theme.gridLineShadow,
        seed: seed,
      );
    case BoardTheme.minimalist:
      return MinimalistPatternPainter(
        baseColor: theme.cellBackground,
        lineColor: theme.gridLine,
      );
    case BoardTheme.pixelArt:
      return PixelArtPatternPainter(
        baseColor: theme.cellBackground,
        color1: theme.cellBackgroundLight,
        color2: theme.cellBackgroundDark,
        seed: seed,
      );
  }
}

// =============================================================================
// BOARD DECORATION OVERLAY PAINTER
// =============================================================================

/// Paints decorative elements at grid intersections and edges
/// This creates the beautiful filigree and ornamental details between squares
class BoardDecorationPainter extends CustomPainter {
  final int boardSize;
  final double spacing;
  final double padding;
  final double cellSize;
  final BoardTheme theme;
  final Color decorColor;

  BoardDecorationPainter({
    required this.boardSize,
    required this.spacing,
    required this.padding,
    required this.cellSize,
    required this.theme,
    required this.decorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Skip if size is zero (no constraints)
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = decorColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = decorColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Calculate coordinates for grid intersections
    // The grid cells start at (padding, padding) with spacing between them
    // Corners and edges are at the actual cell boundaries
    // Interior intersections are in the center of the gaps between cells

    for (var row = 0; row <= boardSize; row++) {
      for (var col = 0; col <= boardSize; col++) {
        // Calculate position - different for edges vs interior
        final isRowEdge = row == 0 || row == boardSize;
        final isColEdge = col == 0 || col == boardSize;
        final isCorner = isRowEdge && isColEdge;
        final isEdge = isRowEdge || isColEdge;
        final isInterior = !isEdge;

        double x, y;

        if (col == 0) {
          // Left edge of grid
          x = padding;
        } else if (col == boardSize) {
          // Right edge of grid
          x = padding + (boardSize - 1) * (cellSize + spacing) + cellSize;
        } else {
          // Interior: center of gap between columns
          x = padding + col * (cellSize + spacing) - spacing / 2;
        }

        if (row == 0) {
          // Top edge of grid
          y = padding;
        } else if (row == boardSize) {
          // Bottom edge of grid
          y = padding + (boardSize - 1) * (cellSize + spacing) + cellSize;
        } else {
          // Interior: center of gap between rows
          y = padding + row * (cellSize + spacing) - spacing / 2;
        }

        if (isCorner) {
          _paintCornerDecoration(canvas, x, y, row, col, paint, fillPaint);
        } else if (isInterior) {
          _paintIntersectionDecoration(canvas, x, y, paint, fillPaint);
        } else if (isEdge) {
          _paintEdgeDecoration(canvas, x, y, row, col, paint, fillPaint);
        }
      }
    }

    // Draw border decorations along edges
    _paintBorderDecorations(canvas, size, paint);
  }

  void _paintCornerDecoration(Canvas canvas, double x, double y, int row, int col, Paint paint, Paint fillPaint) {
    // Use cellSize-based sizing for substantial corner ornaments
    final ornamentSize = cellSize * 0.35;

    canvas.save();
    canvas.translate(x, y);

    // Rotate based on which corner
    if (row == 0 && col == boardSize) {
      canvas.rotate(math.pi / 2);
    } else if (row == boardSize && col == boardSize) {
      canvas.rotate(math.pi);
    } else if (row == boardSize && col == 0) {
      canvas.rotate(-math.pi / 2);
    }

    switch (theme) {
      case BoardTheme.classicWood:
        _paintWoodCornerOrnament(canvas, ornamentSize, paint, fillPaint);
      case BoardTheme.darkStone:
        _paintStoneCornerOrnament(canvas, ornamentSize, paint, fillPaint);
      case BoardTheme.marble:
        _paintMarbleCornerOrnament(canvas, ornamentSize, paint, fillPaint);
      case BoardTheme.minimalist:
        _paintMinimalistCornerOrnament(canvas, ornamentSize, paint);
      case BoardTheme.pixelArt:
        _paintPixelCornerOrnament(canvas, ornamentSize, paint, fillPaint);
    }

    canvas.restore();
  }

  void _paintIntersectionDecoration(Canvas canvas, double x, double y, Paint paint, Paint fillPaint) {
    // Size based on spacing for interior decorations
    final size = spacing * 1.0;

    switch (theme) {
      case BoardTheme.classicWood:
        // Elegant fleur-de-lis inspired crosshatch
        final thinPaint = Paint()
          ..color = paint.color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

        // Main cross with tapered ends
        canvas.drawLine(Offset(x - size, y), Offset(x + size, y), thinPaint);
        canvas.drawLine(Offset(x, y - size), Offset(x, y + size), thinPaint);

        // Decorative diamond center
        final d = size * 0.4;
        final path = Path();
        path.moveTo(x, y - d);
        path.lineTo(x + d, y);
        path.lineTo(x, y + d);
        path.lineTo(x - d, y);
        path.close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, thinPaint);

      case BoardTheme.darkStone:
        // Runic intersection symbol
        final s = size * 0.8;
        // Diamond shape
        final path = Path();
        path.moveTo(x, y - s);
        path.lineTo(x + s * 0.6, y);
        path.lineTo(x, y + s);
        path.lineTo(x - s * 0.6, y);
        path.close();
        canvas.drawPath(path, paint);

        // Inner cross detail
        final innerPaint = Paint()
          ..color = paint.color.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(x - s * 0.3, y), Offset(x + s * 0.3, y), innerPaint);
        canvas.drawLine(Offset(x, y - s * 0.3), Offset(x, y + s * 0.3), innerPaint);

      case BoardTheme.marble:
        // Classical quatrefoil rosette
        final r = size * 0.5;
        for (var i = 0; i < 4; i++) {
          final angle = i * math.pi / 2 + math.pi / 4;
          final px = x + math.cos(angle) * r * 0.7;
          final py = y + math.sin(angle) * r * 0.7;

          // Petal shape
          final petalPath = Path();
          petalPath.addOval(Rect.fromCenter(
            center: Offset(px, py),
            width: r * 0.5,
            height: r * 0.35,
          ));
          canvas.drawPath(petalPath, paint);
        }
        // Center dot
        canvas.drawCircle(Offset(x, y), size * 0.15, fillPaint);

      case BoardTheme.minimalist:
        // Subtle plus with center dot
        final thinPaint = Paint()
          ..color = paint.color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
        final s = size * 0.6;
        canvas.drawLine(Offset(x - s, y), Offset(x + s, y), thinPaint);
        canvas.drawLine(Offset(x, y - s), Offset(x, y + s), thinPaint);
        canvas.drawCircle(Offset(x, y), size * 0.2,
          Paint()..color = paint.color.withValues(alpha: 0.35)..style = PaintingStyle.fill);

      case BoardTheme.pixelArt:
        // Pixel cross pattern
        final px = spacing * 0.25;
        // Center pixel
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: px * 2, height: px * 2),
          fillPaint,
        );
        // Cross arms
        final armPaint = Paint()..color = paint.color.withValues(alpha: 0.4);
        canvas.drawRect(Rect.fromLTWH(x - px * 2, y - px / 2, px, px), armPaint);
        canvas.drawRect(Rect.fromLTWH(x + px, y - px / 2, px, px), armPaint);
        canvas.drawRect(Rect.fromLTWH(x - px / 2, y - px * 2, px, px), armPaint);
        canvas.drawRect(Rect.fromLTWH(x - px / 2, y + px, px, px), armPaint);
    }
  }

  void _paintEdgeDecoration(Canvas canvas, double x, double y, int row, int col, Paint paint, Paint fillPaint) {
    // Edge decorations along the border
    final size = spacing * 0.9;
    final isTop = row == 0;
    final isBottom = row == boardSize;
    final isLeft = col == 0;

    switch (theme) {
      case BoardTheme.classicWood:
        // Decorative serif/bracket motif
        final thinPaint = Paint()
          ..color = paint.color.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;

        if (isTop || isBottom) {
          // Horizontal edge - vertical tick with small curls
          final dir = isTop ? 1.0 : -1.0;
          canvas.drawLine(Offset(x, y), Offset(x, y + size * 0.8 * dir), thinPaint);
          // Small curl accents
          canvas.drawLine(Offset(x - size * 0.3, y + size * 0.5 * dir),
              Offset(x, y + size * 0.8 * dir), thinPaint);
          canvas.drawLine(Offset(x + size * 0.3, y + size * 0.5 * dir),
              Offset(x, y + size * 0.8 * dir), thinPaint);
        } else {
          // Vertical edge - horizontal tick with small curls
          final dir = isLeft ? 1.0 : -1.0;
          canvas.drawLine(Offset(x, y), Offset(x + size * 0.8 * dir, y), thinPaint);
          canvas.drawLine(Offset(x + size * 0.5 * dir, y - size * 0.3),
              Offset(x + size * 0.8 * dir, y), thinPaint);
          canvas.drawLine(Offset(x + size * 0.5 * dir, y + size * 0.3),
              Offset(x + size * 0.8 * dir, y), thinPaint);
        }

      case BoardTheme.darkStone:
        // Angular runic tick marks
        if (isTop || isBottom) {
          final dir = isTop ? 1.0 : -1.0;
          canvas.drawLine(Offset(x, y), Offset(x, y + size * dir), paint);
          canvas.drawLine(Offset(x - size * 0.4, y + size * 0.5 * dir),
              Offset(x + size * 0.4, y + size * 0.5 * dir), paint);
        } else {
          final dir = isLeft ? 1.0 : -1.0;
          canvas.drawLine(Offset(x, y), Offset(x + size * dir, y), paint);
          canvas.drawLine(Offset(x + size * 0.5 * dir, y - size * 0.4),
              Offset(x + size * 0.5 * dir, y + size * 0.4), paint);
        }

      case BoardTheme.marble:
        // Elegant beaded border with small flourish
        canvas.drawCircle(Offset(x, y), size * 0.25, fillPaint);
        canvas.drawCircle(Offset(x, y), size * 0.25, paint);

        // Small decorative curves on alternate positions
        if ((col + row) % 2 == 0) {
          final thinPaint = Paint()
            ..color = paint.color.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8;
          if (isTop || isBottom) {
            final dir = isTop ? 1.0 : -1.0;
            final path = Path();
            path.moveTo(x - size * 0.4, y + size * 0.2 * dir);
            path.quadraticBezierTo(x, y + size * 0.5 * dir, x + size * 0.4, y + size * 0.2 * dir);
            canvas.drawPath(path, thinPaint);
          } else {
            final dir = isLeft ? 1.0 : -1.0;
            final path = Path();
            path.moveTo(x + size * 0.2 * dir, y - size * 0.4);
            path.quadraticBezierTo(x + size * 0.5 * dir, y, x + size * 0.2 * dir, y + size * 0.4);
            canvas.drawPath(path, thinPaint);
          }
        }

      case BoardTheme.minimalist:
        // Subtle tick marks
        final subtlePaint = Paint()
          ..color = paint.color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
        if (isTop || isBottom) {
          final dir = isTop ? 1.0 : -1.0;
          canvas.drawLine(Offset(x, y), Offset(x, y + size * 0.5 * dir), subtlePaint);
        } else {
          final dir = isLeft ? 1.0 : -1.0;
          canvas.drawLine(Offset(x, y), Offset(x + size * 0.5 * dir, y), subtlePaint);
        }

      case BoardTheme.pixelArt:
        // Pixel bracket edge
        final px = spacing * 0.25;
        if (isTop || isBottom) {
          final dir = isTop ? 1.0 : -1.0;
          canvas.drawRect(Rect.fromLTWH(x - px, y, px * 2, px * 2 * dir), fillPaint);
        } else {
          final dir = isLeft ? 1.0 : -1.0;
          canvas.drawRect(Rect.fromLTWH(x, y - px, px * 2 * dir, px * 2), fillPaint);
        }
    }
  }

  void _paintBorderDecorations(Canvas canvas, Size canvasSize, Paint paint) {
    // Additional decorative elements along the outer frame based on theme
    final boardWidth = canvasSize.width;
    final boardHeight = canvasSize.height;

    switch (theme) {
      case BoardTheme.classicWood:
        // Elegant double-line frame effect
        final framePaint = Paint()
          ..color = decorColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

        // Outer frame line
        final outerInset = padding * 0.15;
        canvas.drawRect(
          Rect.fromLTWH(outerInset, outerInset,
              boardWidth - outerInset * 2, boardHeight - outerInset * 2),
          framePaint,
        );

        // Inner frame accent
        final innerPaint = Paint()
          ..color = decorColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6;
        final innerInset = padding * 0.4;
        canvas.drawRect(
          Rect.fromLTWH(innerInset, innerInset,
              boardWidth - innerInset * 2, boardHeight - innerInset * 2),
          innerPaint,
        );

      case BoardTheme.darkStone:
        // Runic border pattern
        final runePaint = Paint()
          ..color = decorColor.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.square;

        // Angular corner brackets on outer edge
        final bracketSize = padding * 0.8;
        final inset = padding * 0.2;

        // Top-left bracket
        canvas.drawLine(Offset(inset, bracketSize), Offset(inset, inset), runePaint);
        canvas.drawLine(Offset(inset, inset), Offset(bracketSize, inset), runePaint);

        // Top-right bracket
        canvas.drawLine(Offset(boardWidth - bracketSize, inset),
            Offset(boardWidth - inset, inset), runePaint);
        canvas.drawLine(Offset(boardWidth - inset, inset),
            Offset(boardWidth - inset, bracketSize), runePaint);

        // Bottom-left bracket
        canvas.drawLine(Offset(inset, boardHeight - bracketSize),
            Offset(inset, boardHeight - inset), runePaint);
        canvas.drawLine(Offset(inset, boardHeight - inset),
            Offset(bracketSize, boardHeight - inset), runePaint);

        // Bottom-right bracket
        canvas.drawLine(Offset(boardWidth - bracketSize, boardHeight - inset),
            Offset(boardWidth - inset, boardHeight - inset), runePaint);
        canvas.drawLine(Offset(boardWidth - inset, boardHeight - inset),
            Offset(boardWidth - inset, boardHeight - bracketSize), runePaint);

      case BoardTheme.marble:
        // Elegant beaded border with Greek key accent
        final beadPaint = Paint()
          ..color = decorColor.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;

        // Calculate bead positions based on board size
        final beadCount = (boardSize + 1) * 2;
        final hSpacing = (boardWidth - padding * 2) / beadCount;
        final vSpacing = (boardHeight - padding * 2) / beadCount;

        // Top and bottom beads
        for (var i = 1; i < beadCount; i++) {
          final bx = padding + i * hSpacing;
          canvas.drawCircle(Offset(bx, padding * 0.3), 1.2, beadPaint);
          canvas.drawCircle(Offset(bx, boardHeight - padding * 0.3), 1.2, beadPaint);
        }

        // Left and right beads
        for (var i = 1; i < beadCount; i++) {
          final by = padding + i * vSpacing;
          canvas.drawCircle(Offset(padding * 0.3, by), 1.2, beadPaint);
          canvas.drawCircle(Offset(boardWidth - padding * 0.3, by), 1.2, beadPaint);
        }

      case BoardTheme.pixelArt:
        // Pixel art dashed border
        final pixelPaint = Paint()
          ..color = decorColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill;

        final px = spacing * 0.3;
        final dashCount = (boardWidth / (px * 4)).floor();

        for (var i = 0; i < dashCount; i++) {
          if (i % 2 == 0) {
            final dx = i * px * 4 + px;
            // Top edge
            canvas.drawRect(Rect.fromLTWH(dx, px * 0.5, px * 2, px), pixelPaint);
            // Bottom edge
            canvas.drawRect(Rect.fromLTWH(dx, boardHeight - px * 1.5, px * 2, px), pixelPaint);
          }
        }

        final vDashCount = (boardHeight / (px * 4)).floor();
        for (var i = 0; i < vDashCount; i++) {
          if (i % 2 == 0) {
            final dy = i * px * 4 + px;
            // Left edge
            canvas.drawRect(Rect.fromLTWH(px * 0.5, dy, px, px * 2), pixelPaint);
            // Right edge
            canvas.drawRect(Rect.fromLTWH(boardWidth - px * 1.5, dy, px, px * 2), pixelPaint);
          }
        }

      case BoardTheme.minimalist:
        // Clean subtle border line
        final subtlePaint = Paint()
          ..color = decorColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5;

        final inset = padding * 0.25;
        canvas.drawRect(
          Rect.fromLTWH(inset, inset,
              boardWidth - inset * 2, boardHeight - inset * 2),
          subtlePaint,
        );
    }
  }

  // Theme-specific corner ornaments
  void _paintWoodCornerOrnament(Canvas canvas, double size, Paint paint, Paint fillPaint) {
    // Elegant scrollwork filigree corner
    var path = Path();

    // Outer flourish curve
    path.moveTo(0, size);
    path.cubicTo(size * 0.2, size * 0.9, size * 0.9, size * 0.2, size, 0);
    canvas.drawPath(path, paint);

    // Inner parallel curve
    path = Path();
    path.moveTo(0, size * 0.7);
    path.cubicTo(size * 0.15, size * 0.65, size * 0.65, size * 0.15, size * 0.7, 0);
    canvas.drawPath(path, paint);

    // Decorative scroll spiral
    path = Path();
    path.moveTo(size * 0.25, size * 0.25);
    path.cubicTo(size * 0.35, size * 0.15, size * 0.45, size * 0.2, size * 0.4, size * 0.3);
    path.cubicTo(size * 0.35, size * 0.4, size * 0.25, size * 0.35, size * 0.28, size * 0.28);
    canvas.drawPath(path, paint);

    // Acorn/leaf accent
    path = Path();
    path.moveTo(size * 0.12, size * 0.5);
    path.quadraticBezierTo(size * 0.2, size * 0.35, size * 0.15, size * 0.25);
    canvas.drawPath(path, paint);

    path = Path();
    path.moveTo(size * 0.5, size * 0.12);
    path.quadraticBezierTo(size * 0.35, size * 0.2, size * 0.25, size * 0.15);
    canvas.drawPath(path, paint);

    // Central decorative dot
    canvas.drawCircle(Offset(size * 0.2, size * 0.2), size * 0.06, fillPaint);
    canvas.drawCircle(Offset(size * 0.2, size * 0.2), size * 0.03, paint);
  }

  void _paintStoneCornerOrnament(Canvas canvas, double size, Paint paint, Paint fillPaint) {
    // Bold angular runic corner with Norse-inspired design
    final thickPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = paint.strokeWidth * 1.3
      ..strokeCap = StrokeCap.square;

    // Outer angular bracket
    var path = Path();
    path.moveTo(0, size * 0.85);
    path.lineTo(size * 0.15, size * 0.5);
    path.lineTo(size * 0.5, size * 0.15);
    path.lineTo(size * 0.85, 0);
    canvas.drawPath(path, thickPaint);

    // Inner parallel line
    path = Path();
    path.moveTo(0, size * 0.55);
    path.lineTo(size * 0.25, size * 0.25);
    path.lineTo(size * 0.55, 0);
    canvas.drawPath(path, paint);

    // Runic symbol (bindrune style)
    canvas.drawLine(Offset(size * 0.18, size * 0.35), Offset(size * 0.22, size * 0.15), paint);
    canvas.drawLine(Offset(size * 0.35, size * 0.18), Offset(size * 0.15, size * 0.22), paint);
    canvas.drawLine(Offset(size * 0.15, size * 0.28), Offset(size * 0.28, size * 0.15), paint);

    // Corner accent diamonds
    final diamondPath = Path();
    final d = size * 0.05;
    final cx = size * 0.32;
    final cy = size * 0.32;
    diamondPath.moveTo(cx, cy - d);
    diamondPath.lineTo(cx + d, cy);
    diamondPath.lineTo(cx, cy + d);
    diamondPath.lineTo(cx - d, cy);
    diamondPath.close();
    canvas.drawPath(diamondPath, fillPaint);
  }

  void _paintMarbleCornerOrnament(Canvas canvas, double size, Paint paint, Paint fillPaint) {
    // Classical Greek/Roman acanthus-inspired corner
    var path = Path();

    // Outer elegant curve
    path.moveTo(0, size);
    path.cubicTo(size * 0.15, size * 0.85, size * 0.85, size * 0.15, size, 0);
    canvas.drawPath(path, paint);

    // Inner curve with flourish
    path = Path();
    path.moveTo(0, size * 0.65);
    path.cubicTo(size * 0.1, size * 0.6, size * 0.6, size * 0.1, size * 0.65, 0);
    canvas.drawPath(path, paint);

    // Acanthus leaf scroll
    path = Path();
    path.moveTo(size * 0.15, size * 0.4);
    path.cubicTo(size * 0.25, size * 0.25, size * 0.35, size * 0.3, size * 0.3, size * 0.4);
    path.cubicTo(size * 0.28, size * 0.45, size * 0.2, size * 0.42, size * 0.22, size * 0.35);
    canvas.drawPath(path, paint);

    path = Path();
    path.moveTo(size * 0.4, size * 0.15);
    path.cubicTo(size * 0.25, size * 0.25, size * 0.3, size * 0.35, size * 0.4, size * 0.3);
    path.cubicTo(size * 0.45, size * 0.28, size * 0.42, size * 0.2, size * 0.35, size * 0.22);
    canvas.drawPath(path, paint);

    // Central rosette
    final cx = size * 0.18;
    final cy = size * 0.18;
    final r = size * 0.08;
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final px = cx + math.cos(angle) * r;
      final py = cy + math.sin(angle) * r;
      canvas.drawCircle(Offset(px, py), size * 0.025, paint);
    }
    canvas.drawCircle(Offset(cx, cy), size * 0.04, fillPaint);
    canvas.drawCircle(Offset(cx, cy), size * 0.025, paint);

    // Small bead accents
    canvas.drawCircle(Offset(size * 0.08, size * 0.35), size * 0.02, fillPaint);
    canvas.drawCircle(Offset(size * 0.35, size * 0.08), size * 0.02, fillPaint);
  }

  void _paintMinimalistCornerOrnament(Canvas canvas, double size, Paint paint) {
    // Elegant minimal corner with subtle geometry
    final thinPaint = Paint()
      ..color = paint.color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Primary L bracket
    canvas.drawLine(Offset(0, size * 0.7), Offset(size * 0.25, size * 0.25), paint);
    canvas.drawLine(Offset(size * 0.25, size * 0.25), Offset(size * 0.7, 0), paint);

    // Subtle parallel accent
    canvas.drawLine(Offset(0, size * 0.45), Offset(size * 0.18, size * 0.18), thinPaint);
    canvas.drawLine(Offset(size * 0.18, size * 0.18), Offset(size * 0.45, 0), thinPaint);

    // Clean corner dot
    canvas.drawCircle(
      Offset(size * 0.15, size * 0.15),
      size * 0.04,
      Paint()..color = paint.color.withValues(alpha: 0.5)..style = PaintingStyle.fill,
    );
  }

  void _paintPixelCornerOrnament(Canvas canvas, double size, Paint paint, Paint fillPaint) {
    final px = size / 8;

    // Chunky pixel L-bracket
    canvas.drawRect(Rect.fromLTWH(0, 0, px * 2, px * 6), fillPaint);
    canvas.drawRect(Rect.fromLTWH(0, 0, px * 6, px * 2), fillPaint);

    // Stepped inner edge (creates pixelated corner feel)
    final midPaint = Paint()..color = paint.color.withValues(alpha: 0.4);
    canvas.drawRect(Rect.fromLTWH(px * 2, px * 2, px * 2, px * 2), midPaint);
    canvas.drawRect(Rect.fromLTWH(px * 4, px * 2, px, px), midPaint);
    canvas.drawRect(Rect.fromLTWH(px * 2, px * 4, px, px), midPaint);

    // Decorative pixel pattern
    final accentPaint = Paint()..color = paint.color.withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromLTWH(px * 3, px * 3, px, px), accentPaint);

    // Highlight pixels
    final highlightPaint = Paint()..color = paint.color;
    canvas.drawRect(Rect.fromLTWH(px * 0.5, px * 0.5, px, px), highlightPaint);
  }

  @override
  bool shouldRepaint(covariant BoardDecorationPainter oldDelegate) =>
      boardSize != oldDelegate.boardSize ||
      spacing != oldDelegate.spacing ||
      theme != oldDelegate.theme ||
      decorColor != oldDelegate.decorColor;
}

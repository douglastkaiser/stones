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
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(h * 0.5),
    );

    // Shadow
    canvas.drawRRect(
      rect.shift(const Offset(2, 2)),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Main body
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [colors.primary, colors.secondary],
    );

    canvas.drawRRect(
      rect,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Border
    canvas.drawRRect(
      rect,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Highlight arc
    canvas.drawArc(
      Rect.fromLTWH(w * 0.15, 2, w * 0.7, h * 0.5),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
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

/// Polished marble flat - smooth oval with shine
class MarbleFlatPainter extends CustomPainter {
  final PieceColors colors;
  final bool isLightPlayer;

  MarbleFlatPainter({required this.colors, required this.isLightPlayer});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    // Shadow
    canvas.drawOval(
      rect.shift(const Offset(2, 3)),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Main body - smooth oval
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 1.0,
      colors: [
        Color.lerp(colors.primary, Colors.white, 0.2)!,
        colors.primary,
        colors.secondary,
      ],
      stops: const [0.0, 0.4, 1.0],
    );

    canvas.drawOval(rect, Paint()..shader = gradient.createShader(rect));

    // Subtle border
    canvas.drawOval(
      rect,
      Paint()
        ..color = colors.border.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Polished shine highlight
    final shinePath = Path();
    shinePath.addOval(Rect.fromLTWH(w * 0.15, h * 0.1, w * 0.4, h * 0.3));

    canvas.drawPath(
      shinePath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.6),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(w * 0.15, h * 0.1, w * 0.4, h * 0.3)),
    );
  }

  @override
  bool shouldRepaint(covariant MarbleFlatPainter oldDelegate) =>
      colors != oldDelegate.colors;
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
// PIECE PAINTERS - HAND CARVED STYLE
// =============================================================================

/// Hand carved flat - irregular rough edges
class CarvedFlatPainter extends CustomPainter {
  final PieceColors colors;
  final bool isLightPlayer;
  final int seed;

  CarvedFlatPainter({
    required this.colors,
    required this.isLightPlayer,
    this.seed = 42,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final random = SeededRandom(seed);

    // Create irregular polygon
    final path = Path();
    final points = <Offset>[];
    const numPoints = 8;

    for (var i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi - math.pi / 2;
      final radiusX = w * 0.4 + random.range(-w * 0.08, w * 0.08);
      final radiusY = h * 0.4 + random.range(-h * 0.08, h * 0.08);
      points.add(Offset(
        w / 2 + math.cos(angle) * radiusX,
        h / 2 + math.sin(angle) * radiusY,
      ));
    }

    path.moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      // Slightly wavy lines between points
      final prev = points[i - 1];
      final curr = points[i];
      final mid = Offset(
        (prev.dx + curr.dx) / 2 + random.range(-3, 3),
        (prev.dy + curr.dy) / 2 + random.range(-3, 3),
      );
      path.quadraticBezierTo(mid.dx, mid.dy, curr.dx, curr.dy);
    }
    path.close();

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(2, 2)),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Wood grain effect
    final grainGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colors.primary,
        Color.lerp(colors.primary, colors.secondary, 0.3)!,
        colors.primary,
        colors.secondary,
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    );

    canvas.drawPath(
      path,
      Paint()..shader = grainGradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Carved texture lines
    final linePaint = Paint()
      ..color = colors.border.withValues(alpha: 0.2)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 5; i++) {
      final y = h * 0.2 + i * h * 0.15;
      canvas.drawLine(
        Offset(w * 0.2 + random.range(0, 5), y + random.range(-2, 2)),
        Offset(w * 0.8 + random.range(-5, 0), y + random.range(-2, 2)),
        linePaint,
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
  }

  @override
  bool shouldRepaint(covariant CarvedFlatPainter oldDelegate) =>
      colors != oldDelegate.colors || seed != oldDelegate.seed;
}

/// Hand carved wall - rough hewn look
class CarvedWallPainter extends CustomPainter {
  final PieceColors colors;
  final int seed;

  CarvedWallPainter({required this.colors, this.seed = 42});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final random = SeededRandom(seed);
    final thickness = w * 0.28;

    // Create irregular wall shape
    final path = Path();
    path.moveTo(w * 0.12 + random.range(-3, 3), h);
    path.lineTo(w * 0.12 + thickness + random.range(-3, 3), h - random.range(0, 3));

    // Irregular top edge
    final topY = random.range(0, 4);
    path.lineTo(w * 0.88 + random.range(-3, 3), topY);
    path.lineTo(w * 0.88 - thickness + random.range(-3, 3), topY + random.range(0, 3));
    path.close();

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(2, 2)),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Main body with wood grain
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [colors.primary, colors.secondary, colors.primary],
      stops: const [0.0, 0.5, 1.0],
    );

    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Carving marks
    final markPaint = Paint()
      ..color = colors.border.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 4; i++) {
      final startX = w * 0.3 + random.range(0, w * 0.1);
      final startY = h * 0.2 + i * h * 0.2;
      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX + w * 0.3 + random.range(-10, 10), startY + random.range(-5, 5)),
        markPaint,
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
  }

  @override
  bool shouldRepaint(covariant CarvedWallPainter oldDelegate) =>
      colors != oldDelegate.colors || seed != oldDelegate.seed;
}

/// Hand carved capstone - rough dome with chisel marks
class CarvedCapstonePainter extends CustomPainter {
  final PieceColors colors;
  final int seed;

  CarvedCapstonePainter({required this.colors, this.seed = 42});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final random = SeededRandom(seed);
    final centerX = w / 2;

    // Create irregular dome shape
    final path = Path();
    path.moveTo(w * 0.1, h * 0.9);

    // Irregular dome curve with slight bumps
    final points = <Offset>[];
    for (var i = 0; i <= 10; i++) {
      final t = i / 10;
      final x = w * 0.1 + t * w * 0.8;
      final baseY = h * 0.9 - math.sin(t * math.pi) * h * 0.75;
      final y = baseY + random.range(-3, 3);
      points.add(Offset(x, y));
    }

    for (var i = 0; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2 + random.range(-2, 2),
      );
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    path.lineTo(w * 0.9, h * 0.9);
    path.close();

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(2, 3)),
      Paint()..color = colors.border.withValues(alpha: 0.3),
    );

    // Main body
    final gradient = RadialGradient(
      center: const Alignment(-0.2, -0.3),
      radius: 1.0,
      colors: [colors.primary, colors.secondary],
    );

    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Chisel marks
    final chiselPaint = Paint()
      ..color = colors.border.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 6; i++) {
      final angle = random.range(-0.5, 0.5);
      final startX = centerX + random.range(-w * 0.25, w * 0.25);
      final startY = h * 0.3 + random.range(0, h * 0.4);
      canvas.save();
      canvas.translate(startX, startY);
      canvas.rotate(angle);
      canvas.drawLine(
        const Offset(-5, 0),
        Offset(5 + random.range(0, 8), 0),
        chiselPaint,
      );
      canvas.restore();
    }

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CarvedCapstonePainter oldDelegate) =>
      colors != oldDelegate.colors || seed != oldDelegate.seed;
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
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    switch (theme) {
      case BoardTheme.classicWood:
        _paintWoodCorner(canvas, size, paint);
        break;
      case BoardTheme.darkStone:
        _paintStoneCorner(canvas, size, paint);
        break;
      case BoardTheme.marble:
        _paintMarbleCorner(canvas, size, paint);
        break;
      case BoardTheme.minimalist:
        _paintMinimalistCorner(canvas, size, paint);
        break;
      case BoardTheme.pixelArt:
        _paintPixelCorner(canvas, size, paint);
        break;
    }
  }

  void _paintWoodCorner(Canvas canvas, Size size, Paint paint) {
    // Celtic knot style corner
    final path = Path();
    path.moveTo(0, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.3, size.height * 0.3, size.width * 0.3, 0);
    canvas.drawPath(path, paint);

    path.reset();
    path.moveTo(0, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.5, size.height * 0.5, size.width * 0.5, 0);
    canvas.drawPath(path, paint);
  }

  void _paintStoneCorner(Canvas canvas, Size size, Paint paint) {
    // Runic style corner marks
    canvas.drawLine(Offset(0, size.height * 0.2), Offset(size.width * 0.2, 0), paint);
    canvas.drawLine(Offset(0, size.height * 0.4), Offset(size.width * 0.4, 0), paint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.15), 2, paint..style = PaintingStyle.fill);
  }

  void _paintMarbleCorner(Canvas canvas, Size size, Paint paint) {
    // Elegant scroll
    final path = Path();
    path.moveTo(0, size.height * 0.4);
    path.cubicTo(
      size.width * 0.2, size.height * 0.4,
      size.width * 0.4, size.height * 0.2,
      size.width * 0.4, 0,
    );
    canvas.drawPath(path, paint);

    // Small flourish
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.1), 3, paint..style = PaintingStyle.stroke);
  }

  void _paintMinimalistCorner(Canvas canvas, Size size, Paint paint) {
    // Simple geometric
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width * 0.3, size.height * 0.3), paint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.3, size.height * 0.3), paint);
  }

  void _paintPixelCorner(Canvas canvas, Size size, Paint paint) {
    // Pixel art corner
    paint.style = PaintingStyle.fill;
    const px = 3.0;
    canvas.drawRect(const Rect.fromLTWH(0, 0, px, px * 3), paint);
    canvas.drawRect(const Rect.fromLTWH(0, 0, px * 3, px), paint);
    canvas.drawRect(const Rect.fromLTWH(px, px, px, px), paint);
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
  int seed = 42,
}) {
  switch (style) {
    case PieceStyle.standard:
      return StandardFlatPainter(colors: colors, isLightPlayer: isLightPlayer);
    case PieceStyle.polishedMarble:
      return MarbleFlatPainter(colors: colors, isLightPlayer: isLightPlayer);
    case PieceStyle.handCarved:
      return CarvedFlatPainter(colors: colors, isLightPlayer: isLightPlayer, seed: seed);
  }
}

/// Get the appropriate wall painter for a piece style
CustomPainter getWallPainter({
  required PieceStyle style,
  required PieceColors colors,
  int seed = 42,
}) {
  switch (style) {
    case PieceStyle.standard:
      return StandardWallPainter(colors: colors);
    case PieceStyle.polishedMarble:
      return MarbleWallPainter(colors: colors);
    case PieceStyle.handCarved:
      return CarvedWallPainter(colors: colors, seed: seed);
  }
}

/// Get the appropriate capstone painter for a piece style
CustomPainter getCapstonePainter({
  required PieceStyle style,
  required PieceColors colors,
  int seed = 42,
}) {
  switch (style) {
    case PieceStyle.standard:
      return StandardCapstonePainter(colors: colors);
    case PieceStyle.polishedMarble:
      return MarbleCapstonePainter(colors: colors);
    case PieceStyle.handCarved:
      return CarvedCapstonePainter(colors: colors, seed: seed);
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

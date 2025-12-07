// Dart script to generate app icon and splash screen assets
// Run with: dart run tool/generate_assets.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

// Simple PNG encoder for generating app icons
// Creates a minimal abstract stone/path design

void main() async {
  print('Generating app assets...');

  // Generate main app icon (1024x1024)
  await generateAppIcon('assets/icon/app_icon.png', 1024);

  // Generate adaptive icon foreground (1024x1024 with padding)
  await generateAdaptiveIconForeground('assets/icon/app_icon_foreground.png', 1024);

  // Generate splash logo (512x512)
  await generateSplashLogo('assets/splash/splash_logo.png', 512);

  print('Assets generated successfully!');
}

Future<void> generateAppIcon(String path, int size) async {
  final pixels = Uint8List(size * size * 4);

  // Background: warm brown (#795548 = RGB 121, 85, 72)
  const bgR = 121, bgG = 85, bgB = 72;

  // Stone colors
  const creamR = 245, creamG = 235, creamB = 220; // Cream stone
  const charcoalR = 60, charcoalG = 55, charcoalB = 50; // Charcoal stone

  // Fill background
  for (var i = 0; i < size * size; i++) {
    pixels[i * 4] = bgR;
    pixels[i * 4 + 1] = bgG;
    pixels[i * 4 + 2] = bgB;
    pixels[i * 4 + 3] = 255;
  }

  final center = size / 2;
  final stoneSize = size * 0.18;
  final spacing = size * 0.15;

  // Draw a path of stones - diagonal arrangement suggesting a road
  // This creates an abstract representation of the game concept
  final stones = [
    // Cream stones (forming a path from bottom-left to top-right)
    (center - spacing * 1.5, center + spacing * 1.2, creamR, creamG, creamB, false), // bottom-left
    (center - spacing * 0.3, center + spacing * 0.4, creamR, creamG, creamB, false),
    (center + spacing * 0.9, center - spacing * 0.4, creamR, creamG, creamB, false),
    (center + spacing * 2.0, center - spacing * 1.2, creamR, creamG, creamB, false), // top-right

    // Charcoal stones (perpendicular, suggesting blocking/tension)
    (center - spacing * 0.5, center - spacing * 0.8, charcoalR, charcoalG, charcoalB, true), // standing
    (center + spacing * 1.3, center + spacing * 0.6, charcoalR, charcoalG, charcoalB, false),
  ];

  for (final stone in stones) {
    final (x, y, r, g, b, isStanding) = stone;
    drawRoundedStone(pixels, size, x, y, stoneSize, r, g, b, isStanding);
  }

  await savePng(path, pixels, size, size);
  print('  Created: $path');
}

Future<void> generateAdaptiveIconForeground(String path, int size) async {
  final pixels = Uint8List(size * size * 4);

  // Transparent background for adaptive icon
  for (var i = 0; i < size * size; i++) {
    pixels[i * 4] = 0;
    pixels[i * 4 + 1] = 0;
    pixels[i * 4 + 2] = 0;
    pixels[i * 4 + 3] = 0;
  }

  // Stone colors
  const creamR = 245, creamG = 235, creamB = 220;
  const charcoalR = 60, charcoalG = 55, charcoalB = 50;

  final center = size / 2;
  // Smaller for adaptive icon safe zone (66% of icon is visible)
  final stoneSize = size * 0.12;
  final spacing = size * 0.10;

  // Central arrangement of stones
  final stones = [
    (center - spacing * 1.0, center + spacing * 0.8, creamR, creamG, creamB, false),
    (center + spacing * 0.2, center + spacing * 0.1, creamR, creamG, creamB, false),
    (center + spacing * 1.3, center - spacing * 0.7, creamR, creamG, creamB, false),
    (center - spacing * 0.3, center - spacing * 0.5, charcoalR, charcoalG, charcoalB, true),
    (center + spacing * 0.9, center + spacing * 0.5, charcoalR, charcoalG, charcoalB, false),
  ];

  for (final stone in stones) {
    final (x, y, r, g, b, isStanding) = stone;
    drawRoundedStone(pixels, size, x, y, stoneSize, r, g, b, isStanding);
  }

  await savePng(path, pixels, size, size);
  print('  Created: $path');
}

Future<void> generateSplashLogo(String path, int size) async {
  final pixels = Uint8List(size * size * 4);

  // Transparent background
  for (var i = 0; i < size * size; i++) {
    pixels[i * 4] = 0;
    pixels[i * 4 + 1] = 0;
    pixels[i * 4 + 2] = 0;
    pixels[i * 4 + 3] = 0;
  }

  // Stone colors
  const creamR = 245, creamG = 235, creamB = 220;
  const charcoalR = 60, charcoalG = 55, charcoalB = 50;

  final center = size / 2;
  final stoneSize = size * 0.15;
  final spacing = size * 0.12;

  // Simple centered arrangement
  final stones = [
    (center - spacing * 0.8, center + spacing * 0.5, creamR, creamG, creamB, false),
    (center + spacing * 0.4, center - spacing * 0.2, creamR, creamG, creamB, false),
    (center - spacing * 0.2, center - spacing * 0.6, charcoalR, charcoalG, charcoalB, true),
  ];

  for (final stone in stones) {
    final (x, y, r, g, b, isStanding) = stone;
    drawRoundedStone(pixels, size, x, y, stoneSize, r, g, b, isStanding);
  }

  await savePng(path, pixels, size, size);
  print('  Created: $path');
}

void drawRoundedStone(Uint8List pixels, int imgSize, double cx, double cy,
    double stoneSize, int r, int g, int b, bool isStanding) {

  final width = stoneSize;
  final height = isStanding ? stoneSize * 1.4 : stoneSize * 0.6;
  final radius = math.min(width, height) * 0.25;

  // Shadow offset
  const shadowOffset = 3.0;
  const shadowR = 40, shadowG = 30, shadowB = 25;

  // Draw shadow first
  for (var py = (cy - height / 2 + shadowOffset).toInt();
       py < (cy + height / 2 + shadowOffset).toInt(); py++) {
    for (var px = (cx - width / 2 + shadowOffset).toInt();
         px < (cx + width / 2 + shadowOffset).toInt(); px++) {
      if (px < 0 || px >= imgSize || py < 0 || py >= imgSize) continue;

      if (isInsideRoundedRect(px.toDouble(), py.toDouble(),
          cx + shadowOffset, cy + shadowOffset, width, height, radius)) {
        final idx = (py * imgSize + px) * 4;
        // Blend shadow
        pixels[idx] = ((pixels[idx] * 0.7) + (shadowR * 0.3)).toInt();
        pixels[idx + 1] = ((pixels[idx + 1] * 0.7) + (shadowG * 0.3)).toInt();
        pixels[idx + 2] = ((pixels[idx + 2] * 0.7) + (shadowB * 0.3)).toInt();
      }
    }
  }

  // Draw stone
  for (var py = (cy - height / 2).toInt(); py < (cy + height / 2).toInt(); py++) {
    for (var px = (cx - width / 2).toInt(); px < (cx + width / 2).toInt(); px++) {
      if (px < 0 || px >= imgSize || py < 0 || py >= imgSize) continue;

      if (isInsideRoundedRect(px.toDouble(), py.toDouble(), cx, cy, width, height, radius)) {
        final idx = (py * imgSize + px) * 4;

        // Add slight gradient for depth
        final dy = (py - (cy - height / 2)) / height;
        final lightFactor = 1.0 - dy * 0.15;

        pixels[idx] = (r * lightFactor).clamp(0, 255).toInt();
        pixels[idx + 1] = (g * lightFactor).clamp(0, 255).toInt();
        pixels[idx + 2] = (b * lightFactor).clamp(0, 255).toInt();
        pixels[idx + 3] = 255;
      }
    }
  }

  // Draw border
  final borderR = (r * 0.6).toInt();
  final borderG = (g * 0.6).toInt();
  final borderB = (b * 0.6).toInt();

  for (var py = (cy - height / 2 - 2).toInt(); py < (cy + height / 2 + 2).toInt(); py++) {
    for (var px = (cx - width / 2 - 2).toInt(); px < (cx + width / 2 + 2).toInt(); px++) {
      if (px < 0 || px >= imgSize || py < 0 || py >= imgSize) continue;

      final inside = isInsideRoundedRect(px.toDouble(), py.toDouble(), cx, cy, width, height, radius);
      final insideInner = isInsideRoundedRect(px.toDouble(), py.toDouble(), cx, cy,
          width - 3, height - 3, math.max(0, radius - 1.5));

      if (inside && !insideInner) {
        final idx = (py * imgSize + px) * 4;
        pixels[idx] = borderR;
        pixels[idx + 1] = borderG;
        pixels[idx + 2] = borderB;
        pixels[idx + 3] = 255;
      }
    }
  }
}

bool isInsideRoundedRect(double px, double py, double cx, double cy,
    double width, double height, double radius) {

  final left = cx - width / 2;
  final right = cx + width / 2;
  final top = cy - height / 2;
  final bottom = cy + height / 2;

  // Check if inside the main rectangle (excluding corners)
  if (px >= left + radius && px <= right - radius && py >= top && py <= bottom) {
    return true;
  }
  if (px >= left && px <= right && py >= top + radius && py <= bottom - radius) {
    return true;
  }

  // Check corners
  final corners = [
    (left + radius, top + radius),
    (right - radius, top + radius),
    (left + radius, bottom - radius),
    (right - radius, bottom - radius),
  ];

  for (final (cornerX, cornerY) in corners) {
    final dx = px - cornerX;
    final dy = py - cornerY;
    if (dx * dx + dy * dy <= radius * radius) {
      // Check if this is the right quadrant
      if ((px < left + radius || px > right - radius) &&
          (py < top + radius || py > bottom - radius)) {
        return true;
      }
    }
  }

  return false;
}

// Simple PNG encoder (no external dependencies)
Future<void> savePng(String path, Uint8List pixels, int width, int height) async {
  final png = encodePng(pixels, width, height);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(png);
}

Uint8List encodePng(Uint8List pixels, int width, int height) {
  final output = BytesBuilder();

  // PNG signature
  output.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  // IHDR chunk
  final ihdr = BytesBuilder();
  ihdr.add(_int32be(width));
  ihdr.add(_int32be(height));
  ihdr.addByte(8);  // bit depth
  ihdr.addByte(6);  // color type (RGBA)
  ihdr.addByte(0);  // compression
  ihdr.addByte(0);  // filter
  ihdr.addByte(0);  // interlace
  _writeChunk(output, 'IHDR', ihdr.toBytes());

  // IDAT chunk (image data)
  final rawData = BytesBuilder();
  for (var y = 0; y < height; y++) {
    rawData.addByte(0); // filter type: none
    for (var x = 0; x < width; x++) {
      final idx = (y * width + x) * 4;
      rawData.addByte(pixels[idx]);     // R
      rawData.addByte(pixels[idx + 1]); // G
      rawData.addByte(pixels[idx + 2]); // B
      rawData.addByte(pixels[idx + 3]); // A
    }
  }

  final compressed = _deflate(rawData.toBytes());
  _writeChunk(output, 'IDAT', compressed);

  // IEND chunk
  _writeChunk(output, 'IEND', Uint8List(0));

  return output.toBytes();
}

void _writeChunk(BytesBuilder output, String type, Uint8List data) {
  output.add(_int32be(data.length));
  final typeBytes = type.codeUnits;
  output.add(typeBytes);
  output.add(data);

  // CRC32
  final crcData = BytesBuilder();
  crcData.add(typeBytes);
  crcData.add(data);
  output.add(_int32be(_crc32(crcData.toBytes())));
}

Uint8List _int32be(int value) {
  return Uint8List.fromList([
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ]);
}

int _crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc >> 1) ^ ((crc & 1) * 0xEDB88320);
    }
  }
  return crc ^ 0xFFFFFFFF;
}

// Simple DEFLATE compression (zlib format)
Uint8List _deflate(Uint8List data) {
  final output = BytesBuilder();

  // zlib header
  output.addByte(0x78); // CMF
  output.addByte(0x9C); // FLG

  // Store blocks (uncompressed for simplicity)
  var offset = 0;
  while (offset < data.length) {
    final remaining = data.length - offset;
    final blockSize = math.min(remaining, 65535);
    final isLast = offset + blockSize >= data.length;

    output.addByte(isLast ? 0x01 : 0x00); // BFINAL + BTYPE
    output.addByte(blockSize & 0xFF);
    output.addByte((blockSize >> 8) & 0xFF);
    output.addByte((~blockSize) & 0xFF);
    output.addByte(((~blockSize) >> 8) & 0xFF);

    output.add(data.sublist(offset, offset + blockSize));
    offset += blockSize;
  }

  // Adler-32 checksum
  var s1 = 1;
  var s2 = 0;
  for (final byte in data) {
    s1 = (s1 + byte) % 65521;
    s2 = (s2 + s1) % 65521;
  }
  final adler = (s2 << 16) | s1;
  output.add(_int32be(adler));

  return output.toBytes();
}

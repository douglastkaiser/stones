import 'package:flutter/material.dart';
import '../models/cosmetics.dart';
import '../theme/game_colors.dart';
import 'match_config.dart';

class SeatAppearance {
  static PieceIdentity identity(SeatId seat) =>
      PieceIdentity.values[seat.index];
  static PiecePalette palette(SeatId seat, PieceStyle style) =>
      PieceStyleData.forStyle(style).palettes[seat.index];
  static String label(SeatId seat, PieceStyle style) =>
      palette(seat, style).name;
  static Color marker(SeatId seat, [PieceStyle style = PieceStyle.standard]) =>
      palette(seat, style).primary;
  static PieceColors colors(SeatId seat, PieceStyle style) =>
      palette(seat, style).colors;

  /// Engine explanations retain stable seat IDs; translate only at display time.
  static String describe(String text, Map<SeatId, PieceStyle> styles) =>
      text.replaceAllMapped(
          RegExp(r'\b(Ivory|Charcoal|Copper|Jade|[Ww]hite|[Bb]lack)\b'),
          (match) {
        final seat = switch (match[0]!.toLowerCase()) {
          'white' => SeatId.ivory,
          'black' => SeatId.charcoal,
          _ => SeatId.values.firstWhere((id) => id.label == match[0]),
        };
        return label(seat, styles[seat] ?? PieceStyle.standard);
      });
}

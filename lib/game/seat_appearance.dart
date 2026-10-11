import 'package:flutter/material.dart';
import '../models/cosmetics.dart';
import '../theme/game_colors.dart';
import 'match_config.dart';

class SeatAppearance {
  static Color marker(SeatId seat) => const [
        Color(0xFFFFE3A0),
        Color(0xFF607D8B),
        Color(0xFFE68B54),
        Color(0xFF78B58C),
      ][seat.index];

  static PieceColors colors(SeatId seat, PieceStyle style) {
    final data = PieceStyleData.forStyle(style);
    if (seat == SeatId.ivory || seat == SeatId.charcoal) {
      return data.colorsForPlayer(seat == SeatId.ivory);
    }
    final base = seat == SeatId.copper
        ? const [
            Color(0xFFE8A568),
            Color(0xFFC59779),
            Color(0xFFDFC0A1),
            Color(0xFFE2A261),
            Color(0xFFCB8C65)
          ][style.index]
        : const [
            Color(0xFF80B391),
            Color(0xFF79A89A),
            Color(0xFFA5C5B4),
            Color(0xFFA5B46C),
            Color(0xFF6B9F7B)
          ][style.index];
    return PieceColors(
        primary: base,
        secondary: Color.lerp(base, Colors.black, .22)!,
        border: Color.lerp(base, Colors.black, .60)!);
  }
}

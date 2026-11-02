import 'package:flutter/material.dart';
import '../models/cosmetics.dart';
import 'theme_gallery.dart';

void showPieceThemePreview(BuildContext context, PieceStyle style,
        {BoardTheme? board}) =>
    showCityPreview(context,
        theme: board ?? boardForPieces(style),
        style: style,
        city: boardForPieces(style));

class MatchThemeBadge extends StatelessWidget {
  const MatchThemeBadge(
      {super.key, required this.label, required this.style, this.board});
  final String label;
  final PieceStyle style;
  final BoardTheme? board;
  @override
  Widget build(BuildContext context) => ActionChip(
      avatar: const Icon(Icons.auto_awesome, size: 16),
      label: Text('$label · ${PieceStyleData.forStyle(style).name}'),
      tooltip: 'Inspect pieces and how to unlock this theme',
      onPressed: () => showPieceThemePreview(context, style, board: board));
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cosmetics.dart';
import '../models/piece.dart';
import '../providers/cosmetics_provider.dart';
import 'procedural_painters.dart';

/// Exactly five coordinated sets. Either previous board or piece reward grants
/// its complete set, so upgrading never removes an earned cosmetic.
class ThemeGallery extends ConsumerWidget {
  const ThemeGallery({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(cosmeticsProvider);
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 650 ? 3 : 2;
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final theme in BoardTheme.values)
          SizedBox(
              width: width,
              child: Builder(builder: (context) {
                final data = BoardThemeData.forTheme(theme);
                final style = PieceStyle.values[theme.index];
                final unlocked =
                    ref.watch(isBoardThemeUnlockedProvider(theme)) ||
                        ref.watch(isPieceStyleUnlockedProvider(style));
                final active = selected.selectedBoardTheme == theme &&
                    selected.selectedPieceStyle == style;
                final boardRequirement =
                    ref.watch(boardThemeUnlockRequirementProvider(theme));
                final pieceRequirement =
                    ref.watch(pieceStyleUnlockRequirementProvider(style));
                final requirement = [boardRequirement, pieceRequirement]
                    .whereType<String>()
                    .join(' or ');
                void preview() => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                            title: Text(data.name),
                            content: SingleChildScrollView(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                  SizedBox(
                                      width: 320,
                                      child: AspectRatio(
                                          aspectRatio: 1.5,
                                          child: ThemeSample(theme: theme))),
                                  const SizedBox(height: 12),
                                  Text(data.description),
                                  const Text(
                                      'Flat stones, upright walls and capstones. Light and dark retain distinct silhouettes.'),
                                  if (!unlocked)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(requirement)),
                                ])),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'))
                            ]));
                return Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: active
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: active ? 2 : 1)),
                    child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(children: [
                          SizedBox(
                              height: width * .7,
                              child: ThemeSample(theme: theme)),
                          const SizedBox(height: 8),
                          Text(data.name,
                              style: Theme.of(context).textTheme.titleSmall),
                          Text(data.description,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 6),
                          Wrap(alignment: WrapAlignment.center, children: [
                            TextButton(
                                onPressed: preview,
                                child: Text('Preview ${data.name}')),
                            FilledButton.tonal(
                                onPressed: unlocked
                                    ? () => ref
                                        .read(cosmeticsProvider.notifier)
                                        .setTheme(theme)
                                    : preview,
                                child: Text(active
                                    ? 'Selected'
                                    : unlocked
                                        ? 'Use ${data.name}'
                                        : 'Locked')),
                          ]),
                        ])));
              })),
      ]);
    });
  }
}

class ThemeSample extends StatelessWidget {
  const ThemeSample({super.key, required this.theme});
  final BoardTheme theme;
  @override
  Widget build(BuildContext context) => Semantics(
      label:
          '${BoardThemeData.forTheme(theme).name} board with light and dark flat stones, walls and capstones',
      image: true,
      child: Center(
          child: AspectRatio(
              aspectRatio: 1.5,
              child: CustomPaint(painter: ThemeSamplePainter(theme)))));
}

/// Uses the same painter factories as live gameplay; previews cannot drift.
class ThemeSamplePainter extends CustomPainter {
  const ThemeSamplePainter(this.theme);
  final BoardTheme theme;
  @override
  void paint(Canvas canvas, Size size) {
    final data = BoardThemeData.forTheme(theme);
    final pieces = PieceStyleData.forStyle(PieceStyle.values[theme.index]);
    final board = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(board, const Radius.circular(8)),
        Paint()..color = data.frameOuter);
    final gap = size.width * .025;
    final cellW = (size.width - gap * 4) / 3;
    final cellH = (size.height - gap * 3) / 2;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        final rect = Rect.fromLTWH(
            gap + col * (cellW + gap), gap + row * (cellH + gap), cellW, cellH);
        canvas.save();
        canvas.translate(rect.left, rect.top);
        getBoardTexturePainter(theme: data, seed: row * 3 + col)
            .paint(canvas, rect.size);
        final type = PieceType.values[col];
        final pieceSize = cellW * .72 < cellH * .74 ? cellW * .72 : cellH * .74;
        final w = pieceSize * (type == PieceType.standing ? .4 : 1);
        final h = pieceSize * (type == PieceType.flat ? .55 : 1);
        canvas.translate((cellW - w) / 2, (cellH - h) / 2);
        ThemedPiecePainter(
                style: pieces.style,
                colors: pieces.colorsForPlayer(row == 0),
                type: type,
                isLightPlayer: row == 0)
            .paint(canvas, Size(w, h));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant ThemeSamplePainter old) => theme != old.theme;
}

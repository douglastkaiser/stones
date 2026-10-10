import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/piece.dart';
import 'hex_game.dart';

/// One interaction contract for Hex matches, tutorials and puzzles.
/// Every preview/continuation is a complete move accepted by HexRules.
class HexMoveSelection {
  HexCell? source;
  int carry = 1;
  PieceType type = PieceType.flat;
  HexMove? planned;
  List<HexMove> choices = [];
  int pendingDrop = 1;

  void clear() {
    source = null;
    planned = null;
    choices = [];
    pendingDrop = 1;
  }

  static HexCell end(HexMove move) {
    var cell = move.from;
    for (final _ in move.drops) {
      cell = cell.step(move.direction!);
    }
    return cell;
  }

  List<HexMove> spreads(HexGame game) => source == null
      ? []
      : HexRules.spreads(game, source!, pickup: carry).toList();

  Set<HexCell> destinations(HexGame game) {
    if (source == null) return {};
    if (planned?.direction != null) {
      final next = continuation(game);
      return next == null ? {} : {end(next)};
    }
    return {
      for (final direction in HexDirection.values)
        if (HexRules.play(game, HexMove.spread(source!, direction, [carry])) !=
            null)
          source!.step(direction),
    };
  }

  void setCarry(int value) {
    carry = value;
    planned = null;
    choices = [];
    pendingDrop = 1;
  }

  void choose(HexMove move) {
    planned = move;
    pendingDrop = 1;
  }

  /// True requests confirmation of an already-visible placement/single stone.
  bool tap(HexGame game, HexCell cell) {
    if (game.finished) return false;
    final move = planned;
    if (move?.type != null && move!.from == cell) return true;
    if (move?.direction != null && end(move!) == cell) {
      if (carry == 1) return true;
      pendingDrop = pendingDrop >= move.drops.last ? 1 : pendingDrop + 1;
      return false;
    }
    if (move?.direction != null) {
      if (cell == source) {
        planned = null;
        choices = [];
      } else if (cell == end(move!).step(move.direction!)) {
        continueMove(game);
      }
      return false; // Stray taps preserve the preview.
    }
    if (cell == source) {
      final max = math.min(game.carryLimit, game.stackAt(cell).length);
      setCarry(carry <= 1 ? max : carry - 1);
      return false;
    }
    // The primary neighbor interaction has exactly one complete distribution.
    // Avoid enumerating every long spread (thousands at carry nine) for a tap.
    List<HexMove>? adjacentOptions;
    if (source != null) {
      for (final direction in HexDirection.values) {
        if (source!.step(direction) == cell) {
          final next = HexMove.spread(source!, direction, [carry]);
          adjacentOptions = HexRules.play(game, next) == null ? [] : [next];
          break;
        }
      }
    }
    final options = adjacentOptions ??
        spreads(game).where((move) => end(move) == cell).toList();
    if (options.isNotEmpty) {
      choices = options;
      choose(options.first);
    } else if (!game.opening && game.topAt(cell)?.seat == game.current) {
      clear();
      source = cell;
      carry = math.min(game.carryLimit, game.stackAt(cell).length);
    } else if (game.stackAt(cell).isEmpty && source == null) {
      final placement =
          HexMove.place(cell, game.opening ? PieceType.flat : type);
      if (HexRules.play(game, placement) != null) {
        clear();
        planned = placement;
      }
    }
    return false;
  }

  void swipe(HexGame game, HexCell cell, HexDirection direction) {
    if (game.finished || game.opening) return;
    if (planned?.direction != null) {
      if (cell == end(planned!) && direction == planned!.direction) {
        continueMove(game);
      }
      return;
    }
    if (game.topAt(cell)?.seat != game.current) return;
    final pickup = source == cell
        ? carry
        : math.min(game.carryLimit, game.stackAt(cell).length);
    final move = HexMove.spread(cell, direction, [pickup]);
    if (HexRules.play(game, move) == null) return;
    clear();
    source = cell;
    carry = pickup;
    choices = [move];
    choose(move);
  }

  HexMove? continuation(HexGame game) {
    final move = planned;
    if (move?.direction == null || pendingDrop >= move!.drops.last) return null;
    final next = HexMove.spread(move.from, move.direction!, [
      ...move.drops.take(move.drops.length - 1),
      pendingDrop,
      move.drops.last - pendingDrop,
    ]);
    return HexRules.play(game, next) == null ? null : next;
  }

  void continueMove(HexGame game) {
    final next = continuation(game);
    if (next != null) {
      choices = [next];
      choose(next);
    }
  }

  void backStep(HexGame game) {
    final move = planned;
    if (move?.direction == null) return;
    if (move!.drops.length == 1) {
      planned = null;
      choices = [];
      return;
    }
    final drops = move.drops.toList();
    final last = drops.removeLast();
    drops[drops.length - 1] += last;
    final previous = HexMove.spread(move.from, move.direction!, drops);
    if (HexRules.play(game, previous) != null) {
      choices = [previous];
      choose(previous);
    }
  }
}

class HexMoveControls extends StatelessWidget {
  const HexMoveControls(
      {super.key,
      required this.selection,
      required this.game,
      required this.onChanged});
  final HexMoveSelection selection;
  final HexGame game;
  final VoidCallback onChanged;

  void change(VoidCallback action) {
    action();
    onChanged();
  }

  Widget count(String label, int value, int max, ValueChanged<int> update) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            tooltip: 'Decrease $label',
            onPressed:
                value <= 1 ? null : () => change(() => update(value - 1)),
            icon: const Icon(Icons.remove)),
        Text('$label $value'),
        IconButton(
            tooltip: 'Increase $label',
            onPressed:
                value >= max ? null : () => change(() => update(value + 1)),
            icon: const Icon(Icons.add)),
      ]);

  @override
  Widget build(BuildContext context) {
    final source = selection.source;
    if (source == null) return const SizedBox.shrink();
    final move = selection.planned;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      count(
          'Carry',
          selection.carry,
          math.min(game.carryLimit, game.stackAt(source).length),
          selection.setCarry),
      if (move?.direction != null) ...[
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          count('Drop', selection.pendingDrop, move!.drops.last,
              (value) => selection.pendingDrop = value),
          TextButton(
              onPressed: selection.continuation(game) == null
                  ? null
                  : () => change(() => selection.continueMove(game)),
              child: const Text('Drop & next')),
          TextButton(
              onPressed: () =>
                  change(() => selection.pendingDrop = move.drops.last),
              child: const Text('All here')),
          TextButton(
              onPressed: () => change(() => selection.backStep(game)),
              child: const Text('Back step')),
        ]),
        Text('Drop ${move.drops.join(' → ')}', textAlign: TextAlign.center),
        if (selection.choices.length > 1)
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final option in selection.choices)
              ChoiceChip(
                  label: Text('Drop ${option.drops.join(' → ')}'),
                  selected: identical(option, move),
                  onSelected: (_) => change(() => selection.choose(option)))
          ]),
      ],
    ]);
  }
}

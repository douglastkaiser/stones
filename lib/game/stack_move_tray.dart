import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/cosmetics.dart';
import '../widgets/piece_stack_view.dart';
import 'match_config.dart';
import 'match_state.dart';
import 'seat_appearance.dart';

/// The same ordered stones remain visible while choosing, carrying and dropping.
class StackMoveTray extends StatefulWidget {
  const StackMoveTray(
      {super.key,
      required this.label,
      required this.stones,
      required this.styles,
      this.carry = 0,
      this.dropped = 0,
      this.started = false,
      this.carryLimit = 1,
      this.showNextDrop = true,
      this.maxHeight = double.infinity,
      this.onCarry,
      this.onReturn});
  final String label;
  final List<Stone> stones;
  final Map<SeatId, PieceStyle> styles;
  final int carry, dropped, carryLimit;
  final bool started, showNextDrop;
  final double maxHeight;
  final ValueChanged<int>? onCarry;
  final VoidCallback? onReturn;

  static StackVisualPiece visual(Stone stone, Map<SeatId, PieceStyle> styles) {
    final style = styles[stone.seat] ?? PieceStyle.standard;
    return StackVisualPiece(
        type: stone.type,
        style: style,
        colors: SeatAppearance.colors(stone.seat, style),
        owner: stone.seat.label,
        isLight: stone.seat != SeatId.charcoal);
  }

  static Widget nextDrop(Stone stone, Map<SeatId, PieceStyle> styles) =>
      Semantics(
          liveRegion: true,
          child: Row(children: [
            SizedBox(
                width: 38,
                height: 40,
                child: Center(
                    child: PieceStackView.stone(visual(stone, styles), 32))),
            const SizedBox(width: 6),
            Expanded(
                child:
                    Text('Next to drop: ${visual(stone, styles).description}')),
          ]));

  @override
  State<StackMoveTray> createState() => _StackMoveTrayState();
}

class _StackMoveTrayState extends State<StackMoveTray> {
  bool _expanded = false;
  @override
  void didUpdateWidget(StackMoveTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.label != oldWidget.label) _expanded = false;
  }

  Widget _piece(Stone stone) => SizedBox(
      width: 38,
      height: 40,
      child: Center(
          child: PieceStackView.stone(
              StackMoveTray.visual(stone, widget.styles), 32)));

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final length = widget.stones.length;
    final boundary = length - widget.carry;
    final next = boundary + widget.dropped;
    final remaining = widget.carry - widget.dropped;
    return Container(
      key: const ValueKey('stack-tray'),
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
          color: palette.surfaceContainerLow,
          border: Border.all(color: palette.outlineVariant),
          borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
              child: Text(
                  '${widget.label} · $length ${length == 1 ? 'stone' : 'stones'}',
                  style: Theme.of(context).textTheme.titleSmall)),
          TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Collapse' : 'Expand')),
        ]),
        if (widget.onReturn != null)
          TextButton.icon(
              onPressed: widget.onReturn,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to carried stones')),
        if (widget.carry > 0)
          Text(widget.started
              ? 'Carrying $remaining · ${widget.dropped} staged'
              : 'Taking ${widget.carry} of $length · $boundary stay here'),
        if (widget.onCarry != null)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                tooltip: 'Take fewer stones',
                onPressed: widget.carry <= 1
                    ? null
                    : () => widget.onCarry!(widget.carry - 1),
                icon: const Icon(Icons.remove)),
            Text('Take ${widget.carry}'),
            IconButton(
                tooltip: 'Take more stones',
                onPressed: widget.carry >= math.min(length, _limit)
                    ? null
                    : () => widget.onCarry!(widget.carry + 1),
                icon: const Icon(Icons.add)),
          ]),
        Flexible(
            child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 140),
          height: (_expanded
                  ? 260
                  : math.min(length, widget.carry > widget.dropped ? 2 : 3) *
                      48) *
              MediaQuery.textScalerOf(context).scale(1),
          child: ListView.builder(
              key: ValueKey('stack-layers-${widget.label}'),
              itemCount: length,
              itemBuilder: (context, row) {
                final index = length - row - 1;
                final stone = widget.stones[index];
                final selected = widget.carry > 0 && index >= next;
                final staged =
                    widget.carry > 0 && index >= boundary && index < next;
                final count = length - index;
                final enabled = widget.onCarry != null && count <= _limit;
                final status = index == next && remaining > 0
                    ? 'Next to drop'
                    : selected
                        ? widget.started
                            ? 'Carried'
                            : 'Taking'
                        : staged
                            ? 'Staged'
                            : widget.carry > 0
                                ? 'Stays here'
                                : index == length - 1
                                    ? 'Controls stack'
                                    : 'Buried';
                final visual = StackMoveTray.visual(stone, widget.styles);
                return Semantics(
                  label: '${visual.description}, level ${index + 1}, $status',
                  selected: selected,
                  child: Material(
                    color: selected
                        ? palette.primaryContainer
                        : Colors.transparent,
                    child: InkWell(
                      key: ValueKey('take-layer-$count'),
                      onTap: !enabled ? null : () => widget.onCarry!(count),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        decoration: BoxDecoration(
                            border: Border(
                                left: BorderSide(
                                    color: selected
                                        ? palette.primary
                                        : palette.outlineVariant,
                                    width: selected ? 3 : 1))),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Row(children: [
                          _piece(stone),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(
                                  '${visual.description}\n${index == length - 1 ? 'Top · ' : index == 0 ? 'Bottom · ' : ''}$status',
                                  style:
                                      Theme.of(context).textTheme.bodySmall)),
                          Text('${index + 1}',
                              style: Theme.of(context).textTheme.labelSmall),
                        ]),
                      ),
                    ),
                  ),
                );
              }),
        )),
        if (remaining > 0 && widget.showNextDrop)
          StackMoveTray.nextDrop(widget.stones[next], widget.styles),
      ]),
    );
  }

  // The caller limits carry choices using the configured board's carry limit.
  int get _limit => widget.carryLimit;
}

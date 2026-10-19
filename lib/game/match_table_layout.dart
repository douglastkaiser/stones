import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Board size depends on the viewport, never on a transient control or message.
class MatchTableLayout extends StatelessWidget {
  const MatchTableLayout(
      {super.key,
      required this.board,
      required this.players,
      required this.status,
      required this.controls,
      required this.details,
      required this.playerCount,
      this.invitation});
  final Widget board, players, status, controls, details;
  final Widget? invitation;
  final int playerCount;
  Widget _board(double side) => SizedBox(
      key: const ValueKey('stable-board'),
      width: side,
      height: side,
      child: board);
  @override
  Widget build(BuildContext context) =>
      SafeArea(child: LayoutBuilder(builder: (context, bounds) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        if (bounds.maxWidth >= 1000 && bounds.maxWidth / scale >= 760) {
          return Padding(
              padding: const EdgeInsets.all(12),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Column(children: [
                  if (invitation != null) invitation!,
                  SizedBox(height: 44 * scale, child: Center(child: status)),
                  Expanded(
                      child: LayoutBuilder(
                          builder: (_, area) => Center(
                              child: _board(math.min(760,
                                  math.min(area.maxWidth, area.maxHeight)))))),
                ])),
                const SizedBox(width: 16),
                SizedBox(
                    width: 310,
                    child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(children: [players, controls, details]))),
              ]));
        }
        final playerBudget =
            (playerCount > 2 || bounds.maxWidth < 360 ? 120 : 72) * scale;
        final side = math.min(
            math.min(bounds.maxWidth, 760),
            math.max(
                240,
                bounds.maxHeight -
                    playerBudget -
                    44 * scale -
                    130 * scale -
                    (invitation == null ? 0 : 60 * scale)));
        return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(children: [
                      if (invitation != null) invitation!,
                      players,
                      SizedBox(
                          height: 44 * scale, child: Center(child: status)),
                      _board(side.toDouble()),
                      controls,
                      details,
                    ]))));
      }));
}

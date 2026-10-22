import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Geometry and typography determine capacity, never the current move contents.
class MatchLayoutPolicy {
  const MatchLayoutPolicy(this.size, this.panelWidth);
  final Size size;
  final double panelWidth;
  bool get beside =>
      (size.width >= 1000 || size.width > size.height) &&
      size.width >= panelWidth + 224 + 40 &&
      size.height >= 248;
  double get boardSide => beside
      ? math.min(760, math.min(size.width - panelWidth - 40, size.height - 24))
      : math.min(size.width, 760);

  static double measurePanel(BuildContext context) {
    final text = TextPainter(
      text: TextSpan(
        text: 'Cancel   Confirm move',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = math.max(280.0, text.width + 104);
    text.dispose();
    return width;
  }
}

/// Portrait retains full width; the move dock never overlays board targets.
class MatchTableLayout extends StatelessWidget {
  const MatchTableLayout({
    super.key,
    required this.board,
    required this.players,
    required this.status,
    required this.controls,
    required this.details,
    this.invitation,
    this.primaryActions,
    this.moveDock,
    this.boardTools,
    this.controlsBuilder,
  });
  final Widget board, players, status, controls, details;
  final Widget? invitation, primaryActions, moveDock, boardTools;
  final Widget Function(BuildContext, double)? controlsBuilder;

  Widget _board(double side) => SizedBox(
        key: const ValueKey('stable-board'),
        width: side,
        height: side,
        child: board,
      );

  Widget _dock(double availableHeight) => Material(
        key: const ValueKey('primary-actions'),
        elevation: 4,
        child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: availableHeight),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (moveDock != null)
                Flexible(
                    child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxHeight: math.max(0, availableHeight * .3)),
                        child: SingleChildScrollView(
                            key: const PageStorageKey('move-dock-content'),
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: moveDock)))),
              if (primaryActions != null)
                Padding(
                    padding: const EdgeInsets.all(8), child: primaryActions),
            ])),
      );

  Widget _scroll(Widget Function(double) content, String key) => Expanded(
      child: LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
              key: PageStorageKey(key),
              physics: const ClampingScrollPhysics(),
              child: content(bounds.maxHeight))));

  @override
  Widget build(BuildContext context) => SafeArea(child: LayoutBuilder(
        builder: (context, bounds) {
          final policy = MatchLayoutPolicy(
              bounds.biggest, MatchLayoutPolicy.measurePanel(context));
          final dock = primaryActions != null || moveDock != null;
          if (policy.beside) {
            return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: Align(
                              alignment: Alignment.topCenter,
                              child: _board(policy.boardSide))),
                      const SizedBox(width: 16),
                      SizedBox(
                          width: policy.panelWidth,
                          child: Column(children: [
                            _scroll(
                                (height) => Column(children: [
                                      players,
                                      status,
                                      if (invitation != null) invitation!,
                                      if (boardTools != null) boardTools!,
                                      controlsBuilder?.call(context, height) ??
                                          controls,
                                      details
                                    ]),
                                'match-sidebar'),
                            if (dock) _dock(bounds.maxHeight - 24),
                          ])),
                    ]));
          }
          return Column(children: [
            _scroll(
                (height) => Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(children: [
                          players,
                          _board(policy.boardSide),
                          if (boardTools != null) boardTools!,
                          status,
                          if (invitation != null) invitation!,
                          controlsBuilder?.call(context, height) ?? controls,
                          details
                        ]))),
                'match-content'),
            if (dock) _dock(bounds.maxHeight),
          ]);
        },
      ));
}

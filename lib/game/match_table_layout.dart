import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Both shapes use viewport width in portrait; actions never cover the board.
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
  });
  final Widget board, players, status, controls, details;
  final Widget? invitation, primaryActions;

  Widget _board(double side) => SizedBox(
        key: const ValueKey('stable-board'),
        width: side,
        height: side,
        child: board,
      );

  Widget _actions() => Material(
        key: const ValueKey('primary-actions'),
        elevation: 4,
        child: SizedBox(
          width: double.infinity,
          child:
              Padding(padding: const EdgeInsets.all(8), child: primaryActions),
        ),
      );

  @override
  Widget build(BuildContext context) => SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            if (bounds.maxWidth >= 1000 && bounds.maxWidth / scale >= 760) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          if (invitation != null) invitation!,
                          ConstrainedBox(
                            constraints: BoxConstraints(minHeight: 44 * scale),
                            child: Center(child: status),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (_, area) => Center(
                                child: _board(
                                  math.min(
                                    760,
                                    math.min(area.maxWidth, area.maxHeight),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 310,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: Column(
                                  children: [players, controls, details]),
                            ),
                          ),
                          if (primaryActions != null) _actions(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: const PageStorageKey('match-content'),
                    physics: const ClampingScrollPhysics(),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          children: [
                            if (invitation != null) invitation!,
                            players,
                            ConstrainedBox(
                              constraints:
                                  BoxConstraints(minHeight: 44 * scale),
                              child: Center(child: status),
                            ),
                            _board(math.min(bounds.maxWidth, 760)),
                            controls,
                            details,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (primaryActions != null) _actions(),
              ],
            );
          },
        ),
      );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:stones/models/models.dart';

void main() {
  group('tutorialAndPuzzleLibrary', () {
    test('scenarios have required metadata and valid initial states', () {
      final seenIds = <String>{};

      for (final scenario in tutorialAndPuzzleLibrary) {
        expect(
          scenario.id.trim(),
          isNotEmpty,
          reason: 'Scenario id must be non-empty.',
        );
        expect(
          seenIds.add(scenario.id),
          isTrue,
          reason: 'Scenario id must be unique: ${scenario.id}',
        );
        expect(
          scenario.title.trim(),
          isNotEmpty,
          reason: 'Scenario ${scenario.id} must have a title.',
        );
        expect(
          scenario.summary.trim(),
          isNotEmpty,
          reason: 'Scenario ${scenario.id} must have a summary.',
        );
        expect(
          scenario.objective.trim(),
          isNotEmpty,
          reason: 'Scenario ${scenario.id} must have an objective.',
        );
        expect(
          scenario.completionText.trim(),
          isNotEmpty,
          reason: 'Scenario ${scenario.id} must have completion text.',
        );

        final state = scenario.buildInitialState();
        expect(
          state.boardSize,
          inInclusiveRange(3, 8),
          reason: 'Scenario ${scenario.id} has an invalid board size.',
        );
        expect(
          state.turnNumber,
          greaterThan(0),
          reason: 'Scenario ${scenario.id} must start on a positive turn.',
        );
        expect(
          state.whitePieces.flatStones,
          greaterThanOrEqualTo(0),
          reason: 'Scenario ${scenario.id} has negative white flat stones.',
        );
        expect(
          state.whitePieces.capstones,
          greaterThanOrEqualTo(0),
          reason: 'Scenario ${scenario.id} has negative white capstones.',
        );
        expect(
          state.blackPieces.flatStones,
          greaterThanOrEqualTo(0),
          reason: 'Scenario ${scenario.id} has negative black flat stones.',
        );
        expect(
          state.blackPieces.capstones,
          greaterThanOrEqualTo(0),
          reason: 'Scenario ${scenario.id} has negative black capstones.',
        );

        for (final position in state.board.occupiedPositions) {
          expect(
            position.isValid(state.boardSize),
            isTrue,
            reason: 'Scenario ${scenario.id} has out-of-bounds occupied cells.',
          );
        }
      }
    });

    test('guided move contract is coherent and highlighted cells are in bounds', () {
      for (final scenario in tutorialAndPuzzleLibrary) {
        final guidedMove = scenario.guidedMove;
        final state = scenario.buildInitialState();

        switch (guidedMove.type) {
          case GuidedMoveType.placement:
            final hasSingleTarget = guidedMove.target != null;
            final hasMultipleTargets =
                guidedMove.allowedTargets != null && guidedMove.allowedTargets!.isNotEmpty;
            expect(
              hasSingleTarget || hasMultipleTargets,
              isTrue,
              reason: 'Placement move in ${scenario.id} needs target(s).',
            );
            expect(
              hasSingleTarget && hasMultipleTargets,
              isFalse,
              reason: 'Placement move in ${scenario.id} cannot have both target and allowedTargets.',
            );
            expect(guidedMove.from, isNull);
            expect(guidedMove.direction, isNull);
            expect(guidedMove.drops, isNull);

          case GuidedMoveType.stackMove:
            expect(guidedMove.from, isNotNull,
                reason: 'Stack move in ${scenario.id} needs an origin.');
            expect(guidedMove.direction, isNotNull,
                reason: 'Stack move in ${scenario.id} needs a direction.');
            expect(guidedMove.drops, isNotNull,
                reason: 'Stack move in ${scenario.id} needs drops.');
            expect(guidedMove.drops, isNotEmpty,
                reason: 'Stack move in ${scenario.id} needs at least one drop.');
            expect(
              guidedMove.drops!.every((drop) => drop > 0),
              isTrue,
              reason: 'Stack move in ${scenario.id} must have positive drops only.',
            );

          case GuidedMoveType.anyPlacement:
            expect(guidedMove.target, isNull);
            expect(guidedMove.allowedTargets, isNull);
            expect(guidedMove.from, isNull);
            expect(guidedMove.direction, isNull);
            expect(guidedMove.drops, isNull);

          case GuidedMoveType.anyStackMove:
            expect(guidedMove.from, isNotNull,
                reason: 'Any-stack move in ${scenario.id} needs an origin.');
            expect(guidedMove.target, equals(guidedMove.from));
            expect(guidedMove.direction, isNull);
            expect(guidedMove.drops, isNull);
            expect(guidedMove.allowedTargets, isNull);
        }

        for (final position in guidedMove.highlightedCells(state.boardSize)) {
          expect(
            position.isValid(state.boardSize),
            isTrue,
            reason:
                'Scenario ${scenario.id} has highlighted cell outside ${state.boardSize}x${state.boardSize}.',
          );
        }
      }
    });

    test('scripted responses reference legal, in-bounds positions', () {
      for (final scenario in tutorialAndPuzzleLibrary) {
        final boardSize = scenario.buildInitialState().boardSize;

        for (final response in scenario.scriptedResponses) {
          switch (response) {
            case AIPlacementMove():
              expect(
                response.position.isValid(boardSize),
                isTrue,
                reason:
                    'Scenario ${scenario.id} has scripted placement out of bounds: ${response.position}',
              );

            case AIStackMove():
              expect(
                response.from.isValid(boardSize),
                isTrue,
                reason:
                    'Scenario ${scenario.id} has scripted stack origin out of bounds: ${response.from}',
              );
              expect(
                response.drops,
                isNotEmpty,
                reason: 'Scenario ${scenario.id} scripted stack move requires drops.',
              );
              expect(
                response.drops.every((drop) => drop > 0),
                isTrue,
                reason:
                    'Scenario ${scenario.id} scripted stack move has non-positive drops.',
              );

              var current = response.from;
              for (var i = 0; i < response.drops.length; i++) {
                current = response.direction.apply(current);
                expect(
                  current.isValid(boardSize),
                  isTrue,
                  reason:
                      'Scenario ${scenario.id} scripted path exits board at step ${i + 1}: $current',
                );
              }
          }
        }
      }
    });

    test('chapter group sorting is deterministic by chapter then order', () {
      final groups = buildScenarioChapterGroups();

      expect(
        groups.map((group) => group.chapter.index),
        orderedEquals([...groups.map((group) => group.chapter.index)]..sort()),
      );

      for (final group in groups) {
        final orders = group.scenarios.map((scenario) => scenario.orderInChapter).toList();
        expect(
          orders,
          orderedEquals([...orders]..sort()),
          reason: 'Chapter ${group.chapter} has unsorted scenario order.',
        );
      }
    });
  });
}

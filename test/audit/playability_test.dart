import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/models/models.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/hex/hex_ai.dart';
import 'package:stones/providers/achievements_provider.dart';
import 'package:stones/providers/game_provider.dart';
import 'package:stones/providers/scenario_provider.dart';
import 'package:stones/services/ai/ai.dart';

bool play(GameStateNotifier game, AIMove move) => switch (move) {
      AIPlacementMove() => game.placePiece(move.position, move.pieceType),
      AIStackMove() => game.moveStack(move.from, move.direction, move.drops),
    };

void main() {
  test('native compute search returns a legal opening move', () async {
    final game = GameStateNotifier();
    game.newGame(3);
    final move = await selectStonesMove(game.state, AIDifficulty.easy);
    expect(move, isNotNull);
    expect(play(game, move!), isTrue);
    game.dispose();
  });

  for (final radius in [2, 3, 4]) {
    test('three AI Hex seats finish radius $radius with legal moves', () {
      var game = HexGame.initial(radius: radius);
      final timer = Stopwatch()..start();
      while (!game.finished && game.ply < 180) {
        final move = HexAI.choose(game);
        expect(move, isNotNull);
        final next = HexRules.play(game, move!);
        expect(next, isNotNull);
        game = next!;
      }
      print(
          'Hex radius $radius: ${game.ply} plies, ${timer.elapsedMilliseconds} ms, winner=${game.winner}');
      expect(game.finished, isTrue);
      expect(HexAI.choose(game), isNull);
    });
  }

  for (final difficulty in AIDifficulty.values) {
    for (final size in [3, 5, 8]) {
      test('${difficulty.name} takes a road win on $size×$size', () async {
        var board = Board.empty(size);
        for (var col = 0; col < size - 1; col++) {
          board = board.placePiece(Position(0, col),
              const Piece(type: PieceType.flat, color: PlayerColor.white));
        }
        final game = GameStateNotifier();
        addTearDown(game.dispose);
        game.loadState(GameState.initial(size)
            .copyWith(board: board, phase: GamePhase.playing));
        final move =
            await StonesAI.forDifficulty(difficulty, random: Random(17))
                .selectMove(game.state);
        expect(move, isNotNull);
        expect(play(game, move!), isTrue);
        expect(game.state.result, GameResult.whiteWins);
      });
    }
    test('${difficulty.name} seeded complete 3×3 trial', () async {
      final game = GameStateNotifier();
      addTearDown(game.dispose);
      game.newGame(3);
      final ai = StonesAI.forDifficulty(difficulty, random: Random(39));
      final watch = Stopwatch()..start();
      var ply = 0;
      while (!game.state.isGameOver && ply < 80) {
        final move = await ai.selectMove(game.state);
        expect(move, isNotNull, reason: 'No move on ply $ply');
        expect(play(game, move!), isTrue,
            reason: 'Illegal ${difficulty.name} move at $ply');
        ply++;
      }
      expect(game.state.isGameOver, isTrue,
          reason:
              '${difficulty.name} did not finish within 80 moves; repeated cycling needs investigation');
      // Measured trials belong in the audit, not a fragile machine-speed assertion.
      // ignore: avoid_print
      print(
          'AUDIT ${difficulty.name}: $ply plies, ${watch.elapsedMilliseconds}ms, ${game.state.result}');
    });
  }

  for (final difficulty in [AIDifficulty.hard, AIDifficulty.expert]) {
    test('${difficulty.name} finds a forced fork beyond an immediate win',
        () async {
      const white = Piece(type: PieceType.flat, color: PlayerColor.white);
      const black = Piece(type: PieceType.flat, color: PlayerColor.black);
      final board = Board.empty(3)
          .placePiece(const Position(0, 0), white)
          .placePiece(const Position(1, 1), white)
          .placePiece(const Position(0, 2), black);
      final state =
          GameState.initial(3).copyWith(board: board, phase: GamePhase.playing);
      final move = await StonesAI.forDifficulty(difficulty, random: Random(1))
          .selectMove(state);
      expect(move, isA<AIPlacementMove>());
      final placement = move! as AIPlacementMove;
      expect(placement.position, const Position(1, 0));
      expect(placement.pieceType, PieceType.flat);
    });
  }

  for (final scenario in tutorialAndPuzzleLibrary) {
    test('${scenario.title}: prescribed first action is playable', () {
      final game = GameStateNotifier();
      addTearDown(game.dispose);
      game.loadState(scenario.buildInitialState());
      final guide = scenario.guidedMove;
      late final AIMove move;
      if (guide.type == GuidedMoveType.placement ||
          guide.type == GuidedMoveType.anyPlacement) {
        final target = guide.target ??
            guide.allowedTargets?.first ??
            game.state.board.allPositions
                .firstWhere((p) => game.state.board.stackAt(p).isEmpty);
        move = AIPlacementMove(target, guide.pieceType ?? PieceType.flat);
      } else if (guide.type == GuidedMoveType.stackMove) {
        move = AIStackMove(guide.from!, guide.direction!, guide.drops!);
      } else {
        move = const AIMoveGenerator()
            .generateMoves(game.state)
            .whereType<AIStackMove>()
            .firstWhere((m) => m.from == guide.from);
      }
      expect(play(game, move), isTrue);
      if (scenario.scriptedResponses.isNotEmpty && !game.state.isGameOver) {
        expect(play(game, scenario.scriptedResponses.first), isTrue,
            reason:
                'First scripted response must be legal after the taught move');
      }
    });
  }

  test('all three multi-move puzzles reach their advertised road result', () {
    for (final id in ['puzzle_10', 'puzzle_11', 'puzzle_12']) {
      final scenario = tutorialAndPuzzleLibrary.firstWhere((s) => s.id == id);
      final game = GameStateNotifier()..loadState(scenario.buildInitialState());
      try {
        expect(game.placePiece(scenario.guidedMove.target!, PieceType.flat),
            isTrue);
        expect(play(game, scenario.scriptedResponses.first), isTrue);
        if (id == 'puzzle_10') {
          expect(game.placePiece(const Position(3, 2), PieceType.flat), isTrue);
        } else {
          if (id == 'puzzle_11') {
            expect(game.moveStack(const Position(2, 0), Direction.right, [1]),
                isTrue);
          } else {
            expect(
                game.placePiece(const Position(2, 1), PieceType.flat), isTrue);
          }
          expect(play(game, scenario.scriptedResponses[1]), isTrue);
          if (id == 'puzzle_11') {
            expect(
                game.placePiece(const Position(4, 1), PieceType.flat), isTrue);
          } else {
            expect(
                game.moveStack(const Position(2, 0), Direction.right, [1, 1]),
                isTrue);
          }
        }
        expect(game.state.result, GameResult.whiteWins, reason: id);
      } finally {
        game.dispose();
      }
    }
  });

  test('puzzle losses and draws cannot award completion', () {
    for (final scenario in tutorialAndPuzzleLibrary
        .where((s) => s.type == ScenarioType.puzzle)) {
      final progress =
          ScenarioState(activeScenario: scenario, guidedStepComplete: true);
      final initial = scenario.buildInitialState();
      expect(
          progress.isSuccessful(initial.copyWith(
              result: GameResult.blackWins, phase: GamePhase.finished)),
          isFalse);
      expect(
          progress.isSuccessful(initial.copyWith(
              result: GameResult.draw, phase: GamePhase.finished)),
          isFalse);
      expect(
          progress.isSuccessful(initial.copyWith(
              result: GameResult.whiteWins, phase: GamePhase.finished)),
          isTrue);
      if (scenario.scriptedResponses.isNotEmpty) {
        expect(progress.isSuccessful(initial), isFalse);
      }
    }
  });

  test('all eleven achievements unlock, persist, and do not duplicate',
      () async {
    SharedPreferences.setMockInitialValues({});
    final awards = AchievementNotifier();
    final restored = AchievementNotifier();
    addTearDown(awards.dispose);
    addTearDown(restored.dispose);
    for (var win = 0; win < 50; win++) {
      await awards.recordWin(
          isOnline: win == 0,
          aiDifficulty: win < 4 ? AIDifficulty.values[win] : null,
          byTime: win == 1,
          byFlats: win == 2);
    }
    for (final id in AchievementState.allTutorialIds) {
      await awards.completeTutorial(id);
    }
    for (final id in AchievementState.allPuzzleIds) {
      await awards.completePuzzle(id);
    }
    expect(
        awards.state.unlockedAchievements, containsAll(AchievementType.values));
    expect(await awards.unlock(AchievementType.student), isFalse);
    await restored.load();
    expect(restored.state.totalWins, 50);
    expect(
        restored.state.unlockedAchievements, awards.state.unlockedAchievements);
    expect(restored.state.allTutorialsCompleted, isTrue);
    expect(restored.state.allPuzzlesCompleted, isTrue);
  });
}

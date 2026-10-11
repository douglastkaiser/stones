import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_forcing_position.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/multiplayer_studies.dart';
import 'package:stones/game/study_controller.dart';
import 'package:stones/puzzles/forcing_search.dart';

void main() {
  for (final study in multiplayerStudies) {
    test(
        '${study.id} has exactly one legal winning spread and rejects shortcuts',
        () async {
      final game = study.initial;
      expect(game.finished, isFalse);
      for (final id in game.config.ids) {
        expect(MatchRules.road(game, id), isEmpty);
      }
      final proof = ForcingSearch<MatchState, MatchMove>(
          MatchForcingPosition(), game.current.index);
      final winners = proof.winningMoves(game, 1);
      expect(winners, hasLength(1));
      final move = winners.single;
      final square = game.config.shape == BoardShape.square;
      expect(move.from, square ? const Cell(1, 3) : const Cell(0, 2));
      expect(move.direction, Step.northWest);
      expect(move.drops, [1, 1]);
      final initialSupply = Reserve.initial(game.config);
      for (final id in game.config.ids) {
        final pieces =
            game.board.values.expand((s) => s).where((p) => p.seat == id);
        expect(pieces.length + game.reserves[id]!.total, initialSupply.total);
      }
      final controller = StudyController(study);
      expect(await controller.play(move), isTrue);
      expect(controller.solved, isTrue);
      controller.reset();
      final wrong = MatchRules.legalMoves(game).firstWhere((m) =>
          MatchForcingPosition().moveKey(m) !=
          MatchForcingPosition().moveKey(move));
      expect(await controller.play(wrong), isTrue);
      expect(controller.failed, isTrue);
      expect(controller.solved, isFalse);
      controller.dispose();
    });
  }
}

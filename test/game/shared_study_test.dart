import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/legacy_hex_adapter.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_forcing_position.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/match_study.dart';
import 'package:stones/game/study_catalog.dart';
import 'package:stones/game/study_controller.dart';
import 'package:stones/hex/hex_forcing_position.dart';
import 'package:stones/puzzles/certificates.dart';
import 'package:stones/puzzles/forcing_search.dart';
import 'package:stones/puzzles/square_forcing_position.dart';

void main() {
  for (final study in matchStudies
      .where((s) => s.puzzle && !s.id.startsWith('unified_v1_'))) {
    test('${study.id}: shared engine proves the certified winning move set',
        () {
      final certificate = puzzleCertificates[study.id]!;
      final proof = ForcingSearch<MatchState, MatchMove>(
          MatchForcingPosition(), study.initial.current.index);
      final moves = MatchRules.legalMoves(study.initial).toList();
      expect(moves.length, certificate['legal']);
      String oldKey(MatchMove move) => study.legacyHex
          ? HexForcingPosition().moveKey(LegacyHexAdapter.writeMove(move))
          : SquareForcingPosition().moveKey(MatchStudy.squareMove(move));
      final winners = proof
          .winningMoves(study.initial, study.moveLimit)
          .map(oldKey)
          .toSet();
      expect(winners, (certificate['winning'] as List).cast<String>().toSet());
    }, timeout: const Timeout(Duration(minutes: 5)));
    test('${study.id}: solution works in the shared learning controller',
        () async {
      final controller = StudyController(study);
      final sample =
          (puzzleCertificates[study.id]!['sample'] as List).cast<String>();
      final learner = study.initial.current;
      var samplePly = study.initial.ply;
      for (final key in sample) {
        final move = study.legacyHex
            ? LegacyHexAdapter.move(HexForcingPosition.decode(key))
            : MatchStudy.fromSquareMove(SquareForcingPosition.decode(key));
        final actor = study.initial.config.turnAt(samplePly++);
        if (actor == learner && !controller.solved) {
          expect(await controller.play(move), isTrue);
        }
      }
      expect(controller.solved, isTrue);
      expect(controller.failed, isFalse);
      controller.dispose();
    });
  }
  test(
      'variable-seat opening lessons require the entire two-to-four-player cycle',
      () async {
    for (final shape in BoardShape.values) {
      for (var count = 2; count <= 4; count++) {
        final study = matchStudies.firstWhere(
            (s) => s.id == 'unified_v1_${shape.name}_exchange_$count');
        final controller = StudyController(study);
        for (var step = 0; step < count; step++) {
          final move = MatchRules.legalMoves(controller.state.game!).first;
          expect(await controller.play(move), isTrue);
          expect(controller.solved, step == count - 1);
        }
        expect(controller.state.game!.opening, isFalse);
        expect(controller.state.canPlay, isFalse);
        controller.reset();
        expect(controller.state.game!.ply, 0);
        controller.dispose();
      }
    }
  });
}

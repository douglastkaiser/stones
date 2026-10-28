import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/ai_duel_safety.dart';
import 'package:stones/game/ai_search_cache.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/services/ai/search_budget.dart';
import '../../tools/ai_balance_proof.dart' show DuelProof;
import '../../tools/ai_duel_defense_check.dart' show classifyQuickLoss;

void main() {
  final fixtures = jsonDecode(
      File('docs/qa/ai-fix/later-defense-regressions.json')
          .readAsStringSync()) as List;
  for (final fixture in fixtures) {
    test(
        '${fixture['case']} tests the opponent, including when the starter defends',
        () async {
      var game = MatchState.initial(
          MatchConfig.fromMap(Map<String, dynamic>.from(fixture['config'])));
      for (final raw in fixture['moves'] as List) {
        game = MatchRules.play(
            game, MatchMove.fromMap(Map<String, dynamic>.from(raw)))!;
      }
      expect(game.current.name, fixture['defender']);
      final oldMove =
          MatchMove.fromMap(Map<String, dynamic>.from(fixture['losingMove']));
      final defense =
          MatchMove.fromMap(Map<String, dynamic>.from(fixture['defense']));
      final old = classifyQuickLoss(game, oldMove);
      final repaired = classifyQuickLoss(game, defense);
      expect(old.attacker.name, fixture['attacker']);
      expect(repaired.attacker.name, fixture['attacker']);
      expect(old.verdict, DuelProof.proven);
      expect(repaired.verdict, DuelProof.refuted);
      final proof =
          AiDuelSafety(SearchBudget(enabled: false), cache: AiSearchCache());
      expect(
          await proof.forced(MatchRules.play(game, oldMove)!, old.attacker, 3),
          isTrue);
      expect(
          await proof.forced(MatchRules.play(game, defense)!, old.attacker, 3),
          isFalse);
    });
  }
}

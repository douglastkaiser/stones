import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/ai_position.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import '../../tools/ai_policy_check.dart' show verifyPolicy;

void main() {
  final game = MatchState.initial(MatchConfig(
      shape: BoardShape.square,
      size: 3,
      seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]));
  Map<String, dynamic> leaf(MatchState g) =>
      {'kind': 'end', 'position': aiPositionKey(g)};
  Map<String, dynamic> certificate() => {
        'kind': 'attacks',
        'position': aiPositionKey(game),
        'children': [
          for (final attack in MatchRules.legalMoves(game))
            {
              'move': attack.toMap(game.current),
              'node': (() {
                final next = MatchRules.play(game, attack)!;
                final reply = MatchRules.legalMoves(next).first;
                return {
                  'kind': 'choice',
                  'position': aiPositionKey(next),
                  'move': reply.toMap(next.current),
                  'response': {
                    'position': aiPositionKey(next),
                    'move': reply.toMap(next.current)
                  },
                  'child': leaf(MatchRules.play(next, reply)!)
                };
              })()
            }
        ]
      };

  test('policy certificate covers every attack and the actual chosen replies',
      () {
    expect(verifyPolicy(game, SeatId.ivory, 2, certificate()), isTrue);
  });
  test('incomplete or duplicated attack coverage is rejected', () {
    final missing = certificate();
    (missing['children'] as List).removeLast();
    expect(
        () => verifyPolicy(game, SeatId.ivory, 2, missing), throwsStateError);
    final duplicate = certificate();
    final children = duplicate['children'] as List;
    children.add(children.first);
    expect(
        () => verifyPolicy(game, SeatId.ivory, 2, duplicate), throwsStateError);
  });
  test('premature stopping and forged material or final-attack claims fail',
      () {
    expect(() => verifyPolicy(game, SeatId.ivory, 2, leaf(game)),
        throwsStateError);
    expect(
        () => verifyPolicy(game, SeatId.ivory, 2,
            {'kind': 'material', 'position': aiPositionKey(game)}),
        throwsStateError);
    expect(
        () => verifyPolicy(game, SeatId.ivory, 1, {
              'kind': 'last-attacks',
              'position': aiPositionKey(game),
              'winningMoves': ['invented']
            }),
        throwsStateError);
  });
  test('a different recorded worker reply cannot certify the chosen defense',
      () {
    final forged = certificate();
    final child = (forged['children'] as List).first['node'] as Map;
    child['response'] = {'position': 'invented', 'move': child['move']};
    expect(() => verifyPolicy(game, SeatId.ivory, 2, forged), throwsStateError);
  });
}

import 'package:flutter_test/flutter_test.dart';
import '../../tools/ai_strength.dart' show strengthSummary;

List<Map<String, dynamic>> games(
        {int seeds = 5,
        int players = 2,
        int wins = 6,
        int unfinished = 0,
        int draws = 0}) =>
    [
      for (var i = 0; i < seeds * players; i++)
        {
          'seed': i ~/ players,
          'rotation': i % players,
          'finished': i < seeds * players - unfinished,
          'targetWon': i < wins,
          'winner': i < wins
              ? 'ivory'
              : i < seeds * players - unfinished - draws
                  ? 'charcoal'
                  : null
        }
    ];

void main() {
  Map<String, Object?> report(List<Map<String, dynamic>> rows) =>
      strengthSummary(rows, seeds: 5, players: 2, full: false);
  test('small ordering gate rejects parity, incomplete and duplicate trials',
      () {
    expect(report(games())['passed'], isTrue);
    expect(report(games(wins: 5))['passed'], isFalse);
    expect(report(games().sublist(1))['passed'], isFalse);
    final duplicate = games()..[9] = games()[0];
    expect(report(duplicate)['passed'], isFalse);
    final wrongSeeds = games();
    wrongSeeds[0]['seed'] = -1;
    expect(report(wrongSeeds)['passed'], isFalse);
  });
  test('completion and decisive gates cannot be bypassed by a high win share',
      () {
    expect(report(games(wins: 4, unfinished: 3, draws: 3))['passed'], isFalse);
    expect(report(games(wins: 4, draws: 6))['passed'], isFalse);
    final result = report(games(unfinished: 2));
    expect(result['passed'], isTrue);
    expect(result['draws'], 0);
    expect(result['unfinished'], 2);
  });
  test('full qualification requires fifty seeds and more than sixty percent',
      () {
    expect(strengthSummary(games(), seeds: 5, players: 2, full: true)['passed'],
        isFalse);
    expect(
        strengthSummary(games(seeds: 50, wins: 60),
            seeds: 50, players: 2, full: true)['passed'],
        isFalse);
    expect(
        strengthSummary(games(seeds: 50, wins: 61),
            seeds: 50, players: 2, full: true)['passed'],
        isTrue);
  });
  test('multiplayer compares normalized per-seat shares', () {
    final result = strengthSummary(games(players: 4, wins: 8),
        seeds: 5, players: 4, full: false);
    expect(result['normalizedShare'], closeTo(2 / 3, .00001));
    expect(result['passed'], isTrue);
  });
}

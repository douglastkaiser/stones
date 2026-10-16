import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/legacy_achievement_result.dart';
import 'package:stones/game/legacy_square_adapter.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/game_state.dart';
import 'package:stones/models/board.dart';
import 'package:stones/models/online_game.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/providers/game_provider.dart';
import 'package:stones/providers/game_session_provider.dart';
import 'package:stones/services/ai/ai.dart';
import '../fixtures/achievement_matches.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final spread in [false, true]) {
    test(
        'legacy full notation history uses shared skill proof (long spread=$spread)',
        () {
      final event = roadMatch(longSpread: spread, crush: !spread);
      var position = MatchState.initial(event.game.config);
      final history = <MoveRecord>[];
      for (final record in event.moves) {
        final move = MatchMove.fromMap(record);
        final cell =
            '${String.fromCharCode(97 + move.from.x)}${5 - move.from.y}';
        final text = move.type != null
            ? '${move.type == PieceType.capstone ? 'C' : move.type == PieceType.standing ? 'S' : ''}$cell'
            : '${move.carry}$cell${switch (move.direction!.name) {
                'northWest' => '+',
                'southEast' => '-',
                'west' => '<',
                _ => '>'
              }}${move.drops.join()}';
        history.add(MoveRecord(
            notation: text,
            player: PlayerColor.values[position.current.index],
            turnNumber: position.ply ~/ 2 + 1,
            affectedPositions: {},
            stateBefore: LegacySquareAdapter.writeApplied(
                GameState.initial(5), position)));
        position = MatchRules.play(position, move)!;
      }
      final state =
          LegacySquareAdapter.writeApplied(GameState.initial(5), event.game)
              .copyWith(
                  phase: GamePhase.finished,
                  result: GameResult.whiteWins,
                  winReason: WinReason.road);
      final result = legacyAchievementResult(
          state: state,
          session: const GameSessionConfig(
              mode: GameMode.vsComputer, aiDifficulty: AIDifficulty.hard),
          history: history,
          matchId: 'legacy-game');
      expect(result!.verifiedMetrics()?['hardWins'], 1);
      expect(
          result.verifiedMetrics()?[spread ? 'spreadWins' : 'crushingWins'], 1);
      for (final creator in PlayerColor.values) {
        final online = legacyAchievementResult(
            state: state,
            session: const GameSessionConfig(mode: GameMode.online),
            history: history,
            matchId: 'legacy-game',
            room: OnlineGameSession(
                roomCode: 'ABC123',
                creatorColor: creator,
                white: const OnlineGamePlayer(
                    id: 'white-player', displayName: 'White'),
                black: const OnlineGamePlayer(
                    id: 'black-player', displayName: 'Black')));
        expect(online!.id, 'ABC123');
        expect(online.verifiedMetrics()?['onlineWins'], 1);
        expect(online.verifiedMetrics()?['hardWins'], isNull);
      }
    });
  }
  test('legacy takebacks mark the match assisted until a fresh game', () {
    final game = GameStateNotifier();
    addTearDown(game.dispose);
    final first = game.achievementMatchId;
    expect(game.placePiece(const Position(0, 0), PieceType.flat), isTrue);
    expect(game.undo(), isTrue);
    expect(game.achievementAssisted, isTrue);
    game.newGame(5);
    expect(game.achievementAssisted, isFalse);
    expect(game.achievementMatchId, isNot(first));
  });
}

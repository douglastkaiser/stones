import 'package:flutter_test/flutter_test.dart';
import 'package:stones/services/account_game_repository.dart';
import 'package:stones/providers/saved_rooms_provider.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_room.dart';

void main() {
  test('account index cannot substitute an invalid room reference', () {
    expect(() => AccountGame.fromMap({'code': 'bad', 'hex': false}, 'alice'),
        throwsFormatException);
  });
  test('unified rooms derive ownership and turn from authoritative state', () {
    final config =
        MatchConfig.defaults(BoardShape.square).copyWith(seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman),
    ]);
    final room = MatchRoom(
        code: 'UABCDEF',
        host: 'alice',
        config: config,
        owners: {SeatId.ivory: 'alice', SeatId.charcoal: 'bob'});
    final data = room.toMap();
    expect(
        describeAccountRoom(
                const SavedRoom(
                    code: 'UABCDEF', uid: 'alice', hex: false, unified: true),
                data)
            .label,
        'Your turn');
    expect(
        describeAccountRoom(
                const SavedRoom(
                    code: 'UABCDEF', uid: 'bob', hex: false, unified: true),
                data)
            .label,
        'Waiting');
    expect(
        () => describeAccountRoom(
            const SavedRoom(
                code: 'UABCDEF', uid: 'stranger', hex: false, unified: true),
            data),
        throwsStateError);
  });
  test('archiving and muting are independent account metadata', () {
    final game = AccountGame.fromMap({
      'code': 'UABCDEF',
      'hex': false,
      'unified': true,
      'archived': true,
      'muted': false
    }, 'alice');
    expect(game.archived, isTrue);
    expect(game.muted, isFalse);
    expect(game.room.uid, 'alice');
  });
}

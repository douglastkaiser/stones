import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/match_study.dart';
import 'package:stones/game/move_feedback.dart';
import 'package:stones/game/study_controller.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/services/sound_manager.dart';

import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

const flat = Stone(SeatId.ivory, PieceType.flat);
const other = Stone(SeatId.charcoal, PieceType.flat);
const cap = Stone(SeatId.ivory, PieceType.capstone);
const wall = Stone(SeatId.charcoal, PieceType.standing);

MatchConfig localConfig(BoardShape shape) =>
    MatchConfig.defaults(shape).copyWith(
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);

class RecordedSound extends SoundManager {
  final calls = <GameSound>[];
  @override
  Future<void> play(GameSound sound) async => calls.add(sound);
}

void main() {
  for (final shape in BoardShape.values) {
    test('$shape spread feedback preserves supports, ordering and cap crushing',
        () {
      final before =
          MatchState.initial(localConfig(shape)).copyWith(ply: 2, board: {
        const Cell(0, 0): [other, flat, cap],
        const Cell(1, 0): List.generate(30, (i) => i.isEven ? flat : other),
        const Cell(2, 0): [wall],
      });
      final move = MatchMove.spread(const Cell(0, 0), Step.east, [1, 1]);
      final after = MatchRules.play(before, move)!;
      final feedback = ConfirmedMoveFeedback(before, move, after);
      final landings = feedback.landings;
      expect(landings.map((l) => l.cell), [const Cell(1, 0), const Cell(2, 0)]);
      expect(landings.map((l) => l.startIndex), [30, 1]);
      expect(landings.map((l) => l.count), [1, 1]);
      expect(landings.map((l) => l.crush), [false, true]);
      expect(landings.last.delayMilliseconds, greaterThan(0));
      expect(after.stackAt(const Cell(0, 0)), [other]);
      expect(after.stackAt(const Cell(2, 0)).map((s) => s.type),
          [PieceType.flat, PieceType.capstone]);
      expect(feedback.durationMilliseconds, lessThan(450));

      final maximum = before.geometry.carryLimit;
      final tall = before.copyWith(board: {
        const Cell(0, 0): [other, ...List.filled(maximum, flat)],
        const Cell(1, 0): [other],
      });
      final maximumMove =
          MatchMove.spread(const Cell(0, 0), Step.east, [maximum]);
      final maximumFeedback = ConfirmedMoveFeedback(
          tall, maximumMove, MatchRules.play(tall, maximumMove)!);
      expect(maximumFeedback.landings.single.startIndex, 1);
      expect(maximumFeedback.landings.single.count, maximum);
    });

    test('$shape only durable successful moves publish feedback', () async {
      final storage = MemoryMatchStorage();
      final controller = MatchController(
          storage: storage,
          authenticate: () async => 'test',
          store: MemoryMatchRoomStore.new);
      addTearDown(controller.dispose);
      await controller.start(localConfig(shape));
      final before = controller.state.game!;
      final move = MatchMove.place(const Cell(0, 0), PieceType.flat);
      storage.failWrites = true;
      expect(await controller.play(move), false);
      expect(controller.state.moveFeedback, isNull);
      storage.failWrites = false;
      expect(await controller.play(move), true);
      final batch = controller.state.moveFeedback!;
      expect(batch.moves.single.before, same(before));
      expect(batch.moves.single.after, same(controller.state.game));
      expect(batch.moves.single.move, same(move));
      expect(await controller.play(move), false); // Occupied cell.
      expect(controller.state.moveFeedback, same(batch));
      final restored = MatchController(
          storage: storage,
          authenticate: () async => 'test',
          store: MemoryMatchRoomStore.new);
      addTearDown(restored.dispose);
      expect(await restored.resumeLocal(), true);
      expect(restored.state.game!.ply, 1);
      expect(restored.state.moveFeedback, isNull);
    });
  }

  test('AI moves use the same confirmed feedback path', () async {
    final controller = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'test',
        store: MemoryMatchRoomStore.new,
        botDelay: const Duration(days: 1));
    addTearDown(controller.dispose);
    await controller
        .start(localConfig(BoardShape.square).copyWith(seats: const [
      SeatConfig(SeatId.ivory, control: SeatControl.ai),
      SeatConfig(SeatId.charcoal),
    ]));
    expect(
        await controller.play(MatchMove.place(const Cell(0, 0), PieceType.flat),
            bot: true),
        true);
    expect(controller.state.moveFeedback!.moves.single.before.current,
        SeatId.ivory);
  });

  test(
      'online confirmation emits once; duplicates and reconnect catch-up are silent',
      () async {
    final store = MemoryMatchRoomStore();
    final controller = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'host',
        store: () => store);
    addTearDown(controller.dispose);
    addTearDown(store.updates.close);
    await controller
        .start(localConfig(BoardShape.square).copyWith(seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman),
    ]));
    await store.join('UABCDEF', 'guest');
    expect(controller.state.moveFeedback, isNull);
    await controller.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    final first = controller.state.moveFeedback!;
    store.updates.add(store.room!);
    expect(controller.state.moveFeedback, same(first));
    await store.submit('UABCDEF', 'guest', 1,
        MatchMove.place(const Cell(1, 0), PieceType.flat));
    final second = controller.state.moveFeedback!;
    expect(second.token, isNot(first.token));
    expect(second.moves.single.before.ply, 1);
    await controller.play(MatchMove.place(const Cell(0, 1), PieceType.flat));
    final latest = controller.state.moveFeedback;
    store.publishOnSubmit = false;
    await store.submit('UABCDEF', 'guest', 3,
        MatchMove.place(const Cell(1, 1), PieceType.flat));
    expect(await controller.reconnect(), true);
    expect(controller.state.game!.ply, 4);
    expect(controller.state.moveFeedback, same(latest));
  });

  test('learning batches the learner move and automatic replies in order',
      () async {
    final initial =
        MatchState.initial(localConfig(BoardShape.square)).copyWith(ply: 2);
    final controller = StudyController(MatchStudy(
      id: 'feedback',
      title: 'Feedback',
      goal: 'Continue',
      explanation: '',
      initial: initial,
      puzzle: true,
      moveLimit: 2,
      accepts: (_, step) => true,
      replies: (_) => [MatchMove.place(const Cell(1, 0), PieceType.flat)],
      hints: const [],
    ));
    addTearDown(controller.dispose);
    expect(
        await controller
            .play(MatchMove.place(const Cell(0, 0), PieceType.flat)),
        true);
    final batch = controller.state.moveFeedback!;
    expect(batch.moves.length, 2);
    expect(batch.moves.map((m) => m.before.ply), [2, 3]);
    expect(batch.moves.last.after, same(controller.state.game));
    controller.reset();
    expect(controller.state.moveFeedback, isNull);
    await controller.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    expect(controller.state.moveFeedback!.token, isNot(batch.token));
  });

  test('landing material mapping retains board and owner theme choices',
      () async {
    final sound = RecordedSound();
    await sound.playLanding(BoardTheme.kyoto);
    await sound.playLanding(BoardTheme.morocco);
    await sound.playLanding(BoardTheme.celestial);
    await sound.playLanding(BoardTheme.classicWood,
        stackStyle: PieceStyle.polishedMarble, heavy: true);
    await sound.playLanding(BoardTheme.marble,
        stackStyle: PieceStyle.morocco, heavy: true);
    await sound.playLanding(BoardTheme.darkStone,
        stackStyle: PieceStyle.kyoto, heavy: true);
    expect(sound.calls, [
      GameSound.landingWood,
      GameSound.landingStone,
      GameSound.landingMarble,
      GameSound.landingMarbleHeavy,
      GameSound.landingStoneHeavy,
      GameSound.landingWoodHeavy
    ]);
  });
}

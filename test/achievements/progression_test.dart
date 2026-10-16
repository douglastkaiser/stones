import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/match_completed.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/study_catalog.dart';
import 'package:stones/models/achievement.dart';
import 'package:stones/providers/achievements_provider.dart';
import 'package:stones/providers/cosmetics_provider.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../fixtures/achievement_matches.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'catalog has unique stable IDs, attainable targets and genuine long-term goals',
      () {
    expect(achievements.length, 25);
    expect(achievements.map((a) => a.type).toSet(),
        AchievementType.values.toSet());
    const state = AchievementState();
    for (final a in achievements) {
      expect(a.points, greaterThan(0));
      expect(a.requirements, isNotEmpty);
      for (final r in a.requirements) {
        expect(state.target(r), greaterThan(0));
      }
    }
    expect(
        GameAchievement.forType(AchievementType.grandmaster)
            .requirements
            .length,
        2);
    expect(
        GameAchievement.forType(AchievementType.seasoned)
            .requirements
            .last
            .target,
        10);
    expect(AchievementState.puzzleIds(BoardShape.hex).length,
        greaterThanOrEqualTo(3));
  });
  for (final shape in BoardShape.values) {
    for (var count = 2; count <= 4; count++) {
      test('$shape $count legal full histories earn shared skill metrics',
          () async {
        final awards = AchievementNotifier();
        addTearDown(awards.dispose);
        final event = roadMatch(shape: shape, count: count, capstone: true);
        await awards.recordMatch(event);
        expect(awards.state.totalWins, 1);
        expect(awards.state.metrics['roadWins'], 1);
        expect(awards.state.metrics['capRoadWins'], 1);
        expect(
            awards.state.metrics[
                shape == BoardShape.square ? 'squareHardWins' : 'hexHardWins'],
            1);
        if (count == 3) {
          expect(awards.state.metrics['threeHardWins'], 1);
        }
        if (count == 4) {
          expect(awards.state.metrics['fourHardWins'], 1);
        }
        expect(awards.state.metrics['hardWins'],
            shape == BoardShape.square && count == 2 ? 1 : null);
      });
    }
  }
  test(
      'Expert victories advance all AI tiers; a single win cannot unlock any duel reward',
      () async {
    final awards = AchievementNotifier();
    addTearDown(awards.dispose);
    await awards.recordMatch(roadMatch(level: BotLevel.expert));
    for (final metric in ['easyWins', 'mediumWins', 'hardWins', 'expertWins']) {
      expect(awards.state.metrics[metric], 1);
    }
    expect(awards.state.unlockedAchievements, isEmpty);
    for (var i = 1; i < 12; i++) {
      await awards
          .recordMatch(roadMatch(id: 'expert-$i', level: BotLevel.expert));
    }
    expect(awards.state.isUnlocked(AchievementType.firstSteps), isTrue);
    expect(awards.state.isUnlocked(AchievementType.competitor), isTrue);
    expect(awards.state.isUnlocked(AchievementType.strategist), isTrue);
    expect(awards.state.isUnlocked(AchievementType.grandmaster), isFalse);
    await awards.recordMatch(
        roadMatch(id: 'expert-large', level: BotLevel.expert, size: 6));
    expect(awards.state.isUnlocked(AchievementType.grandmaster), isTrue);
    expect(awards.state.tags['expertSizes'], {'5', '6'});
    expect(awards.state.earnedAt[AchievementType.grandmaster], isNotNull);
  });
  test('every opponent must meet the difficulty threshold', () async {
    final awards = AchievementNotifier();
    addTearDown(awards.dispose);
    await awards.recordMatch(roadMatch(
        shape: BoardShape.hex,
        count: 4,
        levels: [
          BotLevel.expert,
          BotLevel.hard,
          BotLevel.easy,
          BotLevel.expert
        ]));
    expect(awards.state.totalWins, 1);
    expect(awards.state.metrics['fourHardWins'], isNull);
    expect(awards.state.metrics['hexHardWins'], isNull);
    expect(awards.state.metrics['roadWins'], isNull);
  });
  test(
      'winning wall crush is established by replay, not a final capstone alone',
      () async {
    final awards = AchievementNotifier();
    addTearDown(awards.dispose);
    await awards.recordMatch(roadMatch(id: 'crush', crush: true));
    expect(awards.state.metrics['crushingWins'], 1);
    expect(awards.state.metrics['capRoadWins'], 1);
    await awards.recordMatch(roadMatch(id: 'cap', capstone: true));
    expect(awards.state.metrics['capRoadWins'], 2);
    expect(awards.state.metrics['crushingWins'], 1);
  });
  test(
      'streaks count qualified duels, survive unrelated practice, reset on real losses',
      () async {
    final awards = AchievementNotifier();
    addTearDown(awards.dispose);
    for (var i = 0; i < 4; i++) {
      await awards.recordMatch(roadMatch(id: 'win-$i'));
    }
    await awards.recordMatch(roadMatch(id: 'court', court: true));
    expect(awards.state.metrics['hardStreak'], 4);
    await awards.recordMatch(roadMatch(id: 'loss', human: SeatId.charcoal));
    expect(awards.state.metrics['hardStreak'], 0);
    expect(awards.state.metrics['bestHardStreak'], 4);
    for (var i = 0; i < 5; i++) {
      await awards.recordMatch(roadMatch(id: 'comeback-$i'));
    }
    expect(awards.state.isUnlocked(AchievementType.winningStreak), isTrue);
    expect(awards.state.totalWins, 9);
  });
  test(
      'online milestones need real opponent variety; AI tiers are not borrowed',
      () async {
    final awards = AchievementNotifier();
    addTearDown(awards.dispose);
    for (var i = 0; i < 5; i++) {
      await awards.recordMatch(roadMatch(id: 'online-$i', online: true));
    }
    expect(awards.state.onlineWins, 5);
    expect(awards.state.isUnlocked(AchievementType.connected), isFalse);
    expect(awards.state.metrics['expertWins'], isNull);
    await awards.recordMatch(
        roadMatch(id: 'friend2', online: true, opponent: 'friend2'));
    await awards.recordMatch(
        roadMatch(id: 'friend3', online: true, opponent: 'friend3'));
    expect(awards.state.isUnlocked(AchievementType.connected), isTrue);
    expect(awards.state.tags['opponents']!.length, 3);
  });
  test(
      'duplicate callbacks, completion metadata changes and restart never count twice',
      () async {
    final awards = AchievementNotifier();
    addTearDown(awards.dispose);
    final event = roadMatch(id: 'stable-room', online: true);
    await Future.wait(List.generate(12, (_) => awards.recordMatch(event)));
    expect(awards.state.totalWins, 1);
    final fresh = AchievementNotifier();
    addTearDown(fresh.dispose);
    await fresh.load();
    await fresh.recordMatch(event);
    expect(fresh.state.totalWins, 1);
    final changed = MatchCompleted(
        MatchSession(
          id: 'stable-room',
          game: event.game.copyWith(
              result:
                  const MatchResult(SeatId.ivory, ResultReason.resignation)),
        ),
        moves: event.moves);
    await fresh.recordMatch(changed);
    expect(fresh.state.totalWins, 1);
  });
  test('missing, rewritten and fabricated winning histories earn nothing',
      () async {
    final awards = AchievementNotifier();
    addTearDown(awards.dispose);
    final event = roadMatch();
    await awards.recordMatch(
        MatchCompleted(MatchSession(id: 'missing', game: event.game)));
    final bad = event.moves.map((m) => Map<String, dynamic>.from(m)).toList();
    bad.first['seat'] = 'charcoal';
    await awards.recordMatch(MatchCompleted(
        MatchSession(id: 'wrong-turn', game: event.game),
        moves: bad));
    final invented = event.game.copyWith(
        result: const MatchResult(SeatId.charcoal, ResultReason.road));
    await awards.recordMatch(MatchCompleted(
        MatchSession(id: 'invented', game: invented),
        moves: event.moves));
    expect(awards.state.totalWins, 0);
  });
  test(
      'timed road wins count; timeouts do not grant craft or specialist awards',
      () async {
    final awards = AchievementNotifier();
    addTearDown(awards.dispose);
    await awards.recordMatch(roadMatch(clockSeconds: 60));
    expect(awards.state.metrics['timedWins'], 1);
    final event = roadMatch(id: 'timeout', clockSeconds: 60);
    // A terminal board cannot be relabeled as a clock ending to grant an award.
    final fake = MatchCompleted(
        MatchSession(
            id: 'fake',
            game: event.game.copyWith(
                result: const MatchResult(SeatId.ivory, ResultReason.time))),
        moves: event.moves);
    await awards.recordMatch(fake);
    expect(awards.state.metrics['timedWins'], 1);
  });
  test('concurrent load, lessons and games retain every durable update',
      () async {
    final awards = AchievementNotifier();
    addTearDown(awards.dispose);
    final lessons = AchievementState.allTutorialIds.take(3).toList();
    final puzzle = AchievementState.allPuzzleIds.first;
    await Future.wait<dynamic>([
      awards.load(),
      for (final id in lessons) awards.completeTutorial(id),
      awards.completePuzzle(puzzle, unassisted: true),
      awards.recordMatch(roadMatch())
    ]);
    final fresh = AchievementNotifier();
    addTearDown(fresh.dispose);
    await fresh.load();
    expect(fresh.state.completedTutorials, containsAll(lessons));
    expect(fresh.state.completedPuzzles, contains(puzzle));
    expect(fresh.state.unaidedPuzzles, contains(puzzle));
    expect(fresh.state.totalWins, 1);
  });
  test('failed durable write cannot publish a win and can be retried once',
      () async {
    var fail = false;
    final awards = AchievementNotifier(preferences: () async {
      if (fail) {
        throw StateError('Disk full');
      }
      return SharedPreferences.getInstance();
    });
    addTearDown(awards.dispose);
    await awards.load();
    final event = roadMatch();
    fail = true;
    await expectLater(awards.recordMatch(event), throwsStateError);
    expect(awards.state.totalWins, 0);
    expect(awards.state.storageError, isNotNull);
    fail = false;
    await awards.recordMatch(event);
    await awards.recordMatch(event);
    expect(awards.state.totalWins, 1);
    expect(awards.state.storageError, isNull);
  });
  test('corrupt and future saves are preserved, never silently overwritten',
      () async {
    final prefs = await SharedPreferences.getInstance();
    for (final payload in [
      '{broken',
      jsonEncode({'version': 99})
    ]) {
      await prefs.setString(AchievementKeys.progression, payload);
      final awards = AchievementNotifier();
      await awards.load();
      expect(awards.state.loaded, isFalse);
      expect(awards.state.storageError, isNotNull);
      await expectLater(awards.recordMatch(roadMatch()), throwsA(anything));
      expect(prefs.getString(AchievementKeys.progression), payload);
      awards.dispose();
    }
  });
  test(
      'migration preserves earned rewards and learning without fabricating mastery evidence',
      () async {
    final hex = matchStudies.firstWhere((s) => s.legacyHex && s.puzzle);
    final unified = matchStudies
        .firstWhere((s) => s.id.startsWith('unified_v1_') && !s.puzzle);
    SharedPreferences.setMockInitialValues({
      AchievementKeys.winLedger: jsonEncode({
        'totalWins': 50,
        'onlineWins': 4,
        'matches': ['old-room:11:road'],
        'unlocks': ['grandmaster', 'connected', 'future-name']
      }),
      '${AchievementKeys.prefix}student': true,
      hexLearningProgressKey: [hex.id],
      unifiedLearningProgressKey: [unified.id],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final awards = container.read(achievementProvider.notifier);
    await awards.load();
    expect(awards.state.totalWins, 50);
    expect(awards.state.metrics['expertWins'], isNull);
    expect(awards.state.unaidedPuzzles, isEmpty);
    expect(awards.state.completedPuzzles, contains(hex.id));
    expect(awards.state.completedTutorials, contains(unified.id));
    expect(awards.state.legacyUnlocks, contains(AchievementType.grandmaster));
    expect(container.read(shareableBoardThemeProvider), BoardTheme.classicWood);
    expect(container.read(isBoardThemeUnlockedProvider(BoardTheme.marble)),
        isTrue);
    expect(await awards.recordMatch(roadMatch(id: 'old-room')), isEmpty);
    expect(awards.state.totalWins, 50);
    await awards.completeTutorial(AchievementState.allTutorialIds.first);
    final fresh = AchievementNotifier();
    addTearDown(fresh.dispose);
    await fresh.load();
    expect(fresh.state.legacyUnlocks, contains(AchievementType.grandmaster));
  });
  test(
      'unknown lesson IDs never advance learning and hinted solves can later gain unaided credit',
      () async {
    final awards = AchievementNotifier();
    addTearDown(awards.dispose);
    await awards.completeTutorial('fake');
    await awards.completePuzzle('fake', unassisted: true);
    expect(awards.state.completedTutorials, isEmpty);
    expect(awards.state.completedPuzzles, isEmpty);
    final id = AchievementState.allPuzzleIds.first;
    await awards.completePuzzle(id);
    expect(awards.state.unaidedPuzzles, isEmpty);
    await awards.completePuzzle(id, unassisted: true);
    expect(awards.state.completedPuzzles.length, 1);
    expect(awards.state.unaidedPuzzles, {id});
  });
  test(
      'all newly earned notifications and dates persist until acknowledged; reset stays reset',
      () async {
    final awards = AchievementNotifier();
    addTearDown(awards.dispose);
    for (var i = 0; i < 5; i++) {
      await awards
          .recordMatch(roadMatch(id: 'notify-$i', level: BotLevel.expert));
    }
    expect(awards.state.pending.length, greaterThanOrEqualTo(3));
    final fresh = AchievementNotifier();
    addTearDown(fresh.dispose);
    await fresh.load();
    expect(fresh.state.pending, awards.state.pending);
    expect(fresh.state.earnedAt, awards.state.earnedAt);
    await fresh.acknowledgeUnlocks([fresh.state.pending.first]);
    expect(fresh.state.pending.length, awards.state.pending.length - 1);
    await fresh.resetAll();
    final again = AchievementNotifier();
    addTearDown(again.dispose);
    await again.load();
    expect(again.state.totalWins, 0);
    expect(again.state.unlockedAchievements, isEmpty);
  });
  test('a verified draw resets the hard-duel streak without adding wins', () async {
    final awards=AchievementNotifier();addTearDown(awards.dispose);
    await awards.recordMatch(roadMatch());
    await awards.recordMatch(drawnHardDuel());
    expect(awards.state.metrics['hardStreak'],0);
    expect(awards.state.metrics['bestHardStreak'],1);
    expect(awards.state.totalWins,1);
  });
  test('online resignations count only after four cycles and never grant board craft', () async {
    final event=roadMatch(online:true);
    final awards=AchievementNotifier();addTearDown(awards.dispose);
    for(final length in [2,8]) {
      var room=MatchRoom(code:length==2 ? 'UEARLYA' : 'ULATERA',host:'player',config:event.game.config,
        owners:event.owners!,moves:event.moves.take(length).toList());
      room=room.resign('opponent-1',SeatId.charcoal);
      await awards.recordMatch(MatchCompleted(MatchSession(id:room.code,uid:'player',room:room,
        game:room.replay()),moves:room.moves));
      expect(awards.state.totalWins,length==2 ? 0 : 1);
    }
    expect(awards.state.onlineWins,1);
    expect(awards.state.metrics['roadWins'],isNull);
  });
  test('shared accounts, spectators and tiny Square boards cannot farm progress', () async {
    final awards=AchievementNotifier();addTearDown(awards.dispose);
    final event=roadMatch(online:true,count:3);
    final config=event.game.config.copyWith(seats:const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal), SeatConfig(SeatId.copper,control:SeatControl.onlineHuman)]);
    final room=MatchRoom(code:'USHARED',host:'player',config:config,
      owners:const {SeatId.ivory:'player',SeatId.charcoal:'player',SeatId.copper:'friend'},moves:event.moves);
    await awards.recordMatch(MatchCompleted(MatchSession(id:'shared',uid:'player',room:room,
      game:room.replay()),moves:room.moves));
    await awards.recordMatch(MatchCompleted(MatchSession(id:'observer',uid:'observer',room:room,
      game:event.game),moves:event.moves));
    await awards.recordMatch(roadMatch(id:'tiny',size:3));
    expect(awards.state.totalWins,0);
  });

  test('every achievement is reachable through verified games and known learning completions', () async {
    final awards=AchievementNotifier();addTearDown(awards.dispose);
    var id=0;
    Future<void> win(MatchCompleted event) async { await awards.recordMatch(event); }
    for(var i=0;i<12;i++) { await win(roadMatch(id:'all-${id++}',level:BotLevel.expert,size:i==11 ? 6 : 5)); }
    for(var i=0;i<5;i++) { await win(roadMatch(id:'all-${id++}',clockSeconds:60)); }
    for(var i=0;i<10;i++) { await win(drawnHardDuel(id:'all-${id++}',flatWin:true)); }
    for(var count=3;count<=4;count++) {
      for(var i=0;i<5;i++) { await win(roadMatch(id:'all-${id++}',shape:BoardShape.hex,count:count)); }
    }
    for(var i=0;i<5;i++) { await win(roadMatch(id:'all-${id++}',size:7)); }
    for(var i=0;i<5;i++) { await win(roadMatch(id:'all-${id++}',crush:true)); }
    for(var i=0;i<5;i++) { await win(roadMatch(id:'all-${id++}',longSpread:true)); }
    for(var i=0;i<25;i++) { await win(roadMatch(id:'all-${id++}',online:true,opponent:'friend-${i%10}')); }
    while(awards.state.totalWins<100) { await win(roadMatch(id:'all-${id++}')); }
    for(final lesson in AchievementState.allTutorialIds) { await awards.completeTutorial(lesson); }
    for(final puzzle in AchievementState.allPuzzleIds) { await awards.completePuzzle(puzzle,unassisted:true); }
    expect(awards.state.unlockedAchievements,AchievementType.values.toSet());
    expect(awards.state.earnedAt.length,25);
    expect(awards.state.rank,'Legend');
    final fresh=AchievementNotifier();addTearDown(fresh.dispose);await fresh.load();
    expect(fresh.state.unlockedAchievements,awards.state.unlockedAchievements);
    expect(fresh.state.points,awards.state.points);
  });

  test('an online-hosted AI duel earns the same AI progress without inventing a human online win', () async {
    final base=roadMatch(level:BotLevel.expert);
    final config=base.game.config.copyWith(seats:const [
      SeatConfig(SeatId.ivory,control:SeatControl.onlineHuman),
      SeatConfig(SeatId.charcoal,control:SeatControl.ai,level:BotLevel.expert)]);
    final room=MatchRoom(code:'UHOSTAI',host:'observer',config:config,
      owners:const {SeatId.ivory:'guest',SeatId.charcoal:null},moves:base.moves);
    final event=MatchCompleted(MatchSession(id:room.code,uid:'guest',room:room,
      game:room.replay()),moves:room.moves);
    final awards=AchievementNotifier();addTearDown(awards.dispose);
    await awards.recordMatch(event);
    expect(awards.state.totalWins,1);expect(awards.state.onlineWins,0);
    expect(awards.state.metrics['expertWins'],1);
    expect(awards.state.metrics['hardStreak'],1);
  });

}

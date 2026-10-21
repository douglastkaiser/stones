import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/main.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/providers/account_provider.dart';
import 'package:stones/providers/achievements_provider.dart';
import 'package:stones/services/sound_manager.dart';
import 'fixtures/achievement_matches.dart';
import 'support/fake_account_service.dart';

class _SilentSound extends SoundManager {
  @override
  Future<void> playAchievementUnlock() async {}
}

void main() {
  testWidgets('achievement acknowledgement keeps app listeners in build',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final awards = AchievementNotifier();
    for (var i = 0; i < 5; i++) {
      await awards
          .recordMatch(roadMatch(id: 'notice-$i', level: BotLevel.expert));
    }
    expect(awards.state.pending, isNotEmpty);
    await tester.pumpWidget(ProviderScope(overrides: [
      accountServiceProvider.overrideWithValue(FakeAccount()),
      soundManagerProvider.overrideWithValue(_SilentSound()),
      achievementProvider.overrideWith((_) => awards),
    ], child: const StonesApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(awards.state.pending, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

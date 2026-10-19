import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/rating_submission.dart';
import 'package:stones/game/result_share_dialog.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/providers/account_provider.dart';
import 'package:stones/services/result_share_service.dart';
import '../fixtures/achievement_matches.dart';
import '../support/fake_account_service.dart';

class FakeShareService extends ResultShareService {
  String? text;
  Uint8List? image;
  ResultShareOutcome outcome = ResultShareOutcome.cancelled;
  @override
  Future<ResultShareOutcome> share(String text,
      {Uint8List? png, ui.Rect? origin}) async {
    this.text = text;
    image = png;
    return outcome;
  }

  @override
  Future<bool> sms(String text) async {
    this.text = text;
    return false;
  }
}

void main() {
  Future<void> showShare(WidgetTester tester, FakeShareService service,
      {BoardShape shape = BoardShape.square}) async {
    final event = roadMatch(shape: shape, count: 3);
    final account =
        AccountController(FakeAccount(), hasActiveRoom: () => false);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          accountProvider.overrideWith((ref) => account),
          resultShareServiceProvider.overrideWithValue(service),
          ratingStatusProvider.overrideWith((ref) => (
                event.id,
                const RatingSubmission(
                    RatingSubmissionState.confirmed, 'Rating recorded',
                    deltas: {SeatId.ivory: RatingDelta(1200, 1206)},
                    formatDeltas: {SeatId.ivory: RatingDelta(1200, 1210)},
                    skillBased: true)
              )),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => ResultShareDialog(
                                session: MatchSession(
                                    game: event.game, id: event.id),
                                styles: const {},
                                boardTheme: BoardTheme.classicWood)),
                        child: const Text('Open result')))))));
    await tester.tap(find.text('Open result'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'cancelled native sharing keeps the preview and both skill deltas',
      (tester) async {
    final service = FakeShareService();
    await showShare(tester, service);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(service.text, contains('Overall +6 · Format +10'));
    expect(find.text('Share result'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'unsupported sharing and SMS offer the exact text on the clipboard',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final service = FakeShareService()
      ..outcome = ResultShareOutcome.unsupported;
    await showShare(tester, service);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(copied, service.text);
    expect(copied, contains('Play: https://www.douglastkaiser.com/stones/'));
    await tester.tap(find.text('Text message'));
    await tester.pumpAndSettle();
    expect(copied, service.text);
    expect(tester.takeException(), isNull);
  });
  for (final shape in BoardShape.values) {
    testWidgets('$shape board exports a clean PNG in a phone share dialog',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeShareService();
      await showShare(tester, service, shape: shape);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      // Raster conversion runs outside the fake clock used for widget frames.
      for (var i = 0;
          i < 20 && find.text('Preparing board image…').evaluate().isNotEmpty;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pumpAndSettle();
      }
      expect(find.text('Preparing board image…'), findsNothing);
      expect(find.textContaining('Could not prepare'), findsNothing);
      final share = find.widgetWithText(FilledButton, 'Share');
      await tester.ensureVisible(share);
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(service.image, isNotNull);
      expect(
          service.image!.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(tester.takeException(), isNull);
    });
  }
}

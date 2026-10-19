import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/screens/about_screen.dart';
import 'package:stones/screens/feedback_screen.dart';
import 'package:stones/services/feedback_service.dart';

FeedbackReport report({bool includeDetails = true}) => FeedbackReport(
    kind: FeedbackKind.problem,
    summary: 'Road & cap + café?\nNew line',
    description: 'I tried a spread.\nIt stopped & I expected a move.',
    appDetails: 'Version: test\nPlatform: Web (android)',
    includeAppDetails: includeDetails);

Future<void> fillReport(WidgetTester tester) async {
  await tester.enterText(
      find.byType(TextFormField).at(0), 'Cannot move a stack');
  await tester.enterText(find.byType(TextFormField).at(1),
      'I selected two stones. Confirm did not make the move.');
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  test('email draft safely encodes text and contains only selected diagnostics',
      () {
    final draft = report();
    expect(draft.emailUri.scheme, 'mailto');
    expect(draft.emailUri.path, FeedbackReport.recipient);
    expect(draft.emailUri.queryParameters['subject'], draft.subject);
    expect(draft.emailUri.queryParameters['body'], draft.body);
    expect(draft.subject.contains('\n'), isFalse);
    expect(draft.emailUri.query.contains('+'), isFalse);
    expect(report(includeDetails: false).body.contains('Version:'), isFalse);
    expect(FeedbackReport.currentAppDetails(), startsWith('Version:'));
    expect(FeedbackReport.currentAppDetails(), isNot(contains('room=')));
  });

  test('missing email handler and launcher exceptions are recoverable',
      () async {
    expect(await FeedbackService(openDraft: (_) async => false).open(report()),
        isFalse);
    expect(
        await FeedbackService(
            openDraft: (_) async => throw StateError('missing')).open(report()),
        isFalse);
  });

  testWidgets('empty report stays in app and explains required fields',
      (tester) async {
    var opens = 0;
    await tester.pumpWidget(MaterialApp(
        home: FeedbackScreen(service: FeedbackService(openDraft: (_) async {
      opens++;
      return true;
    }))));
    await tapVisible(tester, 'Open email draft');
    expect(opens, 0);
    expect(find.text('Add a short summary.'), findsOneWidget);
    expect(find.text('Add a few details so we can help.'), findsOneWidget);
  });

  testWidgets('draft omits unchecked diagnostics and never claims delivery',
      (tester) async {
    Uri? opened;
    await tester.pumpWidget(MaterialApp(
        home: FeedbackScreen(service: FeedbackService(openDraft: (uri) async {
      opened = uri;
      return true;
    }))));
    await fillReport(tester);
    await tapVisible(tester, 'Include app details');
    await tapVisible(tester, 'Open email draft');
    expect(opened!.queryParameters['body'], contains('I selected two stones'));
    expect(opened!.queryParameters['body'], isNot(contains('Version:')));
    expect(find.textContaining('Finish sending in your email app'),
        findsOneWidget);
    expect(find.text('Feedback sent'), findsNothing);
  });

  testWidgets('failed launch retains text and copy fallback exports the report',
      (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
        home: FeedbackScreen(
            service: FeedbackService(openDraft: (_) async => false))));
    await fillReport(tester);
    await tapVisible(tester, 'Open email draft');
    expect(
        find.textContaining('Could not open an email draft'), findsOneWidget);
    expect(find.text('Cannot move a stack'), findsOneWidget);
    await tapVisible(tester, 'Copy report');
    expect(clipboard, contains('To: ${FeedbackReport.recipient}'));
    expect(clipboard, contains('Cannot move a stack'));
    expect(clipboard, contains('Version:'));
    expect(find.textContaining('Report copied.'), findsOneWidget);
  });

  testWidgets('compact large-text screen can preview and copy without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: const FeedbackScreen()));
    await fillReport(tester);
    await tapVisible(tester, 'Preview report');
    expect(find.textContaining('Subject: [Stones feedback]'), findsOneWidget);
    await tester.ensureVisible(find.text('Copy report'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('feedback is reachable from About without account initialization',
      (tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AboutScreen())));
    await tester.scrollUntilVisible(find.text('Send feedback'), 300);
    await tester.ensureVisible(find.text('Send feedback'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(find.text('Help improve Stones'), findsOneWidget);
  });
}

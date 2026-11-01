import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/screens/about_screen.dart';
import 'package:stones/services/sharing_kit_url.dart';

void main() {
  test('kit URLs retain production or preview root and discard room parameters',
      () {
    expect(sharingKitUrl().toString(),
        'https://www.douglastkaiser.com/stones/share/');
    for (final root in ['stones/', 'stones/pr/123/']) {
      expect(
          sharingKitUrl(
              webBase:
                  Uri.parse('https://example.org/$root?room=private#about')),
          Uri.parse('https://example.org/${root}share/'));
    }
  });

  for (final outcome in ['success', 'declined', 'exception']) {
    testWidgets('About kit launch handles $outcome without leaving About',
        (tester) async {
      String? launched;
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'launch') {
          launched = (call.arguments as Map)['url'] as String;
          if (outcome == 'exception') {
            throw PlatformException(code: 'unavailable');
          }
          return outcome == 'success';
        }
        return true;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: AboutScreen())));
      final target = find.text('Get the Stones sharing kit');
      await tester.scrollUntilVisible(target, 300);
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(launched, 'https://www.douglastkaiser.com/stones/share/');
      expect(find.byType(AboutScreen), findsOneWidget);
      expect(find.text('Could not open the sharing kit. Please try again.'),
          outcome == 'success' ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/services/match_chat_service.dart';
import 'package:stones/widgets/match_chat.dart';

class _Chat extends MatchChatService {
  _Chat() : super('room', 'uid');
  int cleanups = 0, receives = 0, finishes = 0;
  bool closed = false, failCleanup = false, failReceive = false;
  List<ChatMessage> messages = [];
  @override
  Future<void> cleanup({bool finished = false}) async {
    cleanups++;
    if (finished) finishes++;
    if (failCleanup) throw StateError('offline');
  }

  @override
  Future<List<ChatMessage>> receive() async {
    receives++;
    if (failReceive) throw StateError('offline');
    return messages;
  }

  @override
  void dispose() {
    closed = true;
    super.dispose();
  }
}

void main() {
  testWidgets(
      'quiet polls avoid rebuilds but preserve updates, recovery and expiry',
      (tester) async {
    final chat = _Chat();
    final now = DateTime.now();
    chat.messages = [
      ChatMessage('1', 'uid', 'hello', now, now.add(const Duration(minutes: 5)))
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MatchChat(
                room: 'room',
                uid: 'uid',
                names: const {'uid': 'Alice'},
                serviceFactory: (_, __) => chat))));
    await tester.tap(find.text('Game chat'));
    await tester.pumpAndSettle();
    var builds = 0;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.widget is MatchChat) builds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    await tester.pump(const Duration(seconds: 3));
    expect(builds, 0);
    expect(find.text('Alice: hello'), findsOneWidget);
    chat.failReceive = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Chat unavailable. Retrying…'), findsOneWidget);
    builds = 0;
    await tester.pump(const Duration(seconds: 3));
    expect(builds, 0);
    chat.failReceive = false;
    chat.messages = [
      ChatMessage(
          '1', 'uid', 'updated', now, now.add(const Duration(minutes: 5)))
    ];
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Alice: updated'), findsOneWidget);
    expect(find.text('Chat unavailable. Retrying…'), findsNothing);
    chat.messages = [
      ChatMessage('expired', 'uid', 'temporary', now,
          now.subtract(const Duration(seconds: 1)))
    ];
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    chat.messages = [];
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Alice: temporary'), findsNothing);
    expect(find.text('Alice: updated'), findsOneWidget);
    debugOnRebuildDirtyWidget = null;
    await tester.pumpWidget(const SizedBox());
    expect(chat.closed, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'collapsed chat cleans expiry IDs without polling messages; finish and dispose stop timers',
      (tester) async {
    final chat = _Chat();
    Widget view({bool finished = false}) => MaterialApp(
        home: Scaffold(
            body: MatchChat(
                room: 'room',
                uid: 'uid',
                names: const {},
                finished: finished,
                serviceFactory: (room, uid) => chat)));
    await tester.pumpWidget(view());
    expect(chat.cleanups, 1);
    await tester.pump(const Duration(seconds: 31));
    expect(chat.cleanups, 2);
    expect(chat.receives, 0);
    // Failed cleanup is contained and retried with the panel still collapsed.
    chat.failCleanup = true;
    await tester.pump(const Duration(seconds: 30));
    chat.failCleanup = false;
    await tester.pump(const Duration(seconds: 30));
    expect(chat.cleanups, 4);
    await tester.tap(find.text('Game chat'));
    await tester.pumpAndSettle();
    expect(chat.receives, 1);
    await tester.tap(find.text('Game chat'));
    await tester.pumpAndSettle();
    final receives = chat.receives;
    await tester.pump(const Duration(seconds: 31));
    expect(chat.receives, receives);
    expect(chat.cleanups, 5);
    await tester.pumpWidget(view(finished: true));
    await tester.pump();
    expect(chat.finishes, 1);
    final cleanups = chat.cleanups;
    await tester.pump(const Duration(minutes: 1));
    expect(chat.cleanups, cleanups);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(chat.closed, true);
    await tester.pump(const Duration(minutes: 1));
    expect(chat.cleanups, cleanups);
    expect(tester.takeException(), isNull);
  });
}

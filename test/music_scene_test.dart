import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/services/music_service.dart';
import 'package:stones/widgets/music_scene.dart';

void main() {
  testWidgets('pages, dialogs, cue changes and pop restore the visible music',
      (tester) async {
    final director = MusicDirector();
    final navigator = GlobalKey<NavigatorState>();
    final cue = ValueNotifier(MusicCue.square);
    addTearDown(cue.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [musicDirectorProvider.overrideWithValue(director)],
        child: MusicScope(
            director: director,
            child: MaterialApp(
                navigatorKey: navigator,
                navigatorObservers: [director],
                home: const Scaffold(body: Text('Menu'))))));
    expect(director.cue.value, MusicCue.menu);
    final page = MaterialPageRoute<void>(
        builder: (_) => ValueListenableBuilder(
            valueListenable: cue,
            builder: (_, value, child) => MusicScene(
                cue: value, child: const Scaffold(body: Text('Game')))));
    unawaited(navigator.currentState!.push(page));
    await tester.pumpAndSettle();
    expect(director.cue.value, MusicCue.square);
    unawaited(showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(content: Text('Help'))));
    await tester.pumpAndSettle();
    expect(director.cue.value, MusicCue.square);
    cue.value = MusicCue.results;
    await tester.pump();
    expect(director.cue.value, MusicCue.results);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Settings'))));
    await tester.pumpAndSettle();
    expect(director.cue.value, MusicCue.menu);
    // A covered match may rebuild, but cannot take music ownership from Settings.
    cue.value = MusicCue.hex;
    await tester.pump();
    expect(director.cue.value, MusicCue.menu);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(director.cue.value, MusicCue.hex);
    navigator.currentState!.pushReplacement(MaterialPageRoute<void>(
        builder: (_) =>
            const MusicScene(cue: MusicCue.learning, child: Scaffold())));
    await tester.pumpAndSettle();
    expect(director.cue.value, MusicCue.learning);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(director.cue.value, MusicCue.menu);
    await tester.pumpWidget(const SizedBox.shrink());
    director.dispose();
  });
}

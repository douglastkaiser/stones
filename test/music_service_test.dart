import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stones/services/music_service.dart';
import 'helpers/music_voice.dart';

void main() {
  late List<FakeVoice> voices;
  late MusicService music;
  late List<Object> errors;
  setUp(() {
    voices = [];
    errors = [];
    music = MusicService(
        createVoice: () {
          final voice = FakeVoice();
          voices.add(voice);
          return voice;
        },
        wait: (_) async {},
        onError: errors.add);
  });
  tearDown(() => music.dispose());

  test('disabled music never loads; unchanged cue does not restart', () async {
    music.setCue(MusicCue.square);
    await music.settled;
    expect(voices.expand((v) => v.prepared), isEmpty);
    music.configure(enabled: true, volume: .25);
    await music.settled;
    final active = voices.singleWhere((v) => v.playing);
    expect(active.prepared, [MusicCue.square]);
    final starts = active.starts;
    music.setCue(MusicCue.square);
    music.configure(enabled: true, volume: .25);
    music.retry();
    await music.settled;
    expect(active.starts, starts);
    expect(active.levels.last, closeTo(.25, .00001));
  });

  test('crossfade ends with one voice and never exceeds the user volume',
      () async {
    music.configure(enabled: true, volume: .4);
    await music.settled;
    music.setCue(MusicCue.hex);
    await music.settled;
    expect(voices.where((v) => v.playing), hasLength(1));
    expect(voices.singleWhere((v) => v.playing).prepared.last, MusicCue.hex);
    expect(
        voices.expand((v) => v.levels).every((v) => v >= 0 && v <= .4), isTrue);
  });

  test('rapid navigation cancels an obsolete source load before playback',
      () async {
    voices[1].loading = Completer<void>();
    music.configure(enabled: true, volume: .25);
    await Future<void>.delayed(Duration.zero);
    expect(voices[1].prepared, [MusicCue.menu]);
    music.setCue(MusicCue.hex);
    voices[1].loading!.complete();
    await music.settled;
    expect(voices[1].starts, 1);
    expect(voices[1].prepared.last, MusicCue.hex);
    expect(voices[0].playing, isFalse);
  });

  test('mute and background pause both voices; resuming keeps the loaded cue',
      () async {
    music.configure(enabled: true, volume: .25);
    await music.settled;
    music.configure(enabled: false, volume: .25);
    await music.settled;
    expect(voices.any((v) => v.playing), isFalse);
    music.setCue(MusicCue.learning);
    music.configure(enabled: true, volume: .25);
    await music.settled;
    music.configure(enabled: true, volume: 0);
    await music.settled;
    expect(voices.any((v) => v.playing), isFalse);
    final loads = voices.expand((v) => v.prepared).length;
    music.configure(enabled: true, volume: .25);
    await music.settled;
    expect(voices.expand((v) => v.prepared), hasLength(loads));
    expect(
        voices.singleWhere((v) => v.playing).prepared.last, MusicCue.learning);
  });

  test(
      'loop overlap uses the other voice once, and ignored positions cannot restart it',
      () async {
    music.configure(enabled: true, volume: .25);
    await music.settled;
    final old = voices.singleWhere((v) => v.playing);
    old.positions.add(const Duration(milliseconds: 98500));
    old.positions.add(const Duration(milliseconds: 98900));
    await music.settled;
    expect(old.playing, isFalse);
    expect(voices.expand((v) => v.prepared), [MusicCue.menu, MusicCue.menu]);
    old.positions.add(const Duration(seconds: 100));
    await music.settled;
    expect(voices.expand((v) => v.prepared), hasLength(2));
  });

  test('unknown duration still loops at completion', () async {
    for (final voice in voices) {
      voice.duration = null;
    }
    music.configure(enabled: true, volume: .25);
    await music.settled;
    voices.singleWhere((v) => v.playing).completions.add(null);
    await music.settled;
    expect(voices.where((v) => v.playing), hasLength(1));
    expect(voices.expand((v) => v.prepared), hasLength(2));
  });

  test('failed codecs stop both voices and a gesture can retry', () async {
    voices[1].fail = true;
    music.configure(enabled: true, volume: .25);
    await music.settled;
    expect(errors, hasLength(1));
    expect(voices.any((v) => v.playing), isFalse);
    voices[1].fail = false;
    music.retry();
    await music.settled;
    expect(voices.where((v) => v.playing), hasLength(1));
  });

  test('asynchronous playback errors are isolated and can be retried',
      () async {
    music.configure(enabled: true, volume: .25);
    await music.settled;
    voices
        .singleWhere((voice) => voice.playing)
        .completions
        .addError(StateError('device lost'));
    expect(voices.any((voice) => voice.playing), isFalse);
    expect(errors, hasLength(1));
    music.retry();
    await music.settled;
    expect(voices.where((voice) => voice.playing), hasLength(1));
  });

  test('disposal during a source load never starts it', () async {
    voices[1].loading = Completer<void>();
    music.configure(enabled: true, volume: .25);
    await Future<void>.delayed(Duration.zero);
    final disposed = music.dispose();
    await disposed;
    voices[1].loading!.complete();
    expect(
        voices.every((v) => v.disposed && !v.playing && v.starts == 0), isTrue);
    music.setCue(MusicCue.results);
    music.retry();
    await music.settled;
    expect(voices.every((v) => v.starts == 0), isTrue);
  });

  test('backgrounding silences a playing voice while its successor is loading',
      () async {
    music.configure(enabled: true, volume: .25);
    await music.settled;
    final active = voices.singleWhere((v) => v.playing);
    final next = voices.singleWhere((v) => !v.playing);
    next.loading = Completer<void>();
    music.setCue(MusicCue.hex);
    await Future<void>.delayed(Duration.zero);
    music.configure(enabled: false, volume: .25);
    expect(active.playing, isFalse);
    expect(active.levels.last, 0);
    next.loading!.complete();
    await music.settled;
    expect(voices.any((v) => v.playing), isFalse);
  });
}

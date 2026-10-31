import 'dart:async';
import 'package:stones/services/music_service.dart';

class FakeVoice implements MusicVoice {
  final positions = StreamController<Duration>.broadcast(sync: true);
  final completions = StreamController<void>.broadcast(sync: true);
  final prepared = <MusicCue>[];
  final levels = <double>[];
  bool playing = false, disposed = false, fail = false;
  Completer<void>? loading;
  Duration? duration = const Duration(seconds: 100);
  int starts = 0;

  @override
  Stream<Duration> get position => positions.stream;
  @override
  Stream<void> get completed => completions.stream;
  @override
  void unlock() {}
  @override
  Future<Duration?> prepare(MusicCue cue) async {
    prepared.add(cue);
    await loading?.future;
    if (fail) throw StateError('codec unavailable');
    return duration;
  }

  @override
  Future<void> play() async {
    playing = true;
    starts++;
  }

  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> stop() async => playing = false;
  @override
  Future<void> volume(double value) async => levels.add(value);
  @override
  Future<void> dispose() async {
    disposed = true;
    unawaited(positions.close());
    unawaited(completions.close());
  }
}

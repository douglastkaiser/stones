enum MusicCue { menu, square, hex, learning, results }

/// Playback boundary shared by native and browser voices and test doubles.
abstract class MusicVoice {
  Stream<Duration> get position;
  Stream<void> get completed;
  void unlock();
  Future<Duration?> prepare(MusicCue cue);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> volume(double value);
  Future<void> dispose();
}

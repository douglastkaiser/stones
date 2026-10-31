import 'package:audioplayers/audioplayers.dart';

import 'music_types.dart';

MusicVoice createMusicVoice() => _AssetMusicVoice();

class _AssetMusicVoice implements MusicVoice {
  final _player = AudioPlayer();
  @override
  Stream<Duration> get position => _player.onPositionChanged;
  @override
  Stream<void> get completed => _player.onPlayerComplete;
  @override
  void unlock() {}
  @override
  Future<Duration?> prepare(MusicCue cue) async {
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setSource(AssetSource('sounds/music/${cue.name}.mp3'));
    return _player.getDuration();
  }

  @override
  Future<void> play() => _player.resume();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> volume(double value) => _player.setVolume(value);
  @override
  Future<void> dispose() => _player.dispose();
}

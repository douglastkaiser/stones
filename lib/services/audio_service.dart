import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sound effect types
enum SoundEffect {
  place,
  slide,
  flatten,
  win,
}

/// Audio service for playing sound effects
class AudioService {
  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;

  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
    if (!value) {
      _player.stop();
    }
  }

  Future<void> play(SoundEffect effect) async {
    if (!_enabled) return;

    final assetPath = switch (effect) {
      SoundEffect.place => 'sounds/place.wav',
      SoundEffect.slide => 'sounds/slide.wav',
      SoundEffect.flatten => 'sounds/flatten.wav',
      SoundEffect.win => 'sounds/win.wav',
    };

    try {
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      // Silently ignore audio errors (e.g., on web without audio support)
    }
  }

  void dispose() {
    _player.dispose();
  }
}

/// Provider for audio service
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for sound enabled state
final soundEnabledProvider = StateProvider<bool>((ref) => true);

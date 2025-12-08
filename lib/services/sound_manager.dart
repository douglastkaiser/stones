import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sound types available in the game
enum GameSound {
  piecePlace,
  stackMove,
  wallFlatten,
  win,
  illegalMove,
}

/// Manages game sounds with mute support
class SoundManager {
  static const String _muteKey = 'sound_muted';

  final Map<GameSound, AudioPlayer> _players = {};
  bool _isMuted = false;
  bool _isInitialized = false;

  /// Whether sounds are muted
  bool get isMuted => _isMuted;

  /// Initialize the sound manager and load all sounds
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load mute preference
    final prefs = await SharedPreferences.getInstance();
    _isMuted = prefs.getBool(_muteKey) ?? false;

    // Create audio players for each sound
    for (final sound in GameSound.values) {
      _players[sound] = AudioPlayer();
      await _players[sound]!.setSource(AssetSource(_getAssetPath(sound)));
      await _players[sound]!.setReleaseMode(ReleaseMode.stop);
    }

    _isInitialized = true;
  }

  /// Get the asset path for a sound
  String _getAssetPath(GameSound sound) {
    switch (sound) {
      case GameSound.piecePlace:
        return 'sounds/piece_place.wav';
      case GameSound.stackMove:
        return 'sounds/stack_move.wav';
      case GameSound.wallFlatten:
        return 'sounds/wall_flatten.wav';
      case GameSound.win:
        return 'sounds/win.wav';
      case GameSound.illegalMove:
        return 'sounds/illegal_move.wav';
    }
  }

  /// Play a sound effect
  Future<void> play(GameSound sound) async {
    if (_isMuted || !_isInitialized) return;

    final player = _players[sound];
    if (player != null) {
      await player.stop();
      await player.resume();
    }
  }

  /// Set mute state and persist it
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteKey, muted);
  }

  /// Toggle mute state
  Future<void> toggleMute() async {
    await setMuted(!_isMuted);
  }

  /// Dispose all audio players
  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
    _isInitialized = false;
  }

  // Convenience methods for each sound type

  /// Play piece placement sound (soft tap/click)
  Future<void> playPiecePlace() => play(GameSound.piecePlace);

  /// Play stack move sound (sliding stone)
  Future<void> playStackMove() => play(GameSound.stackMove);

  /// Play wall flatten sound (deeper thunk)
  Future<void> playWallFlatten() => play(GameSound.wallFlatten);

  /// Play win sound (pleasant chime)
  Future<void> playWin() => play(GameSound.win);

  /// Play illegal move sound (subtle error buzz)
  Future<void> playIllegalMove() => play(GameSound.illegalMove);
}

/// Provider for the sound manager singleton
final soundManagerProvider = Provider<SoundManager>((ref) {
  final manager = SoundManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Provider for the mute state (reactive)
final isMutedProvider = StateProvider<bool>((ref) => false);

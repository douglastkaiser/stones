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
  achievement,
}

/// Manages game sounds with mute support
class SoundManager {
  static const String _muteKey = 'sound_muted';

  final Map<String, AudioPlayer> _players = {};
  bool _isMuted = false;
  bool _isInitialized = false;

  String _piecePlaceAsset = 'assets/sounds/piece_place.wav';
  String _stackMoveAsset = 'assets/sounds/stack_move.wav';

  /// Whether sounds are muted
  bool get isMuted => _isMuted;

  /// Initialize the sound manager and load all sounds
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load mute preference
    final prefs = await SharedPreferences.getInstance();
    _isMuted = prefs.getBool(_muteKey) ?? false;

    _isInitialized = true;
  }

  /// Get the asset path for a sound
  String _getAssetPath(GameSound sound) {
    switch (sound) {
      case GameSound.piecePlace:
        return _piecePlaceAsset;
      case GameSound.stackMove:
        return _stackMoveAsset;
      case GameSound.wallFlatten:
        return 'assets/sounds/wall_flatten.wav';
      case GameSound.win:
        return 'assets/sounds/win.wav';
      case GameSound.illegalMove:
        return 'assets/sounds/illegal_move.wav';
      case GameSound.achievement:
        return 'assets/sounds/win.wav';
    }
  }

  /// Configure the audio variants used for the current cosmetics.
  void setCosmeticSounds({required String boardSound, required String stackSound}) {
    _piecePlaceAsset = boardSound;
    _stackMoveAsset = stackSound;
  }

  /// Play a sound effect
  Future<void> play(GameSound sound) async {
    if (_isMuted || !_isInitialized) return;

    final asset = _getAssetPath(sound);
    final player = await _getPlayer(asset);
    await player.stop();
    await player.resume();
  }

  Future<AudioPlayer> _getPlayer(String asset) async {
    if (_players.containsKey(asset)) {
      return _players[asset]!;
    }
    final player = AudioPlayer();
    await player.setSource(AssetSource(asset.replaceFirst('assets/', '')));
    await player.setReleaseMode(ReleaseMode.stop);
    _players[asset] = player;
    return player;
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

  /// Play achievement unlock sound
  Future<void> playAchievement() => play(GameSound.achievement);
}

/// Provider for the sound manager singleton
final soundManagerProvider = Provider<SoundManager>((ref) {
  final manager = SoundManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Provider for the mute state (reactive)
final isMutedProvider = StateProvider<bool>((ref) => false);

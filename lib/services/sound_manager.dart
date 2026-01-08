import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cosmetics.dart';

/// Sound types available in the game
enum GameSound {
  piecePlace,
  stackMove,
  wallFlatten,
  win,
  illegalMove,
  achievementUnlock,
  // Board theme sounds
  piecePlaceWood,
  piecePlaceStone,
  piecePlaceMarble,
  piecePlaceMinimal,
  piecePlacePixel,
  // Piece style sounds
  stackMoveWood,
  stackMoveStone,
  stackMoveMarble,
  stackMoveMinimal,
  stackMovePixel,
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
        return 'sounds/piece_place.ogg';
      case GameSound.stackMove:
        return 'sounds/stack_move.ogg';
      case GameSound.wallFlatten:
        return 'sounds/wall_flatten.ogg';
      case GameSound.win:
        return 'sounds/win.ogg';
      case GameSound.illegalMove:
        return 'sounds/illegal_move.ogg';
      case GameSound.achievementUnlock:
        return 'sounds/achievement_unlock.ogg';
      // Board theme placement sounds - fallback to piece_place.ogg for now
      case GameSound.piecePlaceWood:
        return 'sounds/piece_place.ogg';
      case GameSound.piecePlaceStone:
        return 'sounds/piece_place_stone.ogg';
      case GameSound.piecePlaceMarble:
        return 'sounds/piece_place_marble.ogg';
      case GameSound.piecePlaceMinimal:
        return 'sounds/piece_place_minimal.ogg';
      case GameSound.piecePlacePixel:
        return 'sounds/piece_place_pixel.ogg';
      // Piece style stack move sounds - fallback to stack_move.ogg for now
      case GameSound.stackMoveWood:
        return 'sounds/stack_move.ogg';
      case GameSound.stackMoveStone:
        return 'sounds/piece_place_stone.ogg'; // Use stone placement sound
      case GameSound.stackMoveMarble:
        return 'sounds/stack_move_marble.ogg';
      case GameSound.stackMoveMinimal:
        return 'sounds/piece_place_minimal.ogg'; // Use minimal sound
      case GameSound.stackMovePixel:
        return 'sounds/piece_place_pixel.ogg'; // Use pixel sound
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

  /// Play achievement unlock sound
  Future<void> playAchievementUnlock() => play(GameSound.achievementUnlock);

  /// Play themed piece placement sound based on board theme
  Future<void> playThemedPiecePlace(BoardTheme theme) {
    final sound = switch (theme) {
      BoardTheme.classicWood => GameSound.piecePlaceWood,
      BoardTheme.darkStone => GameSound.piecePlaceStone,
      BoardTheme.marble => GameSound.piecePlaceMarble,
      BoardTheme.minimalist => GameSound.piecePlaceMinimal,
      BoardTheme.pixelArt => GameSound.piecePlacePixel,
    };
    return play(sound);
  }

  /// Play themed stack move sound based on piece style
  Future<void> playThemedStackMove(PieceStyle style) {
    final sound = switch (style) {
      PieceStyle.standard => GameSound.stackMoveWood,
      PieceStyle.stone => GameSound.stackMoveStone,
      PieceStyle.polishedMarble => GameSound.stackMoveMarble,
      PieceStyle.minimalist => GameSound.stackMoveMinimal,
      PieceStyle.pixel => GameSound.stackMovePixel,
    };
    return play(sound);
  }
}

/// Provider for the sound manager singleton
final soundManagerProvider = Provider<SoundManager>((ref) {
  final manager = SoundManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Provider for the mute state (reactive)
final isMutedProvider = StateProvider<bool>((ref) => false);

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'music_types.dart';
import 'music_voice_native.dart'
    if (dart.library.js_interop) 'music_voice_web.dart';

export 'music_types.dart';

/// Two voices share one serial, cancellable transition queue. No gameplay awaits
/// this service. A failed load can be retried by the next explicit interaction.
class MusicService {
  MusicService({
    MusicVoice Function()? createVoice,
    Future<void> Function(Duration)? wait,
    this.onError,
  }) : _wait = wait ?? Future<void>.delayed {
    _voices = List.generate(2, (_) => (createVoice ?? createMusicVoice)());
    for (var i = 0; i < _voices.length; i++) {
      final index = i;
      _subscriptions.add(_voices[i].position.listen((position) {
        final duration = _duration;
        if (!_disposed &&
            !_busy &&
            _playing &&
            index == _active &&
            duration != null &&
            position >= duration - loopOverlap) {
          _request(loop: true);
        }
      }, onError: _voiceError));
      _completions.add(_voices[i].completed.listen((_) {
        if (!_disposed && !_busy && _playing && index == _active) {
          // Some codecs don't expose duration until completion. Keep looping,
          // even when that platform cannot provide the early overlap signal.
          _playing = false;
          _request(loop: true);
        }
      }, onError: _voiceError));
    }
  }

  static const fadeDuration = Duration(milliseconds: 900);
  static const loopOverlap = Duration(milliseconds: 1500);
  final Future<void> Function(Duration) _wait;
  final void Function(Object)? onError;
  late final List<MusicVoice> _voices;
  final _subscriptions = <StreamSubscription<Duration>>[];
  final _completions = <StreamSubscription<void>>[];
  Future<void> _pending = Future.value();
  MusicCue _cue = MusicCue.menu;
  MusicCue? _loaded;
  int _active = 0, _revision = 0;
  bool _enabled = false, _playing = false, _busy = false, _disposed = false;
  bool _failed = false;
  double _volume = 0;
  Duration? _duration;
  void Function()? _cancelOperation;

  Future<void> get settled => _pending;

  void unlock() {
    if (_disposed) return;
    for (final voice in _voices) {
      voice.unlock();
    }
  }

  void setCue(MusicCue cue) {
    if (_disposed || _cue == cue) return;
    _cue = cue;
    _request();
  }

  void configure({required bool enabled, required double volume}) {
    if (_disposed) return;
    final clamped = volume.clamp(0.0, 1.0);
    if (_enabled == enabled && _volume == clamped) return;
    _enabled = enabled;
    _volume = clamped;
    // Mute/background must take effect even while a platform source is loading.
    if ((!enabled || clamped == 0) && (_playing || _busy)) {
      _silenceNow();
      _cancelOperation?.call();
    }
    _request();
  }

  void retry() {
    if (!_disposed && _failed) _request();
  }

  void _request({bool loop = false}) {
    final revision = ++_revision;
    _busy = true;
    var expired = false;
    bool current() => !expired && !_disposed && revision == _revision;
    _pending = _pending.then((_) async {
      if (!current()) return;
      try {
        await _bounded(_apply(current, loop: loop), () => expired = true);
        if (current()) _failed = false;
      } catch (error) {
        if (_disposed) return;
        // Even one broken voice must not leave the other playing in the background.
        _playing = false;
        _loaded = null;
        _failed = true;
        for (final voice in _voices) {
          unawaited(voice.stop().catchError((Object _) {}));
        }
        onError?.call(error);
      } finally {
        if (revision == _revision) _busy = false;
      }
    });
  }

  void _silenceNow() {
    for (final voice in _voices) {
      unawaited(voice.volume(0).catchError((Object _) {}));
      unawaited(voice.pause().catchError((Object _) {}));
    }
    _playing = false;
  }

  Future<void> _bounded(Future<void> work, void Function() expire) {
    final done = Completer<void>();
    final timer = Timer(const Duration(seconds: 10), () {
      expire();
      if (!done.isCompleted) {
        done.completeError(
            TimeoutException('Optional music playback timed out'));
      }
    });
    void cancel() {
      expire();
      timer.cancel();
      if (!done.isCompleted) done.complete();
    }

    _cancelOperation = cancel;
    unawaited(work.then<void>((_) {
      timer.cancel();
      if (!done.isCompleted) done.complete();
    }, onError: (Object error, StackTrace stack) {
      timer.cancel();
      if (!done.isCompleted) done.completeError(error, stack);
    }));
    return done.future.whenComplete(() {
      if (identical(_cancelOperation, cancel)) _cancelOperation = null;
    });
  }

  void _voiceError(Object error) {
    if (_disposed) return;
    ++_revision;
    _busy = false;
    _failed = true;
    _loaded = null;
    _silenceNow();
    onError?.call(error);
  }

  Future<void> _apply(bool Function() current, {required bool loop}) async {
    final old = _voices[_active], next = _voices[1 - _active];
    await next.stop();
    if (!current()) return;
    if (!_enabled || _volume == 0) {
      await old.pause();
      _playing = false;
      return;
    }
    if (_loaded == _cue && !loop) {
      await old.volume(_volume);
      if (!current()) return;
      await old.play();
      _playing = true;
      return;
    }
    final cue = _cue;
    final duration = await next.prepare(cue);
    if (!current()) return;
    await next.volume(0);
    if (!current()) return;
    await next.play();
    if (!current()) return;
    final wasPlaying = _playing;
    const steps = 18;
    for (var step = 1; step <= steps; step++) {
      if (!current()) return;
      final phase = step / steps * math.pi / 2;
      await next.volume(_volume * math.sin(phase));
      if (!current()) return;
      await old.volume(wasPlaying ? _volume * math.cos(phase) : 0);
      await _wait(fadeDuration ~/ steps);
    }
    if (!current()) return;
    await old.stop();
    if (!current()) return;
    _active = 1 - _active;
    _loaded = cue;
    _duration = duration;
    _playing = true;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_revision;
    _cancelOperation?.call();
    _silenceNow();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    for (final subscription in _completions) {
      await subscription.cancel();
    }
    // The revision checks prevent queued work from starting again. Release
    // voices now rather than waiting for a platform load that may never finish.
    for (final voice in _voices) {
      await voice.dispose();
    }
  }
}

final musicServiceProvider = Provider<MusicService>((ref) {
  final music = MusicService(
      onError: (error) => debugPrint('Optional music playback failed: $error'));
  ref.onDispose(() => unawaited(music.dispose()));
  return music;
});

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'music_types.dart';

_MusicContext? _shared;

MusicVoice createMusicVoice() => _BufferMusicVoice(_shared ??= _MusicContext());

/// One context keeps browser gesture permission across new tracks. The stock
/// media-element backend creates a new element when its source changes, which
/// loses autoplay permission in Firefox/WebKit during asynchronous transitions.
class _MusicContext {
  web.AudioContext? _context;
  web.AudioContext get context => _context ??= web.AudioContext();
  final buffers = <MusicCue, Future<web.AudioBuffer>>{};
  int owners = 0;

  Future<void> close() async {
    await _context?.close().toDart;
  }

  Future<web.AudioBuffer> load(MusicCue cue) {
    final existing = buffers.remove(cue);
    final buffer = existing ?? _decode(cue);
    buffers[cue] = buffer;
    // Bound decoded memory. A playing node retains its own buffer until stopped.
    while (buffers.length > 2) {
      buffers.remove(buffers.keys.first);
    }
    return buffer;
  }

  Future<web.AudioBuffer> _decode(MusicCue cue) async {
    try {
      final data = await rootBundle.load('assets/sounds/music/${cue.name}.mp3');
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      return await context
          .decodeAudioData(Uint8List.fromList(bytes).buffer.toJS)
          .toDart;
    } catch (_) {
      // A later interaction may retry a failed download.
      buffers.removeWhere((key, _) => key == cue);
      rethrow;
    }
  }
}

class _BufferMusicVoice implements MusicVoice {
  _BufferMusicVoice(this.pool) {
    pool.owners++;
  }
  final _MusicContext pool;
  web.GainNode? _gain;
  double _level = 1;
  final _positions = StreamController<Duration>.broadcast();
  final _completions = StreamController<void>.broadcast();
  web.AudioBuffer? _buffer;
  web.AudioBufferSourceNode? _source;
  Timer? _timer;
  double _offset = 0, _startedAt = 0;
  bool _disposed = false;
  int _revision = 0;

  @override
  Stream<Duration> get position => _positions.stream;
  @override
  Stream<void> get completed => _completions.stream;

  @override
  void unlock() {
    if (!_disposed) {
      // Called directly inside a trusted gesture, before any source-load await.
      try {
        unawaited(pool.context
            .resume()
            .toDart
            .then<void>((_) {}, onError: (Object _) {}));
      } catch (error) {
        _completions.addError(error);
      }
    }
  }

  @override
  Future<Duration?> prepare(MusicCue cue) async {
    final revision = ++_revision;
    final buffer = await pool.load(cue);
    if (_disposed || revision != _revision) return null;
    _buffer = buffer;
    _offset = 0;
    return Duration(microseconds: (buffer.duration * 1000000).round());
  }

  double get _position =>
      _offset + (_source == null ? 0 : pool.context.currentTime - _startedAt);

  @override
  Future<void> play() async {
    if (_disposed || _source != null || _buffer == null) return;
    final revision = _revision;
    await pool.context.resume().toDart;
    if (_disposed || revision != _revision) return;
    final source = pool.context.createBufferSource();
    if (_gain == null) {
      _gain = pool.context.createGain();
      _gain!.connect(pool.context.destination);
    }
    _gain!.gain.value = _level;
    source.buffer = _buffer;
    source.connect(_gain!);
    _source = source;
    _startedAt = pool.context.currentTime;
    source.addEventListener(
        'ended',
        ((web.Event event) {
          source.disconnect();
          if (!_disposed && _source == source) {
            _source = null;
            _offset = 0;
            _timer?.cancel();
            _completions.add(null);
          }
        }).toJS);
    source.start(0, _offset);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_disposed) {
        _positions.add(Duration(microseconds: (_position * 1000000).round()));
      }
    });
  }

  @override
  Future<void> pause() async {
    ++_revision;
    _offset = _position;
    final source = _source;
    _source = null;
    source?.stop();
    _timer?.cancel();
  }

  @override
  Future<void> stop() async {
    await pause();
    _offset = 0;
  }

  @override
  Future<void> volume(double value) async {
    _level = value;
    _gain?.gain.value = value;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    _gain?.disconnect();
    _buffer = null;
    await _positions.close();
    await _completions.close();
    if (--pool.owners == 0) {
      pool.buffers.clear();
      if (_shared == pool) _shared = null;
      await pool.close();
    }
  }
}

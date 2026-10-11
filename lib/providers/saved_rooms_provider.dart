import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A local pointer, never an authority for seats or the board. Firebase owns
/// the match; the saved identity must still own a seat when resuming.
class SavedRoom {
  const SavedRoom(
      {required this.code,
      required this.uid,
      required this.hex,
      this.unified = false});
  final String code;
  final String uid;
  final bool hex;
  final bool unified;
  Map<String, dynamic> toMap() =>
      {'code': code, 'uid': uid, 'hex': hex, if (unified) 'unified': true};

  static SavedRoom? parse(Object? value) {
    if (value is! Map || value['uid'] is! String || value['hex'] is! bool) {
      return null;
    }
    final code = value['code'];
    final hex = value['hex'] as bool;
    final unified = value['unified'] == true;
    if (code is! String ||
        !(unified
                ? RegExp(r'^U[A-Z]{6}$')
                : hex
                    ? RegExp(r'^H[A-Z]{6}$')
                    : RegExp(r'^[A-Z]{6}$'))
            .hasMatch(code) ||
        (value['uid'] as String).isEmpty) {
      return null;
    }
    return SavedRoom(
        code: code, uid: value['uid'] as String, hex: hex, unified: unified);
  }
}

class SavedRoomsController extends StateNotifier<List<SavedRoom>> {
  SavedRoomsController() : super(const []);
  static const storageKey = 'online_rooms_v1';
  Future<void>? _loading;
  Future<void> _writes = Future<void>.value();

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || !mounted) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      state = List.unmodifiable(
          decoded.map(SavedRoom.parse).whereType<SavedRoom>().take(10));
    } on FormatException {
      // A malformed bookmark must not prevent launching an offline game.
    }
  }

  Future<void> remember(SavedRoom room) async {
    await load();
    if (!mounted) return;
    state = List.unmodifiable([
      room,
      ...state.where((old) => old.code != room.code || old.hex != room.hex)
    ].take(10));
    await _save();
  }

  Future<void> forget(SavedRoom room) async {
    await load();
    if (!mounted) return;
    state = List.unmodifiable(
        state.where((old) => old.code != room.code || old.hex != room.hex));
    await _save();
  }

  Future<void> _save() {
    final encoded = jsonEncode(state.map((room) => room.toMap()).toList());
    final write = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, encoded)) {
        throw StateError(
            'Could not save the room shortcut. Keep your room code.');
      }
    });
    // A failed write must not prevent a later retry.
    _writes = write.catchError((Object _) {});
    return write;
  }
}

final savedRoomsProvider =
    StateNotifierProvider<SavedRoomsController, List<SavedRoom>>(
        (ref) => SavedRoomsController());

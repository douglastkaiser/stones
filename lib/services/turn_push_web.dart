// @dart=3.3
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'turn_push_types.dart';

@JS('stonesPush')
external _PushApi get _push;
extension type _PushApi(JSObject _) implements JSObject {
  external JSPromise<JSString> permission();
  external JSPromise<JSString> enable(JSString vapid);
  external JSPromise<JSString> refresh(JSString vapid);
  external JSPromise<JSAny?> disable();
  external JSPromise<JSAny?> bind(JSString uid);
}

TurnPushPlatform createTurnPushPlatform() => _WebPush();

class _WebPush implements TurnPushPlatform {
  @override
  Future<TurnPushPermission> permission() async => TurnPushPermission.values
      .byName((await _push.permission().toDart).toDart);
  @override
  Future<String?> enable(String vapidKey) async {
    final token = (await _push.enable(vapidKey.toJS).toDart).toDart;
    return token.isEmpty ? null : token;
  }

  @override
  Future<String?> refresh(String vapidKey) async {
    final token = (await _push.refresh(vapidKey.toJS).toDart).toDart;
    return token.isEmpty ? null : token;
  }

  @override
  Future<void> disable() async {
    await _push.disable().toDart;
  }

  @override
  Future<void> bind(String? uid) async {
    await _push.bind((uid ?? '').toJS).toDart;
  }

  Stream<Map<String, dynamic>> _events(String type) =>
      Stream<Map<String, dynamic>>.multi((controller) {
        final listener = ((web.Event event) {
          try {
            final raw = (event as web.CustomEvent).detail as JSString;
            controller.add(Map<String, dynamic>.from(jsonDecode(raw.toDart)));
          } catch (_) {/* Ignore unrelated browser messages. */}
        }).toJS;
        web.window.addEventListener(type, listener);
        controller.onCancel =
            () => web.window.removeEventListener(type, listener);
      });
  @override
  Stream<Map<String, dynamic>> get opened => _events('stones-turn-open');
  @override
  Stream<Map<String, dynamic>> get foreground =>
      _events('stones-turn-foreground');
  @override
  Stream<String> get tokens => const Stream.empty();
}

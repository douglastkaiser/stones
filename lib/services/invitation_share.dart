import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('stones/invitations');

/// Android uses its sharesheet; other platforms retain explicit copy actions.
Future<bool> shareInvitation(Uri invitation) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await _channel
            .invokeMethod<bool>('share', {'url': invitation.toString()}) ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

import 'package:flutter/material.dart';
import 'join_room_screen.dart';

/// Cold web URLs and native pushRoute links use the same non-claiming screen.
List<Route<dynamic>> initialInvitationRoutes(String platformRoute,
    {required Widget home, Uri? browserUri}) {
  final incoming = browserUri != null && _hasRoom(browserUri)
      ? browserUri.toString()
      : platformRoute;
  final uri = Uri.tryParse(incoming);
  return [
    MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/'), builder: (_) => home),
    if (uri != null && _hasRoom(uri))
      invitationRoute(RouteSettings(name: incoming)),
  ];
}

Route<void> invitationRoute(RouteSettings settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => JoinRoomScreen(invitation: settings.name ?? ''));

bool _hasRoom(Uri uri) {
  try {
    return uri.queryParametersAll.containsKey('room');
  } on FormatException {
    return uri.hasQuery;
  }
}

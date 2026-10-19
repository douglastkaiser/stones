import 'dart:convert';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

bool downloadResultImage(Uint8List bytes) {
  final anchor = web.HTMLAnchorElement()
    ..href = 'data:image/png;base64,${base64Encode(bytes)}'
    ..download = 'stones-result.png';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  return true;
}

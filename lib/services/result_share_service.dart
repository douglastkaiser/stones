import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum ResultShareOutcome { handled, cancelled, unsupported }

Uri resultSmsUri(String text, {bool ios = false}) =>
    Uri.parse('sms:${ios ? '&' : '?'}body=${Uri.encodeComponent(text)}');

class ResultShareService {
  const ResultShareService();

  Future<ResultShareOutcome> share(String text,
      {Uint8List? png, Rect? origin}) async {
    try {
      final result = await SharePlus.instance.share(ShareParams(
        title: 'Stones result',
        text: text,
        sharePositionOrigin: origin,
        mailToFallbackEnabled: false,
        downloadFallbackEnabled: false,
        files:
            png == null ? null : [XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: png == null ? null : ['stones-result.png'],
      ));
      return result.status == ShareResultStatus.dismissed
          ? ResultShareOutcome.cancelled
          : ResultShareOutcome.handled;
    } catch (_) {
      return ResultShareOutcome.unsupported;
    }
  }

  Future<bool> sms(String text) async {
    try {
      return await launchUrl(
          resultSmsUri(text, ios: defaultTargetPlatform == TargetPlatform.iOS),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

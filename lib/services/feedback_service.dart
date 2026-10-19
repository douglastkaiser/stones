import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../version.dart';

enum FeedbackKind {
  problem('Problem'),
  idea('Idea'),
  other('Other');

  const FeedbackKind(this.label);
  final String label;
}

/// Deliberately limited diagnostics: no account, room, URL, logs or saved game.
class FeedbackReport {
  const FeedbackReport({
    required this.kind,
    required this.summary,
    required this.description,
    required this.appDetails,
    this.includeAppDetails = true,
  });

  static const recipient = 'douglastkaiser@gmail.com';
  final FeedbackKind kind;
  final String summary, description, appDetails;
  final bool includeAppDetails;

  static String currentAppDetails() => 'Version: ${AppVersion.displayVersion}\n'
      'Platform: ${kIsWeb ? 'Web' : 'App'} (${defaultTargetPlatform.name})';

  String get subject => '[Stones feedback] ${kind.label}: '
      '${summary.replaceAll(RegExp(r'[\r\n]+'), ' ').trim()}';

  String get body => '${description.trim()}\n\n'
      '${includeAppDetails ? 'App details\n$appDetails\n' : ''}';

  String get copyText => 'To: $recipient\nSubject: $subject\n\n$body';

  // mailto requires percent-encoded spaces; queryParameters uses '+' instead.
  Uri get emailUri => Uri(
      scheme: 'mailto',
      path: recipient,
      query: 'subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}');
}

class FeedbackService {
  FeedbackService({Future<bool> Function(Uri)? openDraft})
      : _openDraft = openDraft ?? _launch;
  final Future<bool> Function(Uri) _openDraft;

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// True means a composer was requested, never that feedback was sent.
  Future<bool> open(FeedbackReport report) async {
    try {
      return await _openDraft(report.emailUri)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      return false;
    }
  }
}

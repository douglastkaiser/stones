/// Auto-generated version information.
/// This file is updated during CI/CD builds with git information.
/// Do not edit manually - changes will be overwritten.

class AppVersion {
  /// Full version string (e.g., "v1.0.0+3.g404a5eb.d20251206")
  static const String version = 'dev';

  /// Short git commit hash (e.g., "404a5eb")
  static const String commitHash = 'local';

  /// Build date in YYYYMMDD format
  static const String buildDate = '';

  /// GitHub repository URL for linking to commits
  static const String repoUrl = 'https://github.com/douglastkaiser/stones';

  /// Get the full display string for the version footer
  static String get displayVersion {
    if (commitHash == 'local') {
      return 'dev (local)';
    }
    return '$version ($commitHash)';
  }

  /// Get the URL to the commit on GitHub
  static String? get commitUrl {
    if (commitHash == 'local' || commitHash.isEmpty) {
      return null;
    }
    return '$repoUrl/commit/$commitHash';
  }
}

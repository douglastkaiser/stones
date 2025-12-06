#!/bin/bash
# Generate version.dart with git information
# This script is run during CI/CD builds

set -e

# Get version info from git
COMMIT_HASH=$(git rev-parse --short HEAD)
FULL_HASH=$(git rev-parse HEAD)
BUILD_DATE=$(date +%Y%m%d)

# Get version from pubspec.yaml
PUBSPEC_VERSION=$(grep '^version:' pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1)

# Count commits for build number
COMMIT_COUNT=$(git rev-list --count HEAD)

# Create version string similar to: v1.0.0+42.g404a5eb.d20251206
VERSION="v${PUBSPEC_VERSION}+${COMMIT_COUNT}.g${COMMIT_HASH}.d${BUILD_DATE}"

# Get repo URL from git remote (fallback to default)
REPO_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's|git@github.com:|https://github.com/|' || echo "https://github.com/douglastkaiser/stones")

echo "Generating version.dart with:"
echo "  Version: $VERSION"
echo "  Commit: $COMMIT_HASH"
echo "  Build Date: $BUILD_DATE"
echo "  Repo URL: $REPO_URL"

# Generate the version.dart file
cat > lib/version.dart << EOF
/// Auto-generated version information.
/// This file is updated during CI/CD builds with git information.
/// Do not edit manually - changes will be overwritten.

class AppVersion {
  /// Full version string (e.g., "v1.0.0+3.g404a5eb.d20251206")
  static const String version = '$VERSION';

  /// Short git commit hash (e.g., "404a5eb")
  static const String commitHash = '$COMMIT_HASH';

  /// Build date in YYYYMMDD format
  static const String buildDate = '$BUILD_DATE';

  /// GitHub repository URL for linking to commits
  static const String repoUrl = '$REPO_URL';

  /// Get the full display string for the version footer
  static String get displayVersion {
    if (commitHash == 'local') {
      return 'dev (local)';
    }
    return '\$version (\$commitHash)';
  }

  /// Get the URL to the commit on GitHub
  static String? get commitUrl {
    if (commitHash == 'local' || commitHash.isEmpty) {
      return null;
    }
    return '\$repoUrl/commit/$FULL_HASH';
  }
}
EOF

echo "Generated lib/version.dart"

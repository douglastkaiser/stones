# stones
Stones: An Okay Game

## Development

### Prerequisites
- Flutter SDK (3.0+)

### Running Locally
```bash
flutter run
```

### Before Pushing

Always run the analyzer locally before pushing to avoid CI failures:

```bash
# Run analyzer with strict checking (matches CI)
flutter analyze --fatal-infos

# Run tests
flutter test
```

The `--fatal-infos` flag treats info-level issues as errors, which is what CI uses. Common issues to watch for:
- **Unused imports** - Remove any imports you're not using
- **Unused variables** - Delete variables that aren't referenced
- **Missing const** - Add `const` to widget constructors where possible
- **Deprecated APIs** - Use modern Flutter APIs (e.g., `activeThumbColor` instead of `activeColor`)

### Building
```bash
flutter build web    # Web build
flutter build apk    # Android build
```

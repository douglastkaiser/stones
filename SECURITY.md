# Security

## Security Measures

This document outlines the security measures implemented in the Stones project.

### 1. Firestore Security Rules

Comprehensive Firestore security rules are defined in `firestore.rules` to protect game data:

- **Authentication Required**: All database operations require user authentication
- **Player Authorization**: Users can only read/modify games they are participating in
- **Data Validation**: Input validation for all fields (room codes, display names, moves, etc.)
- **Immutable Fields**: Player IDs and critical game data cannot be modified after creation
- **Length Limits**: Display names limited to 30 characters, move notation to 20 characters

Deploy rules to Firebase:
```bash
firebase deploy --only firestore:rules
```

### 2. Input Validation and Sanitization

#### Display Names
- Trimmed and length-limited (max 30 characters)
- Control characters removed
- Sanitized in both `OnlineGamePlayer.fromMap()` and when creating players
- See: `lib/models/online_game.dart:_sanitizeDisplayName()`

#### Move Notation
- Format validation using regex patterns
- Length limited to 20 characters
- Only allows valid Tak notation characters
- Validated before parsing and applying moves
- See: `lib/models/online_game.dart:OnlineGameMove.isValidNotation()`

### 3. Cryptographically Secure Random Generation

Room codes and anonymous player names use `Random.secure()` instead of `Random()`:
- Room codes: 6-letter codes are cryptographically random, preventing prediction
- Player names: Anonymous player name suffixes use secure random digits
- See: `lib/providers/online_game_provider.dart:_generateRoomCode()`

### 4. Debug Logging Protection

Verbose debug logging is disabled in production builds:
- All `_debugLog()` calls wrapped in `kDebugMode` checks
- Prevents exposure of user IDs, game data, and internal state in production
- Logs still available during development for debugging
- See: `lib/providers/online_game_provider.dart:_debugLog()`

### 5. Error Message Sanitization

User-facing error messages are sanitized to prevent information disclosure:
- Internal error details logged but not shown to users
- Generic messages replace stack traces and implementation details
- Prevents exposure of database structure or internal logic
- See: `lib/providers/online_game_provider.dart:_sanitizeErrorMessage()`

### 6. Firebase API Key Exposure

Firebase API keys are intentionally public (documented in `lib/firebase_options.dart`):
- Firebase web API keys are designed to be included in client code
- Security is enforced by Firestore Security Rules and Firebase Authentication
- API keys only identify the project, they do not grant data access
- Reference: https://firebase.google.com/docs/projects/api-keys

## Remaining Security Considerations

### 1. Rate Limiting
Currently, there is no rate limiting on:
- Game creation
- Room join attempts
- Move submissions

**Recommendation**: Implement Firebase App Check or Cloud Functions-based rate limiting.

### 2. Data Storage
User data stored in `SharedPreferences` is not encrypted:
- Game statistics
- User preferences

**Recommendation**: For sensitive data, consider using `flutter_secure_storage` package.

### 3. Anonymous Authentication
The app falls back to anonymous authentication if Google Sign-In fails:
- Anonymous users are harder to track and ban
- Less accountability for user actions

**Recommendation**: Consider requiring authenticated users for online play.

## Reporting Security Issues

If you discover a security vulnerability, please report it to the repository maintainers privately rather than opening a public issue.

## Security Checklist for Developers

Before deploying changes:

- [ ] Run `flutter analyze --fatal-infos` (no warnings or infos)
- [ ] Deploy updated Firestore security rules if database schema changes
- [ ] Review any new user inputs for validation needs
- [ ] Ensure error messages don't expose internal details
- [ ] Test authentication flows and authorization checks
- [ ] Verify that debug logging doesn't expose sensitive data

## References

- [Firestore Security Rules Documentation](https://firebase.google.com/docs/firestore/security/get-started)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Flutter Security Best Practices](https://docs.flutter.dev/security)

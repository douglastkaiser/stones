# Claude Code Guidelines for Stones

## Project Overview
Stones is a Flutter-based implementation of the Tak board game with AI opponents, local multiplayer, and online play.

## Build & Test Commands
```bash
flutter analyze --fatal-infos  # Must pass with no issues
flutter test                   # Run all tests
flutter build web              # Build for web
flutter build apk              # Build for Android
```

## Code Quality Rules

### Dart Analyzer
The project uses `flutter analyze --fatal-infos` which treats warnings AND infos as errors. Before committing:

1. **Never declare unused variables** - If you declare a variable, use it. Remove any `final foo = ...` where `foo` is never referenced.

2. **Remove unused imports** - Delete any import statements that aren't used.

3. **Remove unused parameters** - If a function parameter isn't used, either use it or prefix with underscore (`_unusedParam`).

4. **Remove unused private classes/methods** - If you replace a widget or method with a new implementation, DELETE the old one. Don't leave orphaned `_OldWidget` or `_oldMethod` declarations. **IMPORTANT: Check for cascading deletions** - when you delete a class, also delete any helper classes/methods that were ONLY used by that class (e.g., if you delete `_MyDialog`, also delete `_MyDialogRow` if nothing else uses it).

5. **Use const constructors** - Always add `const` keyword to widget constructors when all arguments are compile-time constants. This includes `Text`, `Icon`, `SizedBox`, `TextStyle`, etc.
   ```dart
   // BAD - missing const
   Text('Hello', style: TextStyle(color: Colors.red))

   // GOOD - const added
   const Text('Hello', style: TextStyle(color: Colors.red))
   ```

6. **Avoid unreachable switch cases** - Don't use wildcard `_` in switch expressions when all enum values are already covered:
   ```dart
   // BAD - unreachable case (PieceType only has flat, standing, capstone)
   final name = switch (type) {
     PieceType.flat => 'Flat',
     PieceType.standing => 'Standing',
     PieceType.capstone => 'Capstone',
     _ => 'Unknown',  // This is unreachable!
   };

   // GOOD - exhaustive without wildcard
   final name = switch (type) {
     PieceType.flat => 'Flat',
     PieceType.standing => 'Standing',
     PieceType.capstone => 'Capstone',
   };
   ```

7. **Common patterns to avoid:**
   ```dart
   // BAD - unused variable
   final size = state.boardSize;  // declared but never used

   // GOOD - only declare what you use
   // (just don't declare it if not needed)
   ```

8. **Before finishing any code changes:**
   - Review all new variables - are they actually used?
   - Review all new imports - are they needed?
   - Review all function parameters - are they used?
   - Check for any widgets/methods that were replaced and can be deleted
   - **Check for cascading deletions** - if you deleted a class, search for helper classes/methods that were only used by it
   - Add `const` to constructors where all arguments are constant

## Architecture Notes

### AI System (`lib/services/ai/`)
- `ai.dart` - Base class, difficulty enum, factory
- `intro_ai.dart` - Random moves (learning mode)
- `easy_ai.dart` - 1-ply lookahead (threat detection)
- `medium_ai.dart` - 2-ply lookahead (fork detection, aggressive)
- `hard_ai.dart` - 3-ply minimax (very aggressive, deep search)
- `move_generator.dart` - Legal move generation

### Key Directories
- `lib/models/` - Game state, board, pieces
- `lib/providers/` - Riverpod state management
- `lib/screens/` - UI screens
- `lib/services/` - AI, sound, online play

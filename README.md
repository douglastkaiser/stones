# stones
Stones: An Okay Game

## Win Rules

Win detection follows the [US Tak Association rules](https://ustak.org/play-beautiful-game-tak/):

- A road connects opposite edges using exposed flat stones and capstones.
- Roads take priority over flat scoring. If a move creates roads for both players,
  the player who made that move wins; if only the opponent has a road, they win.
- With no road, a full board or an exhausted reserve ends the game. Only exposed
  flat stones count (not walls, capstones, or buried stones). Equal counts draw,
  including when a player uses their last piece.

## Development

See the [rules audit](docs/TAK_RULES.md) for official sources, verified mechanics,
and remaining gaps, and the [development map](docs/DEVELOPMENT.md) for architecture
and local testing notes.

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

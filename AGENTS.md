# Working on Stones

Stones is a Flutter implementation of Tak. Before changing mechanics, read
[the rules audit](docs/TAK_RULES.md). Read [the development map](docs/DEVELOPMENT.md)
for architecture, verification commands, and known gaps.

- Put new placement and spread validation in `lib/game/match_rules.dart`.
  Gameplay, AI simulation, review and previews must agree on legal moves.
- New Square and Hex play share the seat-based `lib/game/` engine. Read
  [the shared contract](docs/UNIFIED_PLAY_PLAN.md) before editing variants.
  `lib/hex/` and the older square models remain compatibility adapters; read
  [the legacy Hex contract](docs/HEX_MODE.md) before changing old formats.
- Resolve roads before flat scoring, using the player who completed the move to
  break simultaneous roads. A tied flat count is a draw.
- Keep rule regressions in the model/provider tests and gesture regressions in
  widget tests. Run `flutter test` and `flutter analyze --fatal-infos` after
  mechanics changes.
- Preserve existing local changes, especially Firebase configuration. Do not
  commit generated SDK/build files or replace configuration to make tests pass.
- Update the audit when a documented gap is fixed or a game variant is added.
  Distinguish core rules, optional variants, and application features.

`CLAUDE.md` contains additional analyzer conventions.

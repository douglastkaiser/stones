# Working on Stones

Stones is a Flutter implementation of Tak. Before changing mechanics, read
[the rules audit](docs/TAK_RULES.md). Read [the development map](docs/DEVELOPMENT.md)
for architecture, verification commands, and known gaps.

## Feature inventory maintenance

Before changing player-facing behavior, read the relevant entries in
[the feature inventory and regression contract](docs/SUPPORTED_FEATURES.md) and
identify affected feature IDs and adjacent journeys as regression requirements.
Keep that document current in the same change as the implementation; do not leave
its maintenance to a later documentation task.

- Add or revise entries when adding, changing, removing or repairing a feature,
  usability flow, compatibility guarantee or known limitation. Include the
  expected player-visible behavior, relevant regression journeys and an audit,
  source or available commit reference. Preserve stable feature IDs and add new
  IDs without renumbering existing entries.
- Preserve existing supported behavior unless the task explicitly changes it.
  For intentional changes, replace superseded promises and explain remaining
  compatibility or rollout limits. Keep current behavior, historical parity gaps,
  intended capabilities and deliberate exclusions distinct. A legacy feature
  absent from a newer screen is a gap to investigate, not permission to drop it.
  Update resolved gaps only when implementation and evidence justify doing so.
- For affected journeys, record what was actually verified and what remains
  untested in the task handoff and relevant audit/release record, with the build
  and platform when applicable. Keep the inventory as a durable behavior
  reference rather than a completion checklist. Automated tests alone do not
  establish usability acceptance or deployment.
- Before finishing, review the diff against this inventory. In the handoff,
  identify the feature IDs updated, or state that no inventory update was needed
  because supported behavior and its documented limits are unchanged.

## Implementation conventions

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

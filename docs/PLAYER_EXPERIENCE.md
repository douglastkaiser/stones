# Learning, replay and release quality

Implementation record, 2026-10-20. The release candidate is being qualified;
this record does not claim a deployment or a Play release. See
[the final audit](RELEASE_CANDIDATE_AUDIT.md) for current evidence and gates.

## The first ten minutes

Square setup offers four immediate starts: coached practice, ordinary computer
play, friends on one device, and an online invitation. The presets use an untimed
5×5 two-player game. Hex remains visible with an untimed radius-2 three-player
variant. Customize retains the full seat, size, difficulty and clock editor and
its saved preferences. Starting a local game still checks for an existing save.

Learn presents a nine-lesson Square fundamentals path alongside the full catalog.
Existing tutorial IDs and prerequisites are preserved. A successful lesson saves
progress before enabling Next or coached practice. Navigation exits the lesson's
isolated provider scope, so practice uses the real match controller. Learning
does not replace the player's saved game. Morocco now recognizes the nine
fundamentals; the alternative AI-win route and previously earned ownership remain.

The result explains the adjudicated cause: roads before flats, a full board or
exhausted supply before flat counting, and distinct resignation/time/abandonment
messages. Counts refer to exposed flat stones, never buried stones or capstones.

Eligible version 3 AI-only games now update shared AI rankings in both Overall
and their format. The original signed-in observer reports the saved game but
receives no personal rating or win. Duplicate and interrupted settlement use
the same immutable receipts as human games. See `SKILL_RATINGS.md` for the
reporter authorization and repeated-AI contract. This requires publishing the
updated backend rules before the client release.

## Local completed-game contract

`CompletedMatch` version 1 stores configuration, confirmed moves, terminal reason,
winner, completion time and the original session identity. Capture replays every
move through `MatchRules`. A road/flat result must match replay; only an external
resignation, clock expiry or abandonment can attach a result to a nonterminal
board. Review never invokes a live controller, awards, or rating submission.

`CompletedMatchStorage` writes a separate preferences entry per `(owner, match ID)`.
Repeated completion is idempotent; conflicting content cannot replace an existing
record. The timestamp of the first save is retained. Signed-in history is scoped
to that UID. Guests see unowned local games plus their current anonymous online
identity's games. Two accounts may retain the same online match separately.
These are device-local records, not private encryption or cross-device sync.

Completion archives before processing rewards. Failure remains retryable.
Play again is local-only, waits for completion/reward processing and rating
settlement, archives before replacing the current save, gives the new match a new
identity, and rotates the starter. Online rematch consent is not implemented.

My games displays completed history ten entries at a time. Storage filters by
owner, sorts metadata, and replays only the requested page. A damaged record is
retained and reported without hiding readable games. Key/body identities must
agree; semantically identical retries normalize moves before comparison. This is
a local archive with no automatic deletion, not a server-paginated inbox. Review
uses default appearance rather than storing historical cosmetic selections. A
failed rematch save preserves the finished game and offers a retry.

## CI and publication contract

- Flutter is pinned to 3.47.7. Changed Dart files are checked for formatting without
  rewriting source. Strict analysis, tests with coverage, Python release tests,
  web/Android compilation and emulator browser journeys run in CI.
- Browser journeys build `tools/integration_app.dart` separately. It uses only the
  demo Auth/Firestore emulators. The production entry point is unchanged.
  Separate Chromium contexts exercise learning, save/reload, cold invitations and
  reconnect. Screenshots, traces and page errors are retained even on failure.
- The weekly/manual Game Quality Evidence workflow records bounded AI playthroughs
  for Square duels, Square four-player and Hex three-player, plus shared-engine
  performance probes. Artifacts contain source/runtime, configurations, full moves,
  terminal causes, repeated positions and search timings. These small samples
  identify cases to investigate; they do not establish difficulty ratings.
- Rules tests run for every revision. Superseded validation/build jobs cancel;
  every workflow writing `gh-pages` shares one noncancelling publication lock.
  Writers pull the latest tree and use ordinary pushes. Main preserves previews;
  previews and cleanup only own their selected directory. A stale/closed PR is
  rejected before publication. Fork PR builds never receive publishing permission.
- Deploy Main accepts a full SHA from main history, defaulting to current main.
  It requires successful push CI and rules runs for that exact SHA, downloads its
  web artifact, and verifies file hashes, source, Flutter version, rules and index
  hashes before publication. It does not rebuild. Rollback selects an older
  qualified SHA while its artifact remains available (currently 14 days).
- Publication preserves the bounded previous startup assets. Consequently the
  published directory includes retained assets beyond the verified artifact.
  `release-manifest.json` describes the original CI artifact, not a fresh hash of
  the combined publishing directory.
- iOS remains unsupported until an actual iOS project and signing/qualification
  exist. Its workflow is manual-only; Android/web tags no longer trigger it.

Artifact qualification proves which source/backend contract was tested. It does
not prove those rules/indexes are deployed. Publish backward-compatible backend
changes and verify them before deploying a client that requires them. Play
distribution, repository protection settings and physical-device acceptance are
separate operational gates.

## Reproduce

```sh
flutter pub get
flutter analyze --fatal-infos
flutter test --coverage
python3 -m unittest discover -s scripts -p 'test_*.py'
flutter build web --release --target tools/integration_app.dart \
  --base-href /stones/ --output build/integration-web --no-web-resources-cdn
python3 -m pip install playwright==1.62.0
playwright install chromium
npx --yes firebase-tools@15.33.0 emulators:exec --only auth,firestore \
  --project demo-stones-hex 'python3 tools/browser_journeys.py'
flutter test tools/ai_balance_probe_test.dart --reporter expanded
flutter test tools/shared_performance_probe_test.dart --reporter expanded
```

Use `STONES_CHROMIUM` to select an installed Chromium for local checks. Do not
publish the integration build. Production web builds continue to use `lib/main.dart`.

## Qualification, October 20

Candidate `a045e37` passed [full hosted CI](https://github.com/douglastkaiser/stones/actions/runs/39497631177)
and [Firestore Rules](https://github.com/douglastkaiser/stones/actions/runs/39497631273):
996 Flutter tests, strict analysis, 29 release-tool checks, production web and
Android debug compilation, 136 authorization checks and nine complete browser
journeys with zero page errors. The final hosted web artifact was downloaded and
independently verified against its source/backend manifest, including all 77
files and the hidden Flutter build ID.

Browser evidence covers learning/Next, local save/reload, completion/review/
rematch, cold invitations, independent clients, disconnect/rejoin, an actual
computer reply, real signed-in SDK AI-only settlement in both scopes and no
duplicate award on reopen. The final phone-sized leaderboard capture shows the
updated AI profiles while the observer remains unrated. Harness Back/row selectors
were corrected to match Flutter's accessible controls. Failed reruns clear stale
captures and explicitly report failure. Static public SDK caching never caches
authentication or database requests.

Twelve longer AI games passed with rotated levels/starters across Square duels,
four-player Square and three-player Hex. All finished within the 100-ply bound,
with legal moves and no threefold-repeated positions. These VM samples do not
establish difficulty balance or physical phone latency. Full replays, logs and
source hashes are retained in `build/qa/release-audit/`.

Local external downloads and workspace connectivity interrupted some attempts;
only completed reruns and passing hosted checks count as qualification. The
[Firebase deployment](releases/FIREBASE_20261020.md) subsequently published the
exact tested rules/indexes and passed production readback/access checks. Main
promotion still requires fresh main push checks before web publication. Android
signing/store distribution, real-device and independent production-account
acceptance remain separate.

## Keep the product goal measurable

For each candidate, observe five unfamiliar players without coaching. Record
where they hesitate, recover or abandon; do not infer ease of learning from tests.
Ask each to complete fundamentals, start practice, join an invitation and explain
a road and flat result. Keep the existing target of four of five succeeding and
joining within 90 seconds after load. Record candidate SHA, device and assistance.

Review one week of completed friend games, including asynchronous return visits.
Discuss whether losses were understandable, choices felt meaningful, difficulty
labels matched expectations and players wanted another game. Investigate saved AI
replays for repetition or inexplicable moves before adjusting search or balance.
Keep changes to one learning or gameplay hypothesis per playtest round.

Before each release, exercise large text, narrow screens, keyboard/screen-reader
controls, AI/background recovery and update/reload on named physical devices.
Inspect CI failures and traces, triage feedback, and record pending gates in
`RELEASE_READINESS.md`. Avoid adding new variants to solve a confusing first game.

Account-synced progression, an account-wide active-game inbox, online rematch
consent, reminders and expanded mastery remain the staged work in
`FINISHING_PLAN.md`. Local history does not satisfy those contracts.

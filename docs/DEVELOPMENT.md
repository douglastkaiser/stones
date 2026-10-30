# Development map

The [startup and identity audit](STARTUP_IDENTITY.md) records shared branding,
initialized appearance, loader recovery, generator guards and remaining native
launch/device qualification.

The [feature inventory and regression contract](SUPPORTED_FEATURES.md) covers the
full project history, current and intended capabilities, historical parity gaps
and regression journeys. Read affected feature IDs before implementation and
keep them current in the same change as player-facing behavior.

The [Google sign-in investigation](GOOGLE_SIGN_IN_INVESTIGATION.md) records the
iOS browser missing-state report, reproducible storage/context faults, account
regressions, sanitized probes, remediation specification and pending device checks.
The [implemented recovery and remembered-account behavior](GOOGLE_SIGN_IN_FIX.md)
records early restoration, fresh web gestures, safe delayed-sign-in help and
browser-restart checks included in CI.

The [adaptive gameplay UX](ADAPTIVE_GAMEPLAY_UX.md) records compact move controls,
landscape layout, precision zoom, measured before/after tasks and device
qualification still needed.

The [playtesting feedback implementation](PLAYTESTING_FEEDBACK.md) tracks the
18 latest feedback items, confirmed production ratings diagnosis, feature changes,
calibration evidence and remaining device qualification.

The [player-experience implementation](PLAYER_EXPERIENCE.md) documents setup
presets, the fundamentals path, local history/review/rematch, emulator browser
journeys and qualified-artifact publication. It includes reproducible checks and
the boundaries of the remaining account/inbox/reminder work.

The [home/profile and table-layout follow-up](COMMUNITY_AND_LAYOUT.md) documents
public Stones names, restored QR invitations, responsive boards and opt-in Open
tables, with emulator evidence and the rules-publication prerequisite.

For the current finishing-work handoff, start with [environment handoff](ENVIRONMENT_HANDOFF.md).

For current release evidence and pending physical-device qualification, start
with [release readiness](RELEASE_READINESS.md). The [finishing plan](FINISHING_PLAN.md)
records the approved product direction and staged work. Older sections below
retain historical verification notes; their SDK paths/test counts are not current
release claims. New gameplay uses the shared `lib/game/` architecture described next.

The [2026-10-23 AI upgrades](AI_UPGRADES.md) describe the current v3 source
candidate, full-round multiplayer search, cache/tactics/material/repetition work,
frozen reference tooling and remaining strength/timing qualification. Human-only
rank numbers and clickable personal standings are tracked in the rating contract.

See [skill ratings](SKILL_RATINGS.md) for the version 3 Overall/format ladders,
shared human/AI Glicko-based ratings, uncertainty UI, unordered multiplayer losses
and Spark settlement/recovery protocol. [Ratings and competition](RATINGS.md)
retains the version 1/2 audit and historical publication evidence.

The [achievement progression audit](ACHIEVEMENTS.md) records the 25-goal mastery
ladder, replay evidence, unified learning, save migration and qualification.
The [account-progress foundation](ACCOUNT_PROGRESS.md) records packet 4's merge
contract, cache repository and verified-event adapters, with backend/UI integration
still pending. [Player feedback](FEEDBACK.md) describes the Settings/About support
flow, data boundaries and report triage.

The [2026-10-16 multiplayer reliability audit](MULTIPLAYER_RELIABILITY.md)
records startup deadlines, nonblocking shortcut storage, bounded automatic
recovery, subscription and identity guards, multi-client fault qualification,
regression evidence and current rollout status.

The [unified play expansion plan](UNIFIED_PLAY_PLAN.md) records the architecture
and execution evidence for one setup, seat-based engine, controls and room
protocol for two to four players on Square or Hex. New play and learning now use
`lib/game/`. Production `/matches` rules are published and passed six independent
live API trials. Web startup fingerprinting and bounded previous-release retention
are deployed; a hosted four-seat mixed Hex room passed human/AI/remote turns and
reload recovery. A fresh Play Console check on 2026-10-17 confirms Android 403
is available to Alpha closed testers with full rollout; internal testing remains
385. See release readiness for current qualification and newer web-only changes.
Check the plan and [release record](releases/ANDROID_403.md) for actual rollout evidence.

The [result sharing and placement Elo contract](RESULT_SHARING.md) documents
version 2 standings, globally rated AI, the combined leaderboard, persisted Elo
deltas, native/SMS/copy sharing and final-board PNG export. Its placement-Elo
protocol remains for version 2 saves; new configurations use version 3 skill
ratings. Missing saved metadata preserves the legacy rating protocol.

The current shared path is `MatchSetupScreen` → `MatchController` →
`MatchRules`/`MoveSelection` → `MatchScreen`/`BoardView`. `BoardGeometry` supplies
topology; `MatchConfig` supplies seat order, controls, opening, size and optional
Court/clock settings. `MatchRoomStore` owns transactional `/matches` sessions,
server-confirmed clocks and recoverable AI runner leases. `MatchStorage` saves
local history before exposing a move. `StudyController` uses the same shell in
an isolated sandbox. `MatchCompleted` drives an idempotent achievement ledger.
`room_navigation.dart` is the invitation/recovery dispatcher for new and old
wire formats. Old providers/screens remain only for old session compatibility;
`GameRules` and `HexRules` now forward validation/generation to `MatchRules`.

Historical baseline, 2026-10-10. Read [the Tak rules audit](TAK_RULES.md) before changing game
mechanics; it includes the prioritized follow-up findings.

## Repository and local state

Remote: `https://github.com/douglastkaiser/stones.git`.
The initial refresh fast-forwarded `main` to `b409e0273ca9d08d1b697513659cd938923e824d`.
The prior local formatting change in `android/app/google-services.json` was
discarded at the user's request before pushing the rules audit commit.

The legacy three-player models/codecs remain under `lib/hex/`; read
[their rules and protocol contract](HEX_MODE.md) before changing compatibility.
The [Hex victory audit](HEX_VICTORY_AUDIT.md) explains the reported left-edge
connection, shared opposite-side goals, legacy room compatibility, and independent adjudication checks.

The [playability audit](PLAYABILITY_AUDIT.md) records player-journey questions,
UX improvements, browser trials, automated evidence and remaining product work.
The [current stack interaction](STACK_INTERACTION.md) documents persistent
inspection, hold-to-expand on the board, source-tap/layer/minus-plus pickup,
current-drop minus-plus alongside board taps, explicit spread drafts, live drag
feedback and shared piece depth. Use its 2026-10-23 contract when older control
reviews describe superseded pending-drop or hold-to-open-tray behavior. The [shared stack display](STACK_DISPLAY.md) records
layer rendering, hover and
touch inspection across square and Hex, including owner themes and previews.

The [Android and account audit](ANDROID_AND_ACCOUNTS.md) records Firebase
identity ownership, Google sign-in, signing/release checks and device trials.

## Code map

- `lib/models/board.dart`, `piece.dart`: immutable board positions and bottom-to-top
  stacks. `PieceStack.pop` removes a top portion while preserving its order.
- `lib/models/game_state.dart`: reserves, phase, turn, and result. Opening lasts
  two individual moves; `turnNumber` is a round counter, not a move-log index.
- `lib/models/game_rules.dart`: pure placement/spread transforms, legal spread
  patterns, and terminal flat counts. Successful transforms do not advance turns.
- `lib/providers/game_provider.dart`: gameplay orchestration, undo/history,
  notation, turn advancement, win detection, and animation callbacks.
- `lib/providers/ui_state_provider.dart`: selection, carried pieces, committed
  drops, pending drop, reachable completion squares, and ghost previews.
- `lib/main.dart`: most of `GameScreen`, board rendering, taps/swipes, planner,
  AI scheduling, and integration with online/scenario state. The file under
  `lib/screens/game_screen.dart` re-exports it; it is not a second implementation.
- `lib/services/ai/ai.dart`: AI interface/factory. All difficulties use
  `lookahead_ai.dart`; easy/medium search depth 2, hard 3, expert 4, with different
  branch limits and jitter. `move_generator.dart` delegates legality to GameRules;
  `board_analysis.dart` supplies road and evaluation analysis.
- `lib/providers/online_game_provider.dart`, online models/services: Firebase
  game sessions and notation replay. See the audit before changing synchronization.
- `lib/models/scenarios/` and `lib/providers/scenario_provider.dart`: nine tutorials
  and ten verified square studies, tutorial guidance, puzzle budgets and progress hooks.
- `firestore.rules`: checked-in backend access policy, not proof of deployed policy.

## Move lifecycle

1. A tap/swipe builds a preview; its source board is unchanged.
2. Confirmation calls the game notifier. GameRules validates and constructs the
   entire resulting board before any history or animation side effects.
3. The notifier records the successful move and advances the turn.
4. Resolve roads with the pre-move player as `lastMover`, then resolve flats.
   AI simulations must use that same mover convention after advancing the turn.
5. UI, online recording, scenario progress, and AI scheduling react to the result.

Do not check victories after individual drops inside a spread. Do not infer the
mover from `currentPlayer` after the turn has already advanced.

## Verification and running

```sh
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter run -d chrome
flutter build web
```

For focused rules and controls verification:

```sh
flutter test test/models/game_rules_test.dart test/providers/win_detection_test.dart
flutter test test/widgets/stack_gesture_test.dart
```

The machine's original Flutter checkout was incomplete. This session uses a
temporary Flutter 3.47.7 / Dart 3.13.5 SDK and a separate temporary package cache:

```powershell
$env:PUB_CACHE = "$env:TEMP\stones-pub-cache"
& "$env:TEMP\stones-flutter-sdk\bin\flutter.bat" test
& "$env:TEMP\stones-flutter-sdk\bin\flutter.bat" analyze --fatal-infos
```

These temporary directories are machine-specific, not project requirements.
SDK-generated build/cache/config files are excluded locally in `.git/info/exclude`.
This SDK may automatically insert analyzer exclusions for platform/build paths;
avoid accidentally including that unrelated generated edit in a rules change.

### Audit verification

See [movement UX](MOVEMENT_UX.md) for the carry/drop interaction contract,
usability questions, regression coverage, and future square/Hex improvements.
The [play selector](PLAY_SELECTION.md) explains the common board/opponent
hierarchy and controls. `board_cell_gestures.dart` shares gesture recognition;
`hex_move_selection.dart` shares Hex match/exercise planning and controls.
The first movement revision passed the complete 244-test suite, strict analysis,
and a release web build, with phone/desktop browser trials.

The latest playability audit passed all 176 tests, and `flutter analyze --fatal-infos`
reported no issues using the temporary SDK listed above. Four additional
targeted Hex/isolate tests also passed, bringing current coverage to 180 tests.
Two widget regressions exercise actual flings/taps (swipes require velocity),
including safe screen disposal. Model fixtures cover published spreads and reject
invalid moves without state/history changes. Online multi-client, deployment,
Android device, and exhaustive tutorial playthrough checks remain separate work.

### Theme and Hex learning iteration

See [theme design](THEMES.md) for the five-set visual contract, saved-index
migration and rendering repair. Hex learning is isolated in `lib/hex/`:
`hex_exercises.dart` supplies tested positions and `hex_learning_screen.dart`
handles previews, objectives, retry and independent progress. Both square and
Hex use the same cosmetic painter factories; the gallery renders those factories
rather than surrogate color swatches.

Online cosmetic metadata lives in square `OnlineGamePlayer.pieceStyle` and
Hex `HexRoom.pieceStyles`. `shareablePieceStyleProvider` validates the local
selection against paired rewards before publishing. `match_theme_badge.dart`
provides in-match inspection without awarding cosmetics. Square cell rendering
uses an owner-color lookup for all stone/ghost/inspection paths; Hex receives
the room's seat styles explicitly, leaving its learning sandbox independent.
See THEMES.md for the wire compatibility and backend deployment requirements.

## Speed and room recovery iteration

Read [performance and recovery](PERFORMANCE_AND_RECOVERY.md) for the resume
contract, timing measurements and remaining online boundaries. Local room
shortcuts use `saved_rooms_provider.dart`; Firebase remains authoritative.
`online_replay.dart` validates recorded square moves before applying shared
GameRules. Square mode changes detach online subscriptions. Hex retains
independent replay/seat authority and now applies only appended moves on updates.
AI browser work cooperatively yields during ranking and recursive search; square
AI uses completed iterative-deepening results with difficulty-specific budgets.

## Court Mode

See [Court Mode](COURT_MODE.md) for optional Square/Hex coaching with local or
online humans, threat warnings, local takebacks and unanimous online takebacks.
Court sessions are untimed, unrated practice; AI-only observation is excluded.
Core move validation remains in MatchRules, with GameRules as a legacy adapter.

## Verified puzzle studies

Read [the puzzle audit](PUZZLE_AUDIT.md) before changing puzzle content. Original
square/Hex study catalogs have exact supplies, full finite-horizon proofs and
checked-in response certificates. Proof search is authoring/test work, never
interactive UI work. Square puzzles use ScenarioState budgets and certified
defenses; Hex keeps independent learning state and progress. Catalog replacement
uses new IDs while preserving existing achievements and saved progress.

Web release preparation runs `scripts/prepare_web_release.py` after compilation
in CI, deploy and previews. It fingerprints the JavaScript entrypoint and bootstrap
without changing gameplay. Main deployment retains two previous startup pairs for
cached HTML, with exact filename validation and bounded storage. The six Python
checks run with `python -m unittest scripts.test_prepare_web_release`.

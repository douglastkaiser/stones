# Development map

Updated 2026-10-09. Read [the Tak rules audit](TAK_RULES.md) before changing game
mechanics; it includes the prioritized follow-up findings.

## Repository and local state

Remote: `https://github.com/douglastkaiser/stones.git`.
The initial refresh fast-forwarded `main` to `b409e0273ca9d08d1b697513659cd938923e824d`.
The prior local formatting change in `android/app/google-services.json` was
discarded at the user's request before pushing the rules audit commit.

The selectable three-player variant is isolated under `lib/hex/`; read
[its rules and protocol contract](HEX_MODE.md) before changing it.
The [Hex victory audit](HEX_VICTORY_AUDIT.md) explains the reported left-edge
connection, shared opposite-side goals, legacy room compatibility, and independent adjudication checks.

The [playability audit](PLAYABILITY_AUDIT.md) records player-journey questions,
UX improvements, browser trials, automated evidence and remaining product work.
The [shared stack display](STACK_DISPLAY.md) records layer rendering, hover and
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

See [Court Mode](COURT_MODE.md) for the optional square AI coaching contract,
source customs, threat warnings, takeback semantics and verification. Court
sessions are untimed, unrated practice; core move validation remains GameRules.

## Verified puzzle studies

Read [the puzzle audit](PUZZLE_AUDIT.md) before changing puzzle content. Original
square/Hex study catalogs have exact supplies, full finite-horizon proofs and
checked-in response certificates. Proof search is authoring/test work, never
interactive UI work. Square puzzles use ScenarioState budgets and certified
defenses; Hex keeps independent learning state and progress. Catalog replacement
uses new IDs while preserving existing achievements and saved progress.

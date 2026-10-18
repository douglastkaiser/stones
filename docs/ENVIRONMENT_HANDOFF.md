# Stones environment handoff

Updated 2026-10-18. Continue the existing finishing effort; do not restart the audit.
The user is moving to a better coding environment. Preserve current source and
local data. Read AGENTS.md, CLAUDE.md, DEVELOPMENT.md and FINISHING_PLAN.md first.

## Checkout and deployment state

- Repository: https://github.com/douglastkaiser/stones
- Branch: `codex/finishing-foundation` (pushed). Latest functional qualification:
  `b8666a5c0da0a231f36a48a6abc8d8fa8c88d8ed`. This handoff follow-up applies only
  the CI formatter to three tests and updates documentation.
- Main/origin main, checked against GitHub: `4ac6485734b90cb6c088c51f616f92004d6c49ea`.
  Finishing work has NOT been merged or deployed to the production game root.
- Real app review: https://www.douglastkaiser.com/stones/pr/finishing-game/?review=b8666a5
- Sample-only visual review: https://www.douglastkaiser.com/stones/pr/finishing/?review=b8666a5
  The old `?review=431cb20` browser tab is the design sample, not the real app.
- Real app review uses normal accounts/services/storage. Both review paths are
  hosted under the same origin as production, so local browser storage is shared.
  Do not clear storage or overwrite existing games to simplify testing.
- `.codex-remote-attachments/` is untracked user material. Leave it alone.
- No Firebase policy/configuration or Play track/release changed in this packet.
- Last Play Console check: Alpha closed testing 403 available; internal 385;
  production inactive, three opted-in testers, displayed gate 12 testers for
  14 continuous days. These finishing changes are NOT a new store release.

## Approved direction and lessons

The owner approved the second visual direction and said to keep going. They
rejected "Pull up a chair", fireside/hospitality copy and the corporate landing-page
feel. Keep direct play/learn language, restrained personality, warm crafted boards,
ink/paper/copper surfaces, readable sans controls and serif identity. Let actual
pieces and short examples explain the game. Do not reintroduce a marketing hero.

Square leads, Hex remains visible. Both use the SAME configurable two-to-four-seat
setup and engine/controls, mixing local humans, online humans and on-device AI.
Exactly five quality cosmetic sets, no additional modes/social features for now.
Variants must be clearly distinguished from standard Tak. Maintain stationary
boards and common stack/movement behavior across shapes.

Quality is about completing reliable friend-game journeys, not accumulating
features. Offline/local play must stay fast and available. Game AI remains on the
participating devices. Firebase stays on Spark; do not add Blaze/cloud AI. Existing
rating evidence/consensus has limitations against colluding malicious clients;
do not describe client verification as cheat-proof. A small free-tier notification
service is allowed by the plan, but no paid infrastructure is assumed.

Remaining confirmed gameplay decisions (NOT implemented in this packet):
- Optional cumulative chess-style clocks, including long games.
- With more than two players, timeout skips future turns and preserves all pieces;
  normal blocking/capture/carry still applies, inactive players cannot win, the
  last active player wins. Preserve old room versions' semantics.
- Explicit group resignation offers an AI replacement; continuation is unrated.
- A welcoming early cosmetic reward, with other sets earned through substantial
  skill challenges. Cross-device earned progress is required for release.

## Finishing-plan status

1. Baseline tooling/inventory implemented; physical-device performance and account
   trials remain pending. HTTP/VM observations are not phone frame-rate evidence.
2. Revised visual prototype approved and reused in actual app code.
3. Home/setup/invitations implemented and code-qualified. Independent invitee and
   Play-signed device trials remain. Finish these gates before calling it complete.
4-12. Not implemented by this finishing effort. Follow FINISHING_PLAN.md one packet
   at a time; later work covers account progress/migration, account game index,
   group forfeiture/timeouts, result/rematch loop, asynchronous reminders,
   learning/progression, visual finish, privacy/account lifecycle and release QA.

## Current implementation

- `lib/widgets/game_menu.dart`: actual app and preview share this menu. Square/Hex,
  Join, My games, Learn and real-renderer road/stack examples. Navigation callbacks
  are injected, so production does not import the sample app.
- `lib/game/example_position.dart`: explicitly labeled visual fixtures, never
  saved games or achievement evidence. `design_preview.dart` retains a fixture
  compatibility wrapper for tests.
- `lib/theme/tavern_theme.dart`: approved shared theme despite its historical
  filename/class names. Bundled StonesSans/StonesLora, no runtime Google Fonts
  in the root theme. Existing board/piece painters retain their silhouettes.
- `lib/main.dart`: actual app theme plus cold/warm invitation routing.
- `lib/screens/main_menu_screen.dart`: real menu/navigation, signed-in rating chip,
  settings, achievements, leaderboard and About. Initialization preserved.
- `lib/screens/saved_games_screen.dart`: DEVICE game recovery and old shortcuts;
  it is not the future account-backed cross-device game index.
- `lib/game/match_setup_form.dart`: same editor; advanced starter/clock/practice
  explanations grouped under Game settings. All seat combinations preserved.
- `lib/game/join_room_screen.dart`, `room_invitation.dart`,
  `invitation_navigation.dart`, `room_navigation.dart`: one parser and join screen
  for links, typed codes, initial web/native routes and native pushRoute.
  Canonical URL: `https://www.douglastkaiser.com/stones/?room=UABCDEF`.
  Accepts existing U/H/seven-character and legacy six-character room formats.
  Rejects foreign URLs, credentials, ports, duplicate room parameters and unrelated
  paths/fragments. Internal web routing supports preview base paths too.
- Opening a link displays a join form; it never claims a seat automatically.
  Active-game switches ask first. Saved-room identity is checked before leaving.
  `MatchController.join` retains the current game until server acceptance, so a
  full/rejected/failed new-style join preserves its board, AI and durable history.
  Existing epoch guards and bounded network timeouts remain in place.
- `lib/widgets/room_invitation_actions.dart`: selectable canonical link, copy-link,
  copy-code and share. Android shares via MethodChannel `stones/invitations` and
  ACTION_SEND; web/unsupported/old binaries fall back to copy. No new package.
- Android MainActivity and manifest wire sharing and HTTPS `/stones/` delivery.

## External website change (already deployed)

The root association file returned 404. We read Play Console's Digital Asset Links
snippet and published exactly that public app-signing fingerprint, not the upload
certificate. Exact payload is `docs/android/assetlinks.json`.

- Separate root website repo: `douglastkaiser/douglastkaiser.github.io`, main.
- Commit: `ba451723d035df7683570d3f96c1b983d855e8e3`.
- Only added `.well-known/assetlinks.json`, preserving the existing tree.
- Root-site workflow run 39097313842 succeeded.
- https://www.douglastkaiser.com/.well-known/assetlinks.json returned HTTP 200,
  `application/json`, and exactly the expected Play statement.
- No signing key, Play protection setting or account permission was changed.
- Actual app-link association/cold-warm delivery on a Play-signed installation and
  the native sharesheet have NOT been physically tested. Debug signing does not
  match the Play association. Do not call Android installation qualified yet.

## Verified evidence

Functional source `b8666a5`:
- Full CI https://github.com/douglastkaiser/stones/actions/runs/39097647956
  All 833 tests, strict analysis, release web and Android debug builds succeeded.
- Review CI https://github.com/douglastkaiser/stones/actions/runs/39097647931
  81 focused tests, 16 bounded AI VM probes, 30 captures, both isolated web builds.
- Pages run 39097853805 succeeded.
- Real app's live source, HTML/bootstrap linkage and startup hashes passed the
  baseline check with `--expected-source b8666a5`.
- CI artifacts include `finishing-review-b8666a5...` (id 12124937579), actual-app
  artifact 12124987316 and design artifact 12125595593. Local evidence folders:
  `build/qa/first-game-final/`, `build/qa/first-game-review/`.
  Build folders are ignored and may not transfer: use the GitHub artifacts.
- 24 sample captures plus 6 actual home/setup captures. Actual captures include
  320/1366 widths at 150% text; existing menu checks also cover 200% signed-in
  text in light/dark. Debug banners in test captures are not release UI.

Live actual-app trial at a5a1106 (same UI/runtime flow as b8666a5 except preview
cold-link normalization): invalid foreign invitation gives editable recovery;
My games retains the pre-existing Hex shortcut; Square -> AI -> Court -> double-tap
opening -> AI reply and explanation -> leave -> My games -> resume preserves both
moves. Hex starts with three seats, grows to four, reduces to two, and attempting
a new local game asks to replace the trial save; Keep saved game cancels.

The browser now has a newly created Square Court practice save containing those
two opening moves. Existing online shortcut UUITBOA was observed but not joined,
deleted or played. Do not mistake the practice save for a pre-existing user game.

Two old regressions needed expectation corrections: the copy button is now
"Copy code", and lifecycle tests must simulate inactive/hidden/paused and
hidden/inactive/resumed. SelectableText introduced a listener that correctly
rejected the old impossible paused-to-resumed shortcut; do not remove its asserts.

## Next environment / immediate next work

1. Check out the pushed finishing branch. Inspect status and read the plan/docs.
   Do not merge to main merely to obtain a running review; the real app review
   URL already exists. New production/store deployment requires the release gates.
2. Install/use pinned Flutter 3.47.7, Java/Android SDK and enough disk space. The old
   Windows environment had no Flutter/Dart SDK and about 2.4 GB free, so it used CI
   for all Dart analysis/testing/formatting. Do not copy generated SDK/build files.
3. Run `flutter pub get`, `flutter analyze --fatal-infos`, `flutter test`.
   Fast relevant suite:
   `flutter test test/design_preview_test.dart test/game/first_game_flow_test.dart test/game/match_screen_test.dart test/widgets/play_selector_test.dart`.
   `--dart-define=STONES_CAPTURE_PREVIEW=true` writes the review PNGs.
4. Complete packet 3's independent-user invitation and Play-signed device checks;
   preserve all existing room codecs and saved-game safety. Canonical invitations
   target the production root, so current branch testing should paste that link
   into the review's Join screen or use its `?room=...` startup route. The old
   production game has not received this new URL handler yet.
5. Then proceed to packet 4: specify and test account-scoped progress migration,
   legacy import, idempotency, offline/concurrent devices, account switching and
   explicit guest/existing-account merge BEFORE deploying storage/rules changes.
   Preserve earned unlocks; do not sum snapshots or invent historical evidence.
6. Read RELEASE_READINESS.md, FIRST_GAME_INVITATIONS.md, RATINGS.md,
   MULTIPLAYER_RELIABILITY.md, ANDROID_AND_ACCOUNTS.md for existing protocols and
   gaps. Physical mobile sign-in/performance, account deletion/privacy accuracy,
   cross-device progress and account game discovery remain release work.

The user authorizes routine implementation, commits and pushes along the way.
Do not ask repeated permission for already-authorized reversible work. Do not
spawn agents without explicit user/repository authorization. This handoff is not
completion of the twelve-packet finishing plan.

# Court Mode

## Current shared Court practice (2026-10-28)

Square and Hex setup offer **Learn with the computer**, whose description names
Court Mode, hints, Tak! warnings and takebacks. **Customize → Game settings**
always shows the Court Mode switch. Previously Customize defaulted to all local
humans and omitted the switch entirely, making it appear that the feature was
missing. Ineligible configurations now show a disabled switch with guidance:
choose at least one AI, retain at least one local human, and replace any online
seats. Eligible configurations can enable Court immediately. Eligibility, untimed
practice, rating/award exclusions and the threat sound are unchanged.

Before an offline Court AI turn after human play, the controller checks for an
exact legal one-move win with the existing tactical enumeration and MatchRules
adjudication. If one exists, it freezes play and active elapsed time before AI
search or submission. The board remains inspectable and the fixed action area
shows **Tak! [seat] can win next move**, **Take back**, and **Let AI play**.
Take back restores the last human decision and removes subsequent AI replies;
Let AI play explicitly commits the verified winning reply, after which normal
finished-Court takeback remains available. Generic Resume cannot bypass the
decision. Draws and nonwinning replies do not trigger the pause.

The check includes placements, complete spreads, capstone flattening, road and
flat wins on Square/Hex with two through four seats. Web work yields and native
work uses an isolate; navigation/position tokens reject stale results. It checks
the current AI's actual turn, rather than predicting intervening opponents'
moves. Further AI seats are checked when their turns arrive. Ordinary games and
isolated studies do not receive this interception; core legality is unchanged.

The local save records the winning reply alongside the confirmed history. Reload
validates it by replay and restores the paused decision. Failed takeback or
continuation writes leave the position and choice retryable. No AI win is exposed
or processed before its move is saved.

Regression journeys cover touch swipes and mouse-wheel navigation through both
expanded setup sections at 150% text on Square and Hex, disabled-to-enabled Court
after selecting an AI, and online/AI-only exclusions. See
`test/game/court_setup_navigation_test.dart`. Adjacent checks cover mixed seats,
saved size/clock preferences, replacement cancellation, learning and quick starts.
`test/game/court_winning_reply_test.dart` covers automatic interception before AI
search, durable reload/takeback, explicit continuation and terminal takeback,
ordinary-game isolation, movement-only flattening wins, flat wins versus draws,
three/four-seat rewind, and failed save retries. Portrait and landscape widget
journeys check both visible choices at 150% text on both shapes.

Verification on Flutter 3.47.7 / Linux: all 27 focused Court setup/interception
tests pass; the full suite passes all 1,921 tests. Strict analysis reports no
issues, and the release web build passes (with the existing secure-storage Wasm
dry-run and Cupertino font warnings).
A localhost Chromium mobile viewport (390×700) checks the disabled switch and
explanation, then replays a Square human mistake through the actual web app:
the AI's sixth move is held, Take back durably restores four moves, and a repeated
mistake followed by Let AI play saves the winning sixth move. Browser API traffic
was blocked; no production game/account was used. Screenshots are generated at
`build/qa/court/disabled-court-mobile.png` and `court-paused-mobile.png`.
Hosted builds and physical devices have not been qualified for this change.
Feature IDs: SETUP-01, LEARN-02, LEARN-08 and SAVE-08.

## Historical legacy implementation (2026-10-09)

The sections below describe the older Square screen; current shared setup,
durable recovery and coaching use `lib/game/` (see [development map](DEVELOPMENT.md)).

## Source and scope

The publisher's [Tak Companion Book](https://crabfragmentlabs.com/s/TakCompanionBookPDF.pdf),
printed pages 29–31 (PDF pages 33–35), describes courtly play as a style of
courteous, considered play: call Tak, allow mistakes to be taken back, and help
teach a less experienced opponent. It does not change placement, spreading or
victory rules. The fictional social customs about capstones are not a new scoring
system. Stones' coaching interface is an application feature inspired by this
style, rather than a publisher-defined AI variant.

## Player flow

- In **Play vs Computer**, turn on **Court Mode**. It defaults off for new sessions.
  It is also available in the in-game computer setup dialog.
- Choose any square size, difficulty and human color. The opponent keeps the
  selected difficulty; the on-demand coach uses Expert's bounded search.
- **Ask coach** suggests a legal move, describes coordinates and spread drops,
  and explains its concrete effects. Keep thinking or explicitly play it.
- After an AI move, tap **Why that AI move?** to read its explanation. When a
  warning is present, tap the warning to see it and the same explanation.
- **Tak!** warns when either player has a legal road win in one move from the
  current position. Threat analysis checks both placement and stack movement,
  including wall flattening and mover priority for simultaneous roads. A warning
  is conditional on the position remaining unchanged, not a forced-win claim.
- **Take back** returns to the last human decision, removing its AI reply when
  appropriate. Repeat to go further back. Finished games can be reopened through
  a takeback. While a search is running, wait for it to finish before undoing.
- Court is untimed practice and does not award achievements or update ratings.
  Clock preferences for other modes are preserved. Online, local two-human,
  tutorials, puzzles and the separate experimental Hex variant keep their
  existing behavior.

## Implementation contract

`GameSessionConfig.isCourtMode` requires a computer game without a scenario.
`CourtCoach` uses GameRules for simulations and BoardAnalysis for road winners.
Move commentary explains observed consequences (road joins, captured control,
source control, wall flattening, flat scoring and the opening exchange). It is
not generated by a language model and does not invent a search narrative or
promise that a move is optimal.

The coach never mutates the board while calculating. A suggested move is applied
only after explicit selection and only if both position and session still match
the search request. Browser search yields cooperatively; native search and
warning analysis run outside the UI isolate. Late results after navigation or a
position change are ignored. Takebacks suppress AI scheduling while restoring
multiple historical states so the AI cannot reply to an intermediate rewind.

History lives in the existing in-memory local session: Home/Continue retain it,
but a full browser reload does not persist an offline Court match. Online room
recovery is a separate feature. No Firebase deployment or new dependency is
required for Court Mode.

## Verification

`test/audit/court_mode_test.dart` covers mode isolation, opening commentary,
capstone spread effects, invalid suggestions, movement-only Tak warnings, and
finished-move takebacks for White and Black across phone, landscape and desktop
layouts. `court_interaction_test.dart` adds repeated rewinds, terminal AI replies,
Black's opening-seat guard, enlarged text with stored clock preferences, and
replayed wins without achievement awards.

Verification: the full 305-test run passed 304 tests; the remaining new Court
widget test required waiting for the existing 200 ms AI scheduling / 500 ms
indicator timers. After correcting its timing, all 16 Court regressions passed
on a focused rerun. Strict analysis reported no issues. This was a test timing
repair, not a change to the opponent's scheduling.


The release JavaScript web build passed. In the localhost browser trial, a hint
was requested and explicitly played, the AI reply and its explanation were
verified, both moves were taken back to the initial position, and dismissing
another hint left the board unchanged. Desktop and 390×844 phone viewport checks
confirmed readable dialogs and usable controls; no browser error/warning logs
were captured. Physical Android/iOS devices were not used. The existing secure
storage WebAssembly compatibility and Cupertino font build warnings remain.

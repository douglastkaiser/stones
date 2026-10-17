# Achievement progression audit — 2026-10-16

Achievements are an application feature, not a change to Tak or the Square/Hex
variant rules. The v2 collection has 25 achievements in Learning, Board craft,
Competition and Mastery, with Bronze/Silver/Gold/Platinum tiers worth
15/35/70/120 points. Collection ranks are Apprentice (0), Craftsman (150),
Tactician (400), Master (850) and Legend (1400). They are not Elo ratings.

## Findings and repairs

- Eleven placeholder badges awarded most cosmetics for one easy result. The new
  ladder needs repeated wins, minimum opponent strength, board/seat variety,
  online opponent variety and verified winning techniques.
- The achievement screen said Hex never counted, although the shared controller
  awarded some Hex wins. Hex and multiplayer learning bypassed the ledger
  entirely. All current learning catalogs now share one persistence path.
- Only wins were recorded, making a reliable winning streak impossible. Qualified
  losses and draws now reset the current Hard+ duel streak; practice does not.
- Only win writes were serialized. Concurrent load/tutorial/puzzle/unlock/reset
  work could overwrite newer progress. All progression operations now share one
  queue and one versioned durable commit, including match deduplication and all
  unlock notifications. Failed writes publish no reward or count.
- Replay IDs included terminal metadata. Match awards now use the stable session
  ID, with normalization of the previous ledger's ending suffixes.
- A hidden About-screen gesture unlocked everything in release builds. Developer
  unlock/reset gestures now execute only in debug builds.
- Shared-engine results had no complete unlock presentation. A grouped snackbar
  shows awards/points with a View action; it does not displace the board. The
  achievement gallery has track/status filters, individual requirement progress,
  earned dates, a next goal, earning rules and learning/reward navigation.

## Qualification contract

All new match statistics require a complete, legal replay from an empty board,
matching the confirmed board, reserves, turn count and natural terminal result.
Preview/study positions and incomplete compatibility saves cannot fabricate wins.
Replay runs once on completion, not on every move or rendered frame.

Square match awards require size 5–8; Hex supports radii 2–4 and either shape
supports two through four seats. There must be an individually attributable
human seat. Court, spectators and local pass-and-play earn no match awards.
In online games each human seat must have an independent owner; winning against
only online-hosted AI does not become an online-human win. All results are
recorded once, including losses relevant to a streak.

Natural road/flat wins count toward general wins. Online resignations/timeouts
count only after four complete turn cycles and only toward general/online wins.
Early concessions and clock wins never earn specialist or board-craft credit.

AI duel tiers use unassisted standard two-player Square games, size 5+, won by
road or flat scoring. Easy/Medium/Hard/Expert targets are 3/5/10/12 victories.
A stronger victory also advances lower tiers. Expert additionally requires two
board sizes. An online-hosted AI duel follows the same strength criteria, but
does not become an online-human win. Every AI opponent must meet a challenge's stated strength; one weak
AI in a mixed table cannot masquerade as an all-Hard win.

Board craft needs Medium+ AI or independently owned online opponents, with no
weak AI mixed in. Goals include 25 roads, 10 flat wins, 5 timed board wins,
10 capstone roads, 5 winning wall crushes and 5 winning spreads over at least
three cells. Crush/spread evidence comes from the final replayed move, rather
than guessing from an end-board capstone. Mastery adds Hard+ wins on Hex, both
shapes, three/four-player tables, large boards and a five-win Hard+ duel streak.
Online milestones require both 5/25 wins and 3/10 different human opponents.

Learning awards use known current catalog IDs, including both shapes and
multiplayer studies. Hinted completion counts toward library completion.
Clear Mind requires three unaided studies on each shape. Opening a hint marks
that visit as assisted, including Retry; revisiting and solving independently
may upgrade an already completed study's unaided mark. Previously completed
studies are never silently assumed unaided. Failed progress storage can be
retried from a solved study without replaying its solution.

## Save migration and limits

`achievement_progression_v2` is the authoritative SharedPreferences document.
It stores metrics, distinct evidence tags, stable match IDs, learning/unaided IDs,
all earned flags/dates and pending notices. A failed commit retains the previous
save and visible counts. Malformed/unsupported saves are not overwritten; the
screen exposes a load retry. The old v1 win ledger, flags, Square learning,
Hex learning and unified learning keys migrate without inventing missing
specialist history. Startup recognizes newly introduced achievements supported
by known saved learning IDs or general counters, without requiring another game
or solve. Unknown unlock names survive a subsequent save.

Previously earned achievements and all five paired cosmetic sets remain earned,
even where requirements increased. They are marked Previously earned; no
historical award date or skill evidence is invented. New challenges start from
available evidence, while legacy general win counts are retained. Reset writes
an empty authoritative v2 document so stale legacy keys cannot resurrect data.

Progress remains device-local. Firebase/Google sign-in does not synchronize it,
and these are not server-attested competitive credentials. No new database rules,
account permissions, reward assets or dependencies are needed. Optional native
Play Games configured IDs/cloud saves are a separate legacy integration; the
25-item catalog is not claimed as a published Play Games achievement catalog.
Cross-device account progression and server-attested results require a separately
designed merge/ownership/backend contract, rather than trusting uploaded counters.

## Verification and rollout

The regression suite uses legal histories from empty boards, rather than manual
win flags. It covers both shapes with two/three/four seats, difficulty inheritance,
weak-opponent exclusion, opponent variety, capstone/crush/spread evidence,
loss/draw streak resets, meaningful/early concessions, stale/duplicate results,
learning with and without hints, migration, failed storage, corruption/future
schemas, notifications and restart/reset behavior. A full collection trial must
reach every achievement through those histories and catalog completions.
Widget trials cover phone/desktop, both brightness modes, enlarged text,
track/status filters, earning rules and progress-save retry.

Qualified at `a078f04` in [CI run 38976082886](https://github.com/douglastkaiser/stones/actions/runs/38976082886):
753 tests passed, `flutter analyze --fatal-infos` reported no issues, and the
release web and Android builds passed. The normal CI workflow is unchanged.

Physical Android/browser trials remain distinct from Flutter widget/model tests.
Play Store users require a new Android release containing the shared client changes.


Publication: main `0a7c05c` was built by [Deploy Main 38993885310](https://github.com/douglastkaiser/stones/actions/runs/38993885310).
The public startup ledger serves `main.d6b358c305a5918a954c.dart.js`; fetching that
bundle confirmed the deployed commit, new achievement names and v2 progression key.
The corresponding Pages publication is [38993974893](https://github.com/douglastkaiser/stones/actions/runs/38993974893).

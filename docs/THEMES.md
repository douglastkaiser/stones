# Five visual sets

The available sets are Classic Wood, Slate, Marble, Morocco and Kyoto. Exactly
five enum slots remain. Classic retains the base-game-inspired ivory trapezoid,
dark rounded flats, upright walls and rounded capstones on a warm wooden board.
The additional sets use consistent flat/wall silhouettes and distinct capstones,
with ornamental inlays and engravings contained within each playing square.

| Set | Board | Pieces | Capstone |
| --- | --- | --- | --- |
| Classic Wood | Walnut frame, warm grain | Ivory and charcoal wood | Rounded carved dome |
| Slate | Blue-gray stone, angular interwoven bands | Granite/slate with chiseled diamond knot medallions | Faceted peak |
| Marble | Veined marble, gilt cameo and laurel | Polished ivory/blue-black with floral cameo and leaf engraving | Turned rounded crown |
| Morocco | Cedar/brass frame, teal trim, interlaced zellige geometry | Glazed ivory/teal with brass eight-point rosettes and petal inlays | Pointed architectural arch |
| Kyoto | Indigo frame, bamboo grain, seigaiha wave pattern | Cream/indigo lacquer with gold blossom medallions | Tiered crown with gilt roof bands |

Settings presents paired sets with real board/piece previews. All five can be
inspected while locked. Either old board or piece achievement unlocks the full
corresponding set; achievement reward copy names the full set. Selecting Use
updates board and pieces together. Existing integer preference indices remain
stable: old Minimalist/index 3 becomes Morocco and Pixel/index 4 becomes Kyoto.
Already saved mixed board/piece choices still load; selecting a set coordinates
both. No extra sixth theme or loss of previously earned progress is introduced.

## Repairs and rendering contract

- Playing squares previously used gradients while the texture factories were
  unused. The board now paints actual material details beneath pieces, with
  clipping and muted opacity so selection, paths and pieces remain readable.
- Replace duplicated, inconsistent per-style painters with bounded normalized
  geometry. Shadows, strokes and highlights stay inside their supplied bounds;
  capstone highlights are clipped to the silhouette, preventing floating lines.
- Preview layout maintains its aspect ratio on narrow screens; stones retain
  the same flat/wall/cap proportions as gameplay. Real samples have explicit
  width constraints, fixing blank previews caused by zero-width painting.
- All factories and paint invalidation compare visible properties. Theme/color,
  piece type and seat silhouette changes repaint; identical values do not.
- Surface patterns are deterministic, avoiding random flicker on rebuild.
- Gameplay, stack inspection and settings samples share the same factories.
  Hex now shares these materials and silhouettes instead of primitive circles
  and rectangles. Its Copper palette and seat symbols remain independent.
- Cell ornaments stay in the grout. Higher board densities do not add large
  decorations over occupied squares. Patterns use no downloaded images and
  require no asset loading or network connection.
- Morocco uses ceramic placement/stack sounds and Kyoto uses wooden sounds,
  replacing the old retro/minimal audio mapping for those slots.

## Verification and future evaluation

Regression coverage checks all 30 theme/seat/type combinations at small/large
sizes for pixels outside their paint bounds, repaint invalidation, legacy-index
persistence, paired selection, and real locked previews at phone/desktop sizes
with enlarged text. A generated contact sheet under build is a local inspection
artifact, not a committed asset. Hex exercises each have legal solution and
non-winning/draw rejection coverage, plus actual tap/confirm/retry/progress flows.

Measure real-device readability at 8×8 and 61 hex cells, including mixed stacks,
color-vision differences, material contrast under selection overlays and native
screen readers. These designs preserve game silhouettes; themed caps never
change their legal behavior. Morocco and Kyoto are inspired designs, not claims
of historical authenticity. Additional sets should replace a weaker slot rather
than increase the count beyond five.

Verification on 2026-10-09: the full suite passed 266 tests. Following the final
preview-proportion adjustment, all six focused visual tests passed again;
strict `flutter analyze --fatal-infos` and the release web build passed. Browser
trials completed all four Hex tutorials and all three Hex puzzles, including
retry and saved completion. The final Morocco preview was inspected at
320×568; responsive widget coverage also includes enlarged text, desktop,
mixed stacks, square 8×8 and the 61-cell Hex board. Physical-device and native
screen-reader evaluation remains future work.

Ornament refinement: the four unlockable sets now use layered, theme-specific
metal inlays, medallions and border patterns rather than single placeholder
marks. Classic Wood keeps its simpler base-game character. Eleven focused
visual/gameplay tests, strict analysis and a fresh release web build passed
after this refinement. Ornament is clipped to piece faces and tile bounds;
wall engravings are fitted to their narrower face.

## Multiplayer cosmetics

Each square participant sends an earned selected piece style when creating or
joining a room. Hex records a three-seat `pieceStyles` map: local humans and AI
use the host's selection; each remote human brings their own. Choices are fixed
for that room, including reconnects. Existing rooms without metadata and unknown
future names render Classic pieces. Cosmetic metadata does not change rule
versions or move replay.

Render pieces by their color/seat rather than by the viewer's preference. Buried
stones, captured stacks, placement ghosts, spread previews and stack inspection
retain the owner's set. Hex Copper retains its identifying copper palette while
using its seat's selected engravings and silhouette. Offline Hex and its learning
sandboxes continue to use the locally selected board and pieces. Online matches use the host's room-scoped board theme for every viewer.
Offline matches and learning use the local selection.

Match theme labels open a read-only sample and show the viewer's unlock
requirements. Rendering an opponent's set never writes preferences or grants
achievements. Outgoing choices respect either legacy paired-set reward. As with
existing achievements, unlocks are client-local; backend shape validation is
not a server-authoritative entitlement ledger.

Checked-in Firestore rules accept known styles, preserve opponent styles during
Hex joins, and freeze cosmetics during moves. The merged policy was published
on 2026-10-09 after Rules Playground checks; see
[Firebase preparation](FIREBASE_PLAYTEST.md). Code changes alone do not deploy
rules.

The multiplayer iteration passed all 272 Flutter tests and a final 60-test
focused run covering phone/desktop layouts, Hex controls, wire compatibility,
read-only unlock previews and rendering another player's locked set. Three
backend authorization regressions were added under `tools/hex_rules/`; their
JavaScript syntax was checked, but the Firestore emulator suite was not run in
this iteration because Java/the emulator runtime is unavailable on this host.
Production two-device play remains unverified. The main deployment workflow
publishes GitHub Pages only; it does not deploy Firestore rules.
Final strict analysis reported no issues, and the release web build succeeded.
The rebuilt browser was checked with a local Hex match: tapping a seat opened
the correct read-only set preview on desktop and at 320×568. Remote mixed-style
rendering was verified in widget tests rather than through live Firebase.

Host-board refinement: square and Hex rooms now publish an earned selected
`boardTheme` at creation. Every participant renders this same board even if
locked locally; offline games use local preferences. Joins, reconnects, moves
and rematches preserve the recorded board. Missing/unknown names default to
Classic. Backend rules validate board names and prevent guests changing them.
Square creation/join authorization now supports the creator's chosen color.
The final host-board run passed 64 focused model, rendering and responsive tests.
Strict analysis and the final release web build also passed.
See FIREBASE_PLAYTEST.md for backend setup and the remaining live verification.

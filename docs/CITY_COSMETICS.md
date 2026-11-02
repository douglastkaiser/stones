# Six city boards and pieces

The approved cosmetics redesign covers Porto, Edinburgh, Florence, Marrakesh,
Kyoto and Jaipur. These are city-inspired designs rather than claims of historical
game equipment. Rules, seat IDs, move records and achievement requirements remain
unchanged. This is a source implementation; production publication is separate.

## Visual contract

| City | Material / engraving / capstone | Palettes in stable seat order |
| --- | --- | --- |
| Porto | Carved oak, cooperage bands, maritime compass; carved dome | Oak, Charred Oak, Port Wine, Atlantic Blue |
| Edinburgh | Hewn stone panels, recessed interlace and stone joints; faceted tower | Limestone, Basalt, Heather, Moss |
| Florence | Duomo marble lozenges, green/rose inlay and Florentine lily; column capital | Carrara, Serpentine, Terracotta, Lapis |
| Marrakesh | Glazed ceramic, zellige rosettes, cedar and brass grout; pointed arch | Sand, Majorelle, Ochre, Palm |
| Kyoto | Indigo wave fans, bamboo, wooden lattice and plum blossom; tiered crown | Rice Paper, Indigo, Vermilion, Matcha |
| Jaipur | Observatory stone, star charts and brass instrument ticks; stepped astronomical finial | Moonstone, Midnight, Pink Sandstone, Turquoise |

Flats retain the trapezoid and rounded families and add diamond and hexagonal
outlines for players three and four. Following user review, walls and capstones
have **no flat-shaped cosmetic bases**: a lone piece must not resemble a stack.
Real supporting stones remain visible underneath stacked uprights. City palettes
identify wall and capstone owners. Upright silhouettes identify type;
architectural capstones also distinguish cities.
This explicitly supersedes the original proposal to carry flat ownership outlines
into upright bases.

Walls use tall slabs with parallel vertical edges, a light top face and a darker
side face. Their shared layout aspect is 1.08 versus .55 for flats. The geometry
makes the distinction visible in 24px cells without relying on fine engraving,
added glyphs or color. The capstones retain the six distinct architectural profiles.

The detail ceiling is restrained craftsmanship: matte wood/stone, diffuse marble
polish, gentle ceramic glaze, satin lacquer and fine astronomical metal detail.
Finishes are static and clipped to the piece face. Engraving softens as pieces
shrink and drops away below 18 logical pixels. Narrow light rims, darker contours
and contact shadows support mixed board/piece contrast. Existing pattern density
remains the ceiling; no animated shine or additional ornament is introduced.

Edinburgh's coursed, carved panels, Florence's green-and-cream lozenges and Kyoto's
wave fans give each board a recognizable surface. Actual grid bands, joints and
inlays follow the cell polygons on Square and Hex. Continuous outer material rims
fit within existing board padding. Small details simplify on dense boards; pieces,
selection, legal targets and winning roads remain above the material decoration.
Board geometry, hit targets and control layout do not depend on cosmetic choice.

## Original-request audit

| Requirement | Implementation / regression evidence |
| --- | --- |
| Walls read clearly as walls | Upright slab silhouette, top/side contrast and shared proportions; `wall_readability_test`, stack and gesture regressions |
| Florence and Jaipur differ from Porto | Column capital and astronomical finial profiles plus distinct material/motifs; six-city piece and board contact sheets |
| Four distinct flat families | Central `PieceIdentity`; color-independent silhouette tests, four-player dense-board captures |
| City naming and themed palette names | Stable metadata identifiers with six city display names and all 24 palette names; explicit mappings and persistence tests |
| Theme-appropriate front symbols | Compass, interlace, lily, rosette, plum/waves and astronomical engraving in the shared painter |
| Branded grid including Hex | Shared polygon-based grid and frame painters; all 36 mixed board/piece combinations on both geometries |
| Complete live previews | Candidate board with selected pieces or candidate pieces with selected board; four players × three types and Square/Hex examples |
| One selection action per category | Independent Board/Pieces tabs; Preview plus Use board, Use pieces, Selected or disabled Locked; persistence and 200% text tests |
| Exact unlock requirements | Ownership state, “Available to everyone,” both achievement routes with explicit either/OR wording; locked preview tests |
| Temporary Jaipur access | Owner-specific fail-closed checks for board/pieces, AI host ownership, open play/review/export refresh; eligibility and emulator tests |
| Remove floating owner initials | Piece owner badges and staged-count owner suffixes removed; heights, carry/staged counts and target feedback retained |
| Consistent identity throughout play | Shared stack, carry, ghost, reserve, inspection, learning, review and export painters; themed labels including legacy Square chrome; human names preserved |
| Compatibility and feature contracts | Original enum slots and room cosmetics preserved, additive celestial piece ID and tolerant readers; ACCOUNT-08/09/12, PREF-03/04/05, PLAY-02/03/10 updated |
| Subtle finish and usable dense boards | Simplified details, stable bounds, 8×8 Square and radius-4 Hex phone/desktop captures in light/dark; stack/spread/crushing regressions |

Settings previews never grant ownership or equip locked cosmetics. Opponent
inspection uses the same read-only preview content with the board in use and
never changes preferences. Palette labels resolve from each owner's piece style,
independently of the board. Engine labels remain stable internally and are
translated at presentation. Cell and stack accessibility descriptions retain
ownership after visual initials are removed.

## Persistence, eligibility and release order

Original board and piece enum identifiers and indices remain unchanged.
`PieceStyle.celestial` is appended at index 5 and displayed as Jaipur. Explicit
pairing replaces index arithmetic. Either historical board or piece achievement
grants both parts of its city. Unknown cosmetic values fall back to Porto without
invalidating otherwise valid rooms; missing cosmetic metadata is also tolerated.

New completed history records optionally snapshot board, per-seat styles and
owner IDs; local snapshots use the account supplying cosmetics at completion,
independently of the account recorded for ratings when play began. Review resolves
Jaipur eligibility live against those owners. Older
history without appearance metadata uses the current local selection. Replay and
move records are unchanged; repeated result writes preserve the first snapshot.

Jaipur board and pieces require the current #1 established human in Overall,
using the existing server-read eligibility stream. Guest, missing, loading,
failed or revoked eligibility cannot grant it. The board follows its host;
pieces follow each owning account, with host-controlled AI following the host.
Revocation changes rendering and labels without rewriting room metadata. Open
result exports use the same effective styles and discard obsolete PNG captures.
Cosmetic entitlement remains client-enforced, not a server award ledger.

Before clients write `celestial` piece metadata:

1. Release the tolerant cosmetic readers to supported clients.
2. Publish and verify the additive Firestore whitelist change.
3. Release Jaipur selection/writes.

Older unupdated shared-room clients use strict enum parsing and cannot display
the new pieces. This source change contains both tolerant readers and the new
writer; the reader-only rollout must precede publishing the writer-capable client.
Do not claim universal old-client compatibility. Committing or pushing `main`
does not deploy the client or rules; publication workflows require separate
manual release actions. No production deployment is performed by this task.

## Verification

Final qualification uses Linux, Flutter 3.47.7 and Dart 3.13.5. Logs, contact sheets,
small-piece comparisons, 48 light/dark full gameplay captures, preview captures and
a source-hashed manifest are retained locally in `build/qa/cities/`. Generated
artifacts are review evidence, not shipped assets.

- All 2,058 Flutter tests passed with `flutter test --no-pub --concurrency=4`,
  including city rendering, bounded/repainting pieces, silhouette separation,
  shared and legacy interactions, learning, mixed stacks, crushing, history,
  online cosmetics, revocation, exports and responsive layouts.
- A final narrow legacy setup-dialog wrap and live shape-swatch refinement passed
  33 focused checks after that full run. These include all six city choices on a
  320px phone at 200% text, mixed online ownership, inspectors, carry/drop/confirm
  and learning interactions. The full suite was not repeated for this small
  layout refinement; source hashes distinguish the full and focused runs.
- All 159 Firestore emulator checks passed against the checked-in rules, including
  Jaipur creation/join and immutable room cosmetics. No production rules changed.
- Release Chromium checks passed at 390×844 and 1366×900 with zero page errors:
  locked requirements, complete previews, category navigation, Jaipur's temporary
  requirement and unchanged preferences. Desktop preview activation also passed
  using the keyboard. Production backend traffic was blocked. These checks
  preceded the final legacy setup-dialog refinement; its separate widget journey
  is covered above. Earned selection and eligibility use Flutter regressions.
- Strict analysis reports no issues, and the final release JavaScript web build
  passed. Logs: `final/analyze.log` and `final/build.log`. The build bundles renderer resources;
  the pre-existing optional Cupertino font notice does not block the web build.

The final manifest records build results and source hashes. `final/` retains the
full-suite, focused, Firestore, analyzer, build and browser logs. All 72 mixed-set
board samples, 48 light/dark phone/desktop gameplay captures and small-piece
comparisons were reviewed for clipping, wall readability, city differentiation
and grid clarity. Automated silhouette tests are engineering evidence rather than
uncoached human recognition trials.

```sh
WEB_ROOT=build/city-web node tools/serve_web.mjs
# Separate terminal:
python tools/city_cosmetics_browser_probe.py
```

Physical Android/iPhone interaction, VoiceOver/TalkBack and uncoached human
readability trials remain unqualified. Automated viewports and rendered captures
do not establish those usability claims. They must be recorded separately before
release acceptance; production publication retains the compatibility sequence
above.

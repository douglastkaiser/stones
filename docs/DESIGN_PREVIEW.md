# Stones design review

The preview is isolated from real accounts, preferences, rooms and achievements:
[Open the prototype](https://www.douglastkaiser.com/stones/pr/finishing/?review=d3b129a).
Its startup page does not load the production Analytics bootstrap. UI typography
is bundled with its open-source licenses, with no runtime font requests.

## What to review

1. Home: the visual identity, Square/Hex hierarchy, Join/My games visibility and
   the newcomer entry. The account, collection, learning and invitation actions
   show labeled sample content; they are not new production services yet.
2. Setup: add/remove the third/fourth seat, try the shared seat-control dropdowns
   and expand the table settings. Try the table opens a composed sample position,
   regardless of the proposed online/AI choices. All seats are manually controlled
   in this preview so no backend or competing AI runner is involved.
3. Table: use the actual shared board/stack renderer and MoveSelection/MatchRules.
   Tap twice to place, select a stack, preview a legal move and confirm it, or hold
   a stack to inspect. The visual study includes an eight-stone mixed stack.
4. Result: Preview a finished game shows a composed, rule-resolved winning road,
   review and rematch presentation. This is not a published online rematch protocol.
5. Switch light/dark; inspect a narrow phone and a large desktop. Keep the board
   legible and stationary while controls change.

Direct examples:

- [Four-player Hex table](https://www.douglastkaiser.com/stones/pr/finishing/?page=table&shape=hex&players=4&review=d3b129a).
- [Square result](https://www.douglastkaiser.com/stones/pr/finishing/?page=result&review=d3b129a).
- [Light Square setup](https://www.douglastkaiser.com/stones/pr/finishing/?page=setup&light=1&review=d3b129a).

## Design and implementation boundary

The second candidate replaces hospitality slogans and the green/brass landing
page with a direct game menu, ink/paper surfaces, a copper accent and warm timber.
Play and Learn lead; the real board switches between a resolved road and a stack
example with short explanations. This responds to owner feedback that the first
candidate felt corporate and heavy-handed. Restrained serif headings remain. UI controls use a bundled sans serif. The background is a
static painter: no large scene images, animation loop or blur filter. Existing
Classic Wood pieces/board retain their current legal silhouettes and stack system.

The prototype uses `lib/design_preview.dart` as a separate entry point and shared
candidate widgets/tokens in `lib/theme/tavern_theme.dart`. The production entry
point is unchanged. After owner feedback, packet 3 applies approved presentation
to the real shared setup/navigation; packet 10 extends it across all five sets.
Do not promote this sample-content shell as the production game.

## Evidence

The focused suite covers 320/390/1440 widths, light/dark, all four screens, large
text, real supply/road fixtures, Hex navigation and a stable mobile board while
stack selection changes. It generated 24 PNGs; the local review folder is
`build/qa/finishing-reviewed/`, also preserved in the workflow artifact.
The complete suite passed 807 tests on the first qualified candidate. Final
packaging at `d3b129a` also passed all 807 tests, strict analysis, normal web and
Android debug builds, and the focused preview pipeline. Full evidence is tracked
in [release readiness](RELEASE_READINESS.md).

Live browser checks exercised home → Hex → fourth seat → table → pickup five
stones → preview a legal neighbor move → confirm → Charcoal to play. Four-player
Hex was also visually inspected at 390×900. This is browser layout/interaction
evidence, not physical Android install, mobile frame timing or screen-reader QA.
Keyboard Return activation of the Square home button was checked in the first
qualified candidate. The revised candidate requires fresh layout and interaction
qualification before the next owner review.

Local preview command with Flutter 3.47.7:

```sh
flutter run -d chrome --target lib/design_preview.dart
```

The plan explicitly says to obtain visual feedback before spreading the design.
That review is pending; the broader finishing plan remains active work.

## Revision in progress

The 2026-10-17 feedback revision removes fireside, hospitality and sentimental
result copy throughout the preview. It keeps Square/Hex, Join/My games and a
visible learning entry, and adds a switchable road/stack example using BoardView
and rule-resolved fixtures. No game mechanics or production entry points change.
Previous evidence above applies to the first candidate until fresh CI completes.

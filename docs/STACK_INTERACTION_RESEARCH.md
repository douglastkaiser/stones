# Stack interaction research and proposed direction

2026-10-19 research and original design proposal. The subsequent shared-play
implementation is documented in [Stack inspection and movement](STACK_INTERACTION.md).
Reviewed the current shared play path at `911af8f`, its stack renderer, gesture
recognizer, move planner, and existing movement/stack audits. External examples
below were checked through product documentation and a developer interview;
they were not subjected to hands-on usability testing in this review.

The original proposal below is historical research, not the current control
specification. The 2026-10-23 revision deliberately restores source-tap pickup
cycling alongside direct selection, adds current-drop minus/plus, and restores
on-board hold expansion. Use the linked implementation contract for current
behavior and verification; preserve the original observations as dated evidence.

## Diagnosis in the application at `911af8f`

The player needs to connect four facts: the contents of the stack, which top
stones they are taking, which bottom stone drops next, and the resulting control
of each cell. The interface currently separates those facts across several views.

| Current behavior | Likely usability cost |
| --- | --- |
| `StackLayerLayout` shows at most three layers, or five after a 240 ms hover. Both layouts fit inside the original cell. | Expansion is subtle and still omits deeper contents; it cannot act as a full stack view. |
| `StackInspection` opens a modal sheet occupying 65% of screen height on hold/right-click. | Routine inspection interrupts board interaction. Touch has no visible inspection button. |
| The inspector lists a snapshot top first; Carry/Drop controls show numbers. | Players must remember piece order and mentally translate numbers into ownership changes. |
| On selecting a stack, the shared planner defaults to the maximum allowed carry; tapping the source cycles that count. | A repeated selection tap can change the intended move without an obvious physical explanation. |
| Drag displacement is accumulated, but the game receives only a direction when the pointer is released. | A slow drag gives no continuously moving carried stack or target feedback. |
| A first spread preview places the entire carry on the destination while `pendingDrop` starts at one. Confirm submits the entire planned move; the pending number matters only when continuing. | “Drop 1”, the displayed board, and Confirm describe different things. |
| “All here” changes the pending number but not the planned board; changing Carry clears the route. | Controls have effects that are difficult to predict from their labels. |

These are code observations and design inferences, not measured novice failure
rates. The existing atomic confirmation, shared legality, cancellation, owner
themes, and viewport-based board sizing are useful foundations.

Relevant implementation: `lib/widgets/piece_stack_view.dart`,
`lib/widgets/board_cell_gestures.dart`, `lib/game/board_view.dart`,
`lib/game/move_selection.dart`, `lib/game/match_screen.dart` and
`lib/game/match_table_layout.dart`. Older audit descriptions sometimes refer to
legacy controls; the shared implementation is the basis for the observations here.

## Documented examples worth borrowing from

| Reference | Documented behavior | Application to Stones |
| --- | --- | --- |
| [WinTak / STak user guide](https://github.com/crasshacker/STak/blob/master/docs/UserGuide.md#basic-game-mechanics) | Pointing at a stone highlights it and the stones above it. Clicking takes that portion; subsequent destination clicks drop individual stones. Legal placement has highlight and snap feedback. | Make the pickup boundary tangible; show the exact stones involved before acting. Adapt the targets for touch. |
| [StackWorks stack inspector](https://stackworks.games/help#stack-inspector) | Clicking a stack shows its composition in the right panel, with owner colors and a marked top. | Keep inspection available alongside the board. This is a close structural analogy because buried pieces and top ownership matter in Lasca too. |
| [Tabletop Simulator advanced controls](https://kb.tabletopsimulator.com/player-guides/advanced-controls/#alt-drop-rmb) | Provides an action to drop the last grabbed object or bottom card of a held deck. | A visible carried collection and an explicit next-drop action are useful. Its modifier combinations are not evidence of beginner discoverability. |
| [PlayTak controls](https://playtak.com/) | Click/tap picks up a stack; desktop right-click-and-hold hides other squares to reveal it. | A direct Tak comparator. Its inspection shortcut demonstrates a solution to occlusion, but does not establish that hold is an effective primary touch interaction. |
| [Into the Breach, interview with Justin Ma](https://www.gamedeveloper.com/game-platforms/road-to-the-igf-subset-games-i-into-the-breach-i-) | Ma describes telegraphed attacks and clear cause and effect as central to making tactical outcomes understandable. | Show the exact consequence of the current draft, including the exposed owner after each drop. This is an inference for Stones, not a claim that the game uses Tak-like stacks. |

## Principles translated into decisions

**Make state visible.** Players should be able to point to what is selected,
what remains carried, and what the next action will do. The feedback principle
is described by [Nielsen Norman Group](https://www.nngroup.com/articles/visibility-system-status/).
For Stones, counts need the actual piece sequence beside them, and every control
must agree with the board preview.

**Make essential actions discoverable.** Inspection and choosing a carry need
visible routes. Hover, hold and right-click may accelerate those routes. They
should not be prerequisites for learning the game. This applies
[recognition rather than recall](https://www.nngroup.com/articles/recognition-and-recall/)
to gestures and buried pieces.

**Maintain continuity.** Preserve each stone's owner, type, order and top/bottom
orientation through inspection, selection and dropping. A brief lift or settle
animation should explain the transition. Reduced motion must retain equally
clear static states. Animation timing is a prototype variable, not a proven fix.

**Make exploration reversible.** Inspection and drafting should be safe. Keep
Undo last drop and Cancel visible, and distinguish the local draft from the
confirmed turn. Never resolve roads or publish partial drops.

**Offer equivalent tap controls.** Sustained dragging is a useful shortcut, but
the complete move should work with discrete taps and visible buttons. This also
follows [W3C's guidance on alternatives to dragging](https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html).

## Proposed primary interaction

### 1. Read and select

Keep a compact stack on the board with a clear top owner/type, total count and
visible lower edges. Do not imply that the three decorative layers are the whole
stack. Select a stack with one tap to show its contents in a persistent tray
below the board on phones, or in the side panel on desktop. An opponent's stack
opens the same view in read-only form.

Use the existing fixed board geometry and reserve space for this tray. Routine
inspection should neither cover the move path nor resize/recenter the board.
A clearly labeled Expand action can reveal the full scrollable contents of very
tall stacks. Small-screen layout and large text need prototype qualification;
there is no assumption that every layer fits at once.

### 2. Choose a physical portion

Show the stack with its top at the top. A selection bracket identifies the top N
stones to take; the lower stones are explicitly labeled “Stays here”. Clicking a
layer boundary selects that layer and everything above, subject to the carry
limit. Large minus/plus or count buttons provide a precise touch alternative.

Retain the current maximum-allowed default for the first comparison prototype,
but make it visible as “Take 4 of 7”. Defaulting to one is a separate question
to evaluate. Repeated taps on the board stack should not silently cycle the count.
An owned stack's tray offers movement immediately; a separate modal confirmation
for selecting the carry is unnecessary.

### 3. Carry visibly and drop deliberately

The selected stones remain visible as a carried stack in the tray. Its lowest
stone is marked “Next to drop”. The board distinguishes carried stones from
stones already staged on a cell; carried stones must not appear settled there.

- Tap a legal neighboring cell: stage one bottom stone there, then reduce the
  visible carried stack by one.
- Tap the current destination again: stage one more there.
- Tap the highlighted next cell: continue straight and stage one there.
- “Drop remaining here” explicitly stages all remaining stones at the current
  destination. Its label and preview must describe the same result.
- Undo last drop restores the previous carried stack and route. Cancel discards
  the complete draft. Off-path taps preserve the draft and explain the constraint.

Annotate each visited cell with its staged count and resulting top owner. Show
the next legal cell and a quiet route line. Wall/cap/edge explanations should
come from shared rules results. At the first drop, establish the movement axis;
subsequent highlights reinforce that direction. Hex uses the same model with six
possible initial directions.

During a draft, inspection remains available through a visible Inspect action
without replacing the selected source or altering the carried stones. This keeps
destination taps unambiguous while still allowing examination of other stacks.

### 4. Finish with an exact preview

Once the hand is empty, enable “Confirm move”. The board already depicts exactly
what will be committed. Keep Cancel and Undo available until submission. For the
first prototype, use explicit confirmation consistently for stack moves rather
than silently submitting a final tap. Any expert auto-confirm preference can be
evaluated separately.

Example: take three stones whose bottom-to-top order is charcoal, ivory, ivory.
A tap on the first cell stages charcoal and leaves two ivory stones carried.
A tap on the next cell stages ivory; “Drop remaining here” adds the final ivory
there. The board now shows the actual 1 → 2 distribution, ready for confirmation.

### 5. Add drag as an alternate input to the same draft

Dragging should show immediate pickup feedback, a ghost offset from the finger,
and the currently targeted legal cell while the pointer moves. A one-cell drag
and release can stage the same single bottom-stone drop as a tap; the remaining
stones stay visibly carried for the next action. Release does not submit a turn.

Evaluate continuous multi-cell spreading after the tap flow works. Avoid
time-based auto-drops or requiring a held pointer plus another hidden gesture to
choose a quantity. This is a proposed interaction to test, not a claim that it
will outperform every existing expert input method.

## Implementation implications

The current `MoveSelection` stores a complete legal move whose final cell absorbs
the remainder. The proposed design makes an incomplete drop sequence visible.
That requires an explicit draft representation: source, selected top portion,
direction, staged drops, remaining hand and revision history. A hidden “all here”
completion must not be mistaken for a staged board result.

Keep legality and completion feasibility in the shared rule layer. Do not create
new UI-only wall/cap rules or enumerate exponentially many complete distributions
on every pointer update. Only submit a fully validated move through the existing
controller. Preserve clock, remote turn, study and permission guards; invalidate
or refresh an inspector/draft when its underlying position changes.

## First prototype and evaluation

Prototype the visible stack tray, tangible pickup boundary, next-drop indicator,
and exact staged board together. This tests a coherent interaction rather than
isolated animation polish. Compare against the current interaction on the same
positions, with task order varied to reduce learning effects.

Ask several players new to this interface to inspect a mixed stack, take a top
portion, make a 2 → 1 spread, revise a drop, cancel, and finish a lone-cap wall
crush. Include a stack taller than the carry limit, an opponent stack, and both
Square and Hex. Use real touch hardware as well as a mouse.

Observe time to first successful spread, requests for help, unintended count
changes, wrong predictions of the next dropped owner, unwanted submissions, and
successful recovery. Before each action, ask what the player expects to happen.
The design is promising if players can predict those outcomes without coaching;
automated gesture success alone cannot establish that.

Implementation verification should cover draft/commit separation, bottom-first
order, carry limits, walls/caps, undo/cancel, interruption by remote state, all
directions, keyboard/tap equivalence, reduced motion, large text, and stationary
board bounds. The initial research pass made no production changes; the implementation and
verification are recorded in the linked interaction contract.

# Planning handoff: fundamental AI strength

Plan the next fundamental improvement to Stones' shared v3 AI. Read
`AGENTS.md`, `docs/AI_BALANCE_INVESTIGATION.md`, its evidence/replay, and
`docs/AI_UPGRADES.md` first.

Investigate replacing selective duel beams and the weak timeout baseline with
completed full-width iterative-deepening minimax, using sound alpha-beta pruning,
move ordering, caching and bounded tactical extensions. Benchmark feasibility
under the existing thinking budgets. Then propose the smallest general
connectivity improvement that recognizes independent winning continuations,
bottlenecks and vulnerable routes beyond shortest-road distance.

Use the recorded quiet defensive flat as a counterexample, not an opening script.
Avoid capstone timing rules, Hex-specific heuristics, increased budgets or relaxed
CI gates. Preserve saved v1/v2 behavior and multiplayer compatibility. Validate
search and evaluation changes separately against a frozen reference, using
held-out openings, swapped seats, adjacent tiers and runtime measurements.
Distinguish AI weaknesses from intrinsic starting advantage; defer rules changes
until stronger equal-strength play supplies evidence. Keep randomness experimental
until difficulty ordering and same-tier no-regression checks pass.

Produce a staged implementation plan with tradeoffs, measurable acceptance gates,
and explicit unresolved risks; do not implement during planning.

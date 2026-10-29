# Hard/Expert strategic-search overhead repair — 2026-10-29

Applies to LEARN-01 and PLAN-10; COMPAT-06 remains the adjacent saved-engine
contract. The October 28 main CI completed its Hex Expert/Hard games at 5–5,
with the starting seat winning all ten games. This is a failed ordering check,
not proof that the two difficulties or the starting positions are equivalent.

The strategic search was rebuilding and validating every immutable stack for
every child position, and checking immediate wins by applying and adjudicating
every candidate move. The exact safety search already used stack sharing and
component-based winning-move detection. Hard/Expert v3 duels now reuse those
same implementations during strategic search as well. This gives refinement
more of its existing time allowance without changing its evaluator, beam/depth
targets, forced-loss veto, game rules or thinking limits.

This change is restricted to the existing Hard/Expert v3 duel path. Easy,
Medium, multiplayer, saved v1/v2 engines and opt-in full-width experiments retain
their existing paths. No opening seeds, difficulty handicaps, CI thresholds or
deployment qualification requirements change. Timed search may complete a
different iteration and therefore choose a different move; the optimization is
not a promise of universal strength or hardware-independent move selection.

## Complete depth before extra width

The first overhead-only candidate (`df977a5`) passed Hex Expert/Hard locally
7–3 and in branch CI 6–4, but failed Square Expert/Hard at 4–5 with one draw.
It was not published. Those results do not qualify the revised source.

Expert's previous duel schedule was 12 roots/two plies, 12/four, 16/four,
16/six. The wider four-ply iteration could consume the deadline before Expert
completed any deeper result than Hard. Expert now completes 12/six before
attempting 16/six. Hard retains its 12-root, four-ply target. The same 2.2-second
strategic allocation and five-second total Expert target remain; neither width
nor depth targets increase. Saved engines and multiplayer retain their prior
iteration schedule. Worker diagnostics record completed depth/width iterations,
and a completed-search regression checks the actual Expert progression.

Correctness checks are the canonical-transition and immutability comparisons in
`test/game/ai_duel_position_test.dart`, exhaustive winning-move membership/order
comparisons in `test/game/ai_connections_test.dart`, and the existing tactical,
cancellation, draw-defense, full-round and saved-engine regressions. Release
qualification still requires strict analysis, the complete Flutter suite,
all six representative adjacent-tier groups, browser/account checks, rules
qualification and two consecutive successful main CI attempts. Native pilot
results alone do not establish those checks or publication. Hosted source,
artifact integrity and login checks follow publication.

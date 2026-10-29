# AI strength qualification follow-up — 2026-10-29

Applies to LEARN-01, PLAN-10 and APP-09. The owner requested removal of the slow
AI tournament checks from routine CI and release gating, with strength work to
be revisited as a broader investigation.

## Current workflow contract

Push/PR CI no longer launches the six native adjacent-tier tournament jobs.
Deploy Main no longer requires those jobs. Analysis, the complete Flutter suite
(including AI correctness/tactics tests), web/Android/emulator builds, rules,
player journeys and three-engine account/recovery checks remain required.
The selected source still needs two consecutive successful CI attempts. Exact
artifact verification, rollback capture and hosted verification are unchanged.

The same six tournament profiles remain available as the manual-only
[AI Ordering workflow](../.github/workflows/ai-ordering.yml). Its seeds,
thresholds, engines and retained replay/provenance artifacts are unchanged.
It has no push, pull-request, scheduled or automatic workflow-run trigger, and
does not block deployment. To explicitly run it later:

```sh
gh workflow run ai-ordering.yml --ref main
```

The larger [Full AI Strength workflow](../.github/workflows/ai-strength-full.yml)
and local/reference investigation tools also remain available on demand.

## Why the release policy changed

Application commit `54b6f155336b790e8fea5594ddbc395432da3e04` changed quick-start
setup and completed-save detection without changing the AI engine. In
[CI run 40958489583](https://github.com/douglastkaiser/stones/actions/runs/40958489583),
all 16 other jobs passed in each of two full attempts, including all 1,953
Flutter tests, builds, player journeys and three-engine account/recovery checks.
Firestore Rules passed separately.

Square-5 Expert/Hard took approximately 22 and 24 minutes, then failed at 4–6
and 5–5. All games finished; the second replay has no emergency fallback moves.
The executable SHA-256 in both failures is
`654afa0bf8a8bfd61ab6f99dcdfa5bce220ea5eb02a098880e6023467a3aadd2`, identical
to the deployed `0f5eb7d` release's two earlier 7–3 successful qualifications.
The engine and tournament-runner source hashes also match. Time-limited search
can complete different iterations on different runs despite fixed opening
seeds and deterministic final-choice policy.

Moving the tournaments to manual execution does not resolve strength ordering
or establish that Expert reliably outplays Hard. The failed outcomes remain
evidence; the engine, difficulty labels, budgets and rating identities are not
retuned in this workflow change.

## Broader investigation to return to

- Separate repeatability and machine/load sensitivity from actual playing strength.
  Record completed depth, timeouts, startup conditions and compute use.
- Use held-out opening clusters, swapped seats, unchanged references and sufficient
  completed games. Report draws and opening/seat sweeps with uncertainty.
- Establish a useful runtime and evidence policy before choosing whether any
  strength study belongs in automatic CI again. Keep correctness and tactical
  regressions distinct from population strength estimates.

Source and runtime qualification for ordinary releases remain recorded in CI
and Deploy Main. This policy change itself does not claim a production rollout
or a physical-device/human-strength qualification.

Local Linux validation passes all 79 release-tool tests. Five tests execute the
actual Deploy Main qualification script against GitHub API fixtures: a complete
non-tournament run selects its exact artifact, while missing/failed browser jobs,
failed CI/rules, a failed previous attempt and mismatched source cannot qualify.
All workflow YAML parses successfully, and the manual tournament job compares
equal to its former automatic definition, with only `workflow_dispatch` enabled.

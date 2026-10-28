These records concern the repair following the failed first duel experiments.
`validation-protocol.json` registers fresh confirmation streams before their use.
Development seeds are for selecting/rejecting components and do not qualify them.

The original counterexample and independent proof remain in
`../ai-balance-investigation.json` and `../ai-balance-hex-counterexample.jsonl`.
The older `../ai-duel-verification.json` and `../ai-benefit-audit.json` describe
superseded implementations, not the revised component algorithm or search schedule.

Native AOT executables and raw pilot replays are stored in the ignored
`build/qa/ai-fix/` directory. Each binary has a checked SHA-256 sidecar; R is the
unchanged frozen engine, RT changes only its thinking allowance, F is the current strategic baseline with the safety guard disabled (earlier F
builds isolated exact win detection), S adds full-width search, E adds connectivity evaluation and SE
combines them. G enables the targeted forced-loss veto. Builds and Flutter tests do not run alongside native timed trials.

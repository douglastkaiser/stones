# City cosmetics publication — November 2, 2026

**Published and hosted-verified.** [Stones](https://www.douglastkaiser.com/stones/)
serves six city boards and piece sets from application source
`95439d23502e0e247ccf3e194dc12b928759d14e`. Walls have distinct upright slab
silhouettes; city palettes, independent selections and complete previews are live.
The owner authorized web/backend publication and deferred the full Android release.

## Web publication and qualification

Both [complete CI attempts](https://github.com/douglastkaiser/stones/actions/runs/41520052627)
passed all **12 jobs each**. Each passed **2,061 Flutter tests**, **83 release-tool
tests**, strict analysis, web/emulator/debug Android builds, player journeys,
and independent Chromium/Firefox/WebKit account and production-auth recovery
checks. All **159** [Firestore authorization checks](https://github.com/douglastkaiser/stones/actions/runs/41520052631)
also passed for this source.

[Deploy Main](https://github.com/douglastkaiser/stones/actions/runs/41527422590)
published the exact second-attempt artifact:
`web-build-95439d23502e0e247ccf3e194dc12b928759d14e-2`.
Publishing commit `77744b2643f05975f50f097c63265759a7360861` reached `gh-pages`
at 2026-11-02T21:20:56Z. All three hosted source/integrity/Google-handoff jobs
passed. A fresh public-site read on November 3 still verifies the selected source,
asset integrity and two retained startup pairs.

Separate public-site Chromium checks passed at 390×844 and 1366×900 with zero
page errors: Board/Pieces tabs, read-only locked previews, exact unlock conditions,
four players × three piece types, Square/Hex samples, Jaipur's temporary eligibility,
keyboard preview activation and unchanged preferences. Production backend traffic
was blocked in these cosmetic UI checks. Emulator player journeys also passed
learning, saved/reviewed/rematched games, independent clients, reconnects, Court
and AI settlement/recovery. The chat probe passed masked delivery and absence of
history after reconnect; it now selects the unique textbox role, as Flutter exposes
the input hint separately from its accessible name.

[Machine-readable web evidence](../qa/city-cosmetics-web-publication-2026-11-02.json)
records sources, runs, artifacts and qualification limits. Initial CI exposed
stale generic-owner assertions; player, chat, placement and adaptive journeys now
use Porto labels while retaining their ownership/move checks. The final release
record/manual-chat-harness follow-up changes documentation and test selection only;
published runtime bytes remain the twice-qualified application above.

## Compatibility and Android deferral

Older installed Android builds strictly parse piece identifiers. The web release
defaults `STONES_JAIPUR_ONLINE_PIECES` off: new shared/legacy online seats use Porto
when an eligible owner selects Jaipur. Saved preferences, local Jaipur play and
previews remain intact. Setup shows the actual online palettes and explains the
temporary limit. Existing rooms remain immutable. The known Jaipur board identifier
stays available online to its eligible host; other city wire identifiers are unchanged.

Enable Jaipur piece writers only after supported app readers and backend
compatibility are qualified. No signed Android release, Play upload or store
publication was performed. The release guard passed 46 local city/setup/online
checks and 14 checks with the future writer flag explicitly enabled.

## Backend published and verified

Firebase CLI 15.33.0 published only Firestore rules to `stones-9a6a0`, default
database. Initial readback at 2026-11-02T20:28:39.501Z and a fresh November 3
readback exactly match checked-in source SHA-256:
`6d1bbbcb5caf41976d5c1064bb2cadb72a106e98c36c0ad7240627e7f22ddbee`.

The only policy change accepts the appended `celestial` piece identifier.
Published ruleset:
`projects/stones-9a6a0/rulesets/a7dead50-87d9-4de6-95b8-b65fb5cc9905`.
Six READY indexes, both field overrides, database identity and other rule releases
are unchanged. Public Overall/Square AI reads returned 200; unauthenticated room,
rating-receipt and skill-settlement enumeration returned 403. No customer game,
account or rating data was created or changed by publication/verification.
[Backend evidence](../qa/city-cosmetics-firestore-2026-11-02.json) records the checks.

## Rollback and remaining qualification

The previous web source is `66443b2492a1f458c17e56d60b5f8fe400f6ad55`.
Its artifact was archived and verified against its own backend hashes before
publication. The [rollback artifact](https://github.com/douglastkaiser/stones/actions/runs/41527422590/artifacts/13180277707)
is retained for 90 days. Its digest is
`e29465f39b4002799d485179f90d215714faad94ff5335b896e6b10306e303f9`.

Backend rollback ruleset:
`projects/stones-9a6a0/rulesets/c94c6cca-e1d8-40cf-a43a-c17191ec4785`;
SHA-256 `4484497f34b7306346a85d8eaaae6bd95a2e0990e8b5ace2b6baecf78a5c20f4`.
Before/after backups, deployment log and readback remain locally under
`build/qa/cities/release/firebase/`.

Hosted checks verify pre-credential Google handoff. Physical-device interaction,
VoiceOver/TalkBack, real Google credential exchange and uncoached human readability
remain unqualified. Automated viewport/rendering evidence does not establish those
claims. Android publication remains a later owner-directed step.

Updated contracts: ACCOUNT-08/09/12, PREF-03 and APP-09. City design, original
requirements audit and initial validation remain in [CITY_COSMETICS.md](../CITY_COSMETICS.md).

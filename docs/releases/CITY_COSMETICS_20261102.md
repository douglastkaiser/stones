# City cosmetics publication — November 2, 2026

The owner requested complete web/backend publication after source `dd23910`,
with the full Android app release deferred. Physical-device, screen-reader and
real Google credential-exchange qualification remain separate.

## Backend published and verified

Firebase CLI 15.33.0 published only Firestore rules to `stones-9a6a0`, default
database. Readback at 2026-11-02T20:28:39.501Z exactly matches checked-in source:
`6d1bbbcb5caf41976d5c1064bb2cadb72a106e98c36c0ad7240627e7f22ddbee`.

The only policy change accepts the appended `celestial` piece identifier.
Published ruleset:
`projects/stones-9a6a0/rulesets/a7dead50-87d9-4de6-95b8-b65fb5cc9905`.
All 159 authorization emulator checks passed for this exact file. Six READY
indexes, both field overrides, database identity and other rule releases are
unchanged. Public Overall/Square AI reads returned 200; unauthenticated room,
rating-receipt and skill-settlement enumeration returned 403. No customer game,
account or rating data was created or changed by publication/verification.

Rollback ruleset:
`projects/stones-9a6a0/rulesets/c94c6cca-e1d8-40cf-a43a-c17191ec4785`;
SHA-256 `4484497f34b7306346a85d8eaaae6bd95a2e0990e8b5ace2b6baecf78a5c20f4`.
Before/after backups, deployment log and readback are retained under
`build/qa/cities/release/firebase/`.

[Machine-readable backend evidence](../qa/city-cosmetics-firestore-2026-11-02.json).

## Web reader rollout and qualification

Web publication is awaiting two complete successful CI attempts and the qualified
Deploy Main workflow. Initial source CI exposed stale browser assertions expecting
Ivory/Charcoal after the UI changed to Oak/Charred Oak. Player, chat, placement
and adaptive browser journeys now use the corresponding Porto labels without
weakening their ownership or move assertions.

Because older installed Android builds strictly parse piece identifiers, the
web release defaults `STONES_JAIPUR_ONLINE_PIECES` off. New shared/legacy online
seats use Porto when the owner selects Jaipur; saved preferences and local
Jaipur play/previews remain intact. Setup uses matching online labels/swatches
and explains the temporary limit. Existing room cosmetics are never rewritten;
the known Jaipur board identifier stays available online to its eligible owner.
Other city styles use their original wire identifiers unchanged.

Do not enable Jaipur piece writers until supported app readers and backend
compatibility are qualified. The current web-only rollout performs no signed
Android release, Play upload or store publication. Ordinary CI still compiles
Android to detect regressions.

The release guard passed 46 local city/setup/online checks, 14 checks with the
future writer flag explicitly enabled, and strict analysis. Final CI/deployment
and hosted verification links will be recorded when those runs complete.

Updated contracts: ACCOUNT-08/09/12, PREF-03 and APP-09. City design, original
requirements audit and initial validation remain in [CITY_COSMETICS.md](../CITY_COSMETICS.md).

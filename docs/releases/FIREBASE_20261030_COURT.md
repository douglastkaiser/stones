# Court Firestore publication — October 30, 2026

The owner requested publication and completed the official Firebase CLI remote
sign-in. firebase-tools 15.33.0 published **only Firestore security rules** to
**stones-9a6a0**, default database, at **2026-10-30T20:59:09.069668Z**.
Application base is `2da3ff8` with the working-tree Court changes; no website or
Android release was performed.

Published ruleset:
`projects/stones-9a6a0/rulesets/c94c6cca-e1d8-40cf-a43a-c17191ec4785`.
Readback exactly matches the tested source SHA-256:
`4484497f34b7306346a85d8eaaae6bd95a2e0990e8b5ace2b6baecf78a5c20f4`.

The rules support untimed online Court rooms, owner-authorized takeback
requests/votes and unanimous prefix rewinds. They reject stale/unauthorized
changes and exclude Court from rating votes, receipts and skill settlement.
Ordinary and legacy room contracts remain compatible. All **158** real
Firestore emulator authorization tests passed against this exact file immediately
before publication. Google accepted compilation during deployment.

After publication, all six indexes remain READY with their resource identities
and configurations unchanged. Field overrides, database identity and other rule
releases are unchanged. No index deployment was performed; checked-in index
configuration SHA-256 remains
`a1e2148a12658d0475f03f054493f54c9dbf241d1e46004bfd4a83828098aed3`.

Five read-only production checks pass: public Overall and Square AI profile
reads return 200; unauthenticated room enumeration, rating-receipt enumeration
and skill-settlement enumeration return 403. No production game, account or
rating data was created, rewritten or migrated. CLI credentials stay in the
normal external Firebase CLI store and are excluded from source.

Before publication, production exactly matched the reviewed baseline
`6839907f200d69fc0c96138f333827be5a80185c3055e24ebc11cc77788160a5`.
Rollback ruleset:
`projects/stones-9a6a0/rulesets/fcda75d9-216e-428f-89cd-1a58d41105d2`.
Full rules source, release/database/index metadata and field overrides were
backed up under `build/qa/firestore-court-20261030/before/`. Readback snapshots,
deploy/test logs and access checks are in the same task directory.

[Machine-readable publication evidence](../qa/firestore-court-publication-2026-10-30.json)
records hashes, release time and verification outcomes. Feature inventory IDs:
**ONLINE-09** and **ONLINE-10**. The backend prerequisite is complete. The
subsequent [application publication](COURT_20261030.md) records the verified web
release, hosted Court trial and signed Android 527 build. Play submission and
physical Android/iOS qualification remain pending.

# Account rooms and turn notifications — implementation candidate

Baseline: main `2ce177a`, November 3, 2026. Local source changes; no backend,
web or Play publication is established by this document.

My games adds owner-private `/playerGames/{uid}/rooms/{code}` references, ten
per page, alongside existing local history and shortcuts. Create/join transactions
register the acting identity. Account summaries are navigation data; opening a
room validates server-confirmed state and ownership. Existing shortcuts migrate
only for the matching identity. Older unindexed rooms need their invitation/code
or an existing shortcut. Archive and notification mute are independent metadata.

Settings adds account-wide turn alerts and device enable/disable. Alerts default
off. Each device needs its own permission. iPhone web push requires a Home Screen
installation on iOS/iPadOS 16.4+ and sign-in in that installation. Android Force
stop, OS permission and browser background restrictions can prevent delivery.
Local games, completed local history and achievements are not cloud-synchronized.

## Release gate and provisioning

Notifications are deliberately disabled unless compiled with
`STONES_TURN_ALERTS_ENABLED=true`; web also requires `STONES_PUSH_VAPID_KEY`.
Do not enable this gate until the live checks below pass. The current environment
has no configured Cloudflare or Firebase sender credentials. No successful live
send, physical-device display or Workers Free CPU measurement is claimed.

1. Publish and qualify the additive Firestore rules and composite indexes first.
2. Provision a dedicated backend service account with Firestore data access and
   FCM send access; protect its private key as a Cloudflare secret. Never include
   backend credentials in Flutter, JavaScript, source control or logs.
3. Deploy `tools/turn_notifications/worker.mjs` with its Wrangler configuration.
   Set `SERVICE_ACCOUNT_EMAIL`, `SERVICE_ACCOUNT_PRIVATE_KEY`, and the correct
   `FIREBASE_PROJECT_ID`. The `ENABLED` variable defaults to false.
4. Prove OAuth, Firestore querying/conditional writes, a real FCM send and retry
   recovery in Workers Free. Measure cold and warm CPU below the 10 ms limit,
   invocation subrequests below 50 and Spark read/write usage. The sender processes
   one due event and at most five registrations per tick, with a durable cursor.
   Capacity is intentionally bounded; queue age must be checked before release.
5. Configure the Firebase web-push VAPID public key; enable the backend and build
   the client with the two release defines. Use the existing manual publication
   process. Do not substitute paid hosting if the feasibility check fails.

Room updates enqueue immutable jobs in the same transaction when the client gate
is enabled. Recipients come from authoritative room seats, not client-provided
addresses. Jobs are leased through Firestore update-time preconditions, checked
against current ply/Court revision/preferences, and delivered by FCM HTTP v1.
Expired tokens are removed. Per-device receipts and collapse identifiers reduce
repeated display; a send interrupted after FCM acceptance may still duplicate.
The push-only service worker caches no application assets.

## Verification record and open acceptance

Local sender unit tests cover turn ownership, obsolete revisions, AI/completed
states, delivery without a client and competing leases. Flutter source analysis,
focused recovery tests and account-reference tests are recorded in the task
handoff when complete. Unit tests do not validate deployed authorization.

Still required before publication: Firestore emulator authorization trials for
the new collections and compound transactions; full suite and release build;
actual Cloudflare CPU/quota qualification; multi-device token/account switching;
Android and desktop closed-window delivery; installed iPhone delivery; next-day
recovery; revoked permissions, backend outage and quota exhaustion. No deployment
or physical-device qualification is claimed. Native iOS remains unsupported.

Final local checks (Flutter 3.47.7 / Dart 3.13.5, Linux): strict analysis
passed with no issues; all 63 focused account/recovery/lazy-list tests passed
serially; all five sender unit tests passed; release JavaScript/CanvasKit web
build passed with the existing Cupertino font warning, with Wasm dry-run disabled.
An earlier competing-build run exposed a one-second legacy Hex AI wait failure;
the individual rerun and final serial run both passed without changing the AI
or that wait. The final navigation UID guard was added after build compilation
started and is covered by final analysis/tests, not a fresh artifact qualification.
The five new Firestore emulator authorization trials subsequently passed,
including atomic creation/rollback, owner isolation, immutable room references,
transition-bound outbox writes and private device tokens/preferences. The full
local Flutter suite is running during release preparation. Two legacy Hex
recovery tests reproduced their one-second timing sensitivity under concurrent
render/AI load; their wait bounds are now five seconds without altering AI or
assertions. The exact committed source must pass the existing full CI and rules
workflows, including two consecutive CI attempts, before manual Deploy Main.
Sender unit tests now also run in CI. No device delivery is claimed.

# Account rooms and turn notifications

Baseline: main `2ce177a`, November 3, 2026. Account-room discovery is published
on web from source `563b0f3`; notifications remain disabled. See the
[publication record](qa/account-persistence-publication-2026-11-09.json).

## Published account-room release — November 9, 2026

Firestore rules and indexes were published on November 3; both new indexes were
confirmed READY again on November 9. All 164 authorization trials passed locally
and in CI. A production API smoke test verified atomic host/join registration,
private lists, fresh-session discovery, move handoff and archive/restore/mute
using isolated QA identities, subsequently removed after ending the QA room.

CI passed 2,091 Flutter tests and strict analysis on full attempts 1 and 3.
Attempt 1 failed one Chromium missing-callback-storage probe; its unchanged
artifact/probe passed the failed-job rerun (attempt 2), followed by a clean full
attempt 3. Successful attempts 2 and 3 satisfied the existing consecutive-success
gate without modifying it. Sender tests, web/emulator/Android compilation,
player journeys and the three-browser account/recovery matrix passed.

[Deploy Main](https://github.com/douglastkaiser/stones/actions/runs/42570037341)
published the qualified attempt-3 artifact. Pages publication and hosted login
checks passed in Chromium, Firefox and WebKit; an independent live integrity check
confirmed the selected source, asset fingerprints and two retained startup pairs.
Android compilation does not constitute a Play release or physical-device check.

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

## Notification release gate and provisioning

Notifications are deliberately disabled unless compiled with
`STONES_TURN_ALERTS_ENABLED=true`; web also requires `STONES_PUSH_VAPID_KEY`.
Do not enable this gate until the live checks below pass. A Cloudflare sender
and its dedicated Firebase service-account credentials are not configured.
No successful live push send, physical-device display or Workers Free CPU
measurement is claimed.

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

Remaining notification acceptance: actual Cloudflare CPU/quota qualification;
sender authentication and live FCM delivery; multi-device token/account switching;
Android and desktop closed-window delivery; installed iPhone delivery; revoked
permissions, backend outages and quota exhaustion. Legacy same-code rematch event
generation and service-worker cold-start/revocation still need qualification
before enabling alerts. Physical Android/iPhone handoff and a day-long friend
match remain unqualified. Native iOS remains unsupported.

Local source checks initially passed 63 focused account/recovery/lazy-list tests,
five sender tests, strict analysis and a release-web build. A resource-constrained
local full-suite run was interrupted. Two legacy Hex recovery tests exposed
one-second timing sensitivity under concurrent render/AI load; the committed
five-second bounds preserve their assertions and AI behavior. Exact-source CI,
backend and hosted verification above supersede the initial candidate-only
artifact qualification. No real push delivery is claimed.

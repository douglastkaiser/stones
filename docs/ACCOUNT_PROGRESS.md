# Account progress: migration and merge foundation

2026-10-18, finishing packet 4, first implementation slice. Started from main
`7036dd9`. This contract and its repository tests precede UI/backend integration.
The running app still uses `AchievementNotifier` and its device-local v2 save.
No Firestore rules, deployed data, account UI or game mechanics change here.

## Data and merge contract

`lib/progression/progress_merge.dart` separates a frozen historical baseline from
future immutable events. `progress_repository.dart` serializes durable local
writes and exposes a transactional remote merge interface. SharedPreferences is
the initial local adapter; no Firebase remote adapter is enabled yet.

- Partition cache keys by encoded Firebase UID and validate the owner inside every
  decoded payload and remote response. Use a separate repository per owner and
  one live repository for that owner in a process. Sign-out selects guest state;
  it must not reuse the old account repository as the new account's provider.
- On migration, first use the existing notifier to consolidate old flags, the v1
  ledger and old learning keys into v2. Capture that v2 baseline **once before
  producing sync events**, leaving the source save untouched. Persist the frozen
  import with the account cache. Never import materialized account totals as a
  new baseline; doing so would double-count post-migration events.
- Merge historical counters with maxima, never sums. Overlap between old snapshots
  is unknowable: this preserves the highest known count but cannot recover every
  distinct historical win. Union match IDs, known learning, earned unlocks and
  evidence tags. Preserve unknown unlock/catalog names. Keep unaided completion
  only when recorded, and retain the earliest known earned date without inventing
  dates for historical awards. Old result-suffixed match IDs are normalized.
- New match evidence uses `match:<stable session id>`. Only a replay-qualified
  result adapter may produce its additive counters. A match cannot use an
  alternative event ID. Use stable lesson/puzzle IDs with distinct assisted and
  unaided completion identities when the learning adapter is added.
- Merge event maps by ID. Identical retries count once; the same ID with different
  evidence raises a conflict instead of silently selecting a device. Future event
  adapters must create deterministic payloads and persist them before sending;
  do not attach a new wall-clock timestamp to each replay of the same event.
- Suppress a match event's counters if the frozen baseline already lists its
  match. Still preserve its earned unlocks and learning. Never reconstruct old
  specialist wins from general totals. Streak counters are rejected in additive
  events: independent device streaks cannot be joined. Preserve historical streak
  maxima only until an ordered, tested streak protocol is specified.
- Signing in does not import a guest save. The future account UI must offer an
  explicit import/keep-separate choice, especially for an existing account. A
  confirmed import calls `importGuest`; retries are idempotent. Do not delete the
  guest source or attach it automatically to the next signed-in account.

## Durability and offline behavior

A local operation publishes new state only after its cache write succeeds. Failed
writes can be retried; corrupt, foreign and unsupported caches are not overwritten.
Local events survive restart before any remote acknowledgment. Network calls stay
outside the local write queue, so a stalled sync does not delay recording another
lesson or game. After receiving a response, merge with the latest local state
before committing. A late Alice response can only update Alice's repository/key.

The `ProgressRemote` contract requires an atomic server-side transaction that reads,
merges and writes under the authenticated owner. Snapshot replacement is forbidden.
A failed remote call retains all durable local evidence for retry. Events are not
pruned on acknowledgment: safe compaction needs a separate versioned protocol.
These are client progress records, not server-attested competitive credentials.

SharedPreferences does not provide cross-tab/process compare-and-swap. This first
adapter requires a single writer per owner; concurrent browser tabs need a
transactional local store or explicit writer coordination before activation.
An unbounded event map must not be uploaded as one ever-growing Firestore document.

## Qualification and remaining packet 4 work

Focused tests exercise overlapping historical snapshots, legacy ID import,
commutative/idempotent/associative merges, concurrent/offline device results,
duplicate/conflicting events, owner rejection, learning/award preservation,
preferences restart, failed writes, corrupt/future caches, sync failure/retry,
sign-in isolation and recording while a network response is pending.

Before enabling account progress:

1. Define bounded owner-private Firestore baseline/event documents, transaction
   retries, event size limits/pagination, offline reads and migration receipts.
   Test owner-only rules in the emulator before deploying them.
2. Supply replay/learning event adapters, explicit import UI, stable auth lifecycle
   binding and a tested streak protocol. Keep pending award notices device-local;
   migration does not replay every old award as a new notification.
3. Resolve multi-tab local writes and partial legacy import failures. Qualify two
   independent clients, offline earning, account switching during requests, cache
   write failure after server commit and recovery without progress duplication.
4. Connect achievements/cosmetic entitlements only after these tests pass. Audio,
   accessibility, selected appearance and other device preferences stay local.

Packet 3's independent invitee and Play-signed phone checks also remain pending.
This foundation is not a claim that cross-device progress has shipped.

## Local verification

Qualified in this cloud environment with Flutter 3.47.7 / Dart 3.13.5:

- `flutter analyze --fatal-infos`: no issues.
- `flutter test`: 848 passed in 4m59s. This run began before the final additional
  server-commit/cache-failure regression was added.
- Final focused merge/repository suite: all 16 passed, including that additional
  regression and recording local progress while a sync response is pending.
- `dart format --output=none --set-exit-if-changed` on the four new Dart files,
  and `git diff --check`: passed.

The SDK and package cache live under `/tmp`, outside the source tree. Generated
Flutter files are excluded locally; the SDK's automatic analyzer-config edit was
restored. No dependencies, Firebase configuration, deployed rules or release
artifacts were changed. The changes remain local on main for review.

## Verified-event adapter follow-up

`progress_recorder.dart` now converts a replay-qualified `MatchCompleted` into a
deterministic event using the stable normalized match ID, additive metrics and
opponent/expert-size tags. It excludes streak deltas and derives no award dates
or unlocks. Court, missing histories and ineligible results produce no event.
Learning accepts only catalog IDs; assisted/unaided puzzle events union into one
completion with a possible unaided upgrade. A bound recorder rejects online
results attributed to a different owner and persists accepted evidence locally.

Capture the recorder/repository when starting the game or study. Do not look up
the newly active account when a delayed completion arrives. Local games do not
carry an authenticated UID, so this binding is required to attribute their
results correctly. The adapter remains separate from the live provider until
backend, auth and migration integration is qualified. This is client replay
verification, not a server-attested competitive credential.

The event-adapter/feedback follow-up passed the complete 862-test suite, all 29
focused feedback/progress tests, strict analysis and the release-web build using
the same pinned SDK. No live-provider or Firebase storage activation is included.

# Home profiles, responsive tables and open invitations

Owner-requested follow-up to finishing main `7036dd9`. Existing local feedback
and progression work is preserved. This packet changes application journeys;
Square/Hex move rules, room versions and earned rewards are unchanged.

## Account and player name

Home now offers **Sign in with Google** directly. The signed-in player chip opens
an account/profile sheet with **Edit player name**, rating navigation and sign-out.
The Settings account card uses the same editor and existing account controller.
Guest linking, conflict handling and active-room account-switch protections remain.

`playerProfiles/{uid}` stores only a public Stones `name` and server `updatedAt`.
The name is separate from Google profile data, survives later Google sign-ins,
and is read by UID on other devices. It overlays stored rating aliases in home,
account, shared games, leaderboards and player details without rewriting ratings
or history. Missing profiles retain the previous name fallback. Profile reads
are individual document gets, not profile collection enumeration; writes are
owner-only, bounded to 40 characters and reject empty/control-character names.
No email, competitive counters or room content is stored in this collection.

## Board layout audit and repair

The previous shared screen used a 760-pixel-wide vertical column on desktop and
reserved 98 text-scaled pixels for players plus 230 for controls. Its board-size
calculation reserved a different amount of height, causing oversized scroll
content and unused space even when the useful controls fitted on a phone.

`MatchTableLayout` uses a board up to 760 pixels beside a 310-pixel controls
sidebar on wide viewports. Phones retain the vertical layout with compact,
content-sized controls. Board geometry depends on the viewport/configuration,
not selection controls or transient errors. Normal 390×844 two-player tables
have zero outer scroll extent; genuinely taller short-screen/large-text content
remains scrollable. Clamped scrolling prevents dragging into unused tail space.

The reachable home, setup, Join, My games, learning, account, Settings, collection
and feedback layouts use their existing bounded or content-sized scroll paths.
The unnecessary fixed control reservation was in the shared match screen; it was
removed there rather than disabling useful scrolling elsewhere. Existing legacy
screens remain available for old saves and rooms.

Automated captures use the actual MatchScreen, renderers and bundled fonts:
`build/qa/community/{square,hex}-{2,4}-{320,390,1366}.png`. They cover 320×568,
390×844 and 1366×900; existing shared screen tests also cover three players and
large text. Debug ribbons in captures are test UI. These are layout/gesture
checks, not physical-phone performance measurements.

## Invitation and QR recovery

Online tables show **Room CODE · Invite / QR** near the top. The invitation dialog
includes a selectable room code, a black-on-white canonical-HTTPS QR code, the
full link, sharing and separate copy-link/code actions. The code is no longer
buried below the board and control panel. Existing shortcut failure warnings
remain available even when local room bookmarking fails.

**Scan QR code** is restored to the shared Join screen. Camera access begins only
when the player opens the scanner. The existing invitation parser validates both
scanned and pasted content, including legacy codes; unrelated/foreign URLs are
not converted into room codes by stripping characters. A successful scan fills
the form. It never joins or claims a seat before the player confirms. Unsupported
camera platforms and permission failures explain the paste/code fallback.

## Opt-in Open tables

Home's quick actions now include **Open tables** beside private invitations.
Browsing authenticates a guest identity if needed but never opens Google sign-in
or claims a seat. The browser fetches at most 25 recent listings, displays public
host names and board/seat summaries, and opens the ordinary Join form on selection.
Refresh is explicit; a local timer hides expired entries without database polling.

Hosts can explicitly turn on **Open to anyone** for an unstarted shared room with
an empty online-human seat. `openTables/{hostUid}` holds only code, shape, size,
player count and server `seenAt`, with at most one listing per host. The rules
verify room ownership, actual settings, open seats and server timestamps. Private
`matches` enumeration remains forbidden. Existing gameplay transactions decide
who can actually claim a seat, so stale/full tables and racing joiners retain the
existing recovery behavior.

While the host keeps the waiting game open and foregrounded, its listing renews
once per minute. Listings are hidden after three minutes without a renewal.
Full/started games stop publication. Leaving the screen withdraws the matching
listing; withdrawal is conditional on its code so an old screen cannot delete a
new table belonging to the same account. Reopening restores current visibility.
Refreshes cannot recreate a withdrawn listing or overwrite a different table
published on another device. Existing invitation links continue working after
withdrawal; discovery removal is not invitation revocation.

Expiry is a discovery filter, not a promise of physical document deletion or
perfect live presence. Expired summaries occupy at most one document per host.
There is no matching queue, broad room scan, cloud AI, paid service or Blaze
upgrade. Future account deletion/retention work must include these two collections.

## Qualification and deployment boundary

The final rules passed all **81 emulator tests**, including owner-only profiles,
public bounded queries, private-room non-enumeration, forged summaries/timestamps,
withdrawal permissions and simultaneous seat claims. Existing room/rating rules
also passed. Rules SHA-256:
`0d7295cfdcef52fbf0d793f09f6f675af520c617fbda348dbcc850242f13c2f2`.

The full Flutter suite passed **884 tests**. After the final desktop four-seat
visibility correction, **44 focused tests** passed again, including actual
Square/Hex layouts and account/guest flows, cross-reader profile updates, QR
validation/recovery, restored visibility and withdrawn-listing races. Strict
analysis (`--fatal-infos`) is clean and the final release-web build succeeded.
The 12 layout captures were regenerated and the desktop four-seat capture was
visually checked with all four players visible.
Real Android camera permissions, physical QR scanning, OAuth and independent
production-account trials remain separate release checks.

On 2026-10-19 UTC, the authorized rules-only publication succeeded with:

```
firebase deploy --only firestore:rules --project stones-9a6a0 --non-interactive
```

The first attempt lacked Firebase authentication. The owner subsequently completed
the Firebase CLI browser login. Before deployment, the active production rules
were compared with main's baseline and matched exactly. After deployment, the
active ruleset was fetched independently and its source hash matched the tested
file above. Active ruleset:
`projects/stones-9a6a0/rulesets/e158e086-b1d8-4208-adc3-3fecaa05ecc5`.

This publishes only the additive profile and public-listing permissions. The app
changes remain local and the compiled client has not been released. Existing
rooms and user progress were not rewritten. Firebase login credentials and local
verification logs are outside the repository.

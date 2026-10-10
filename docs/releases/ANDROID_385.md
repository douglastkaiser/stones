# Stones Android 1.0.0 (385)

Source: main at 7c87c54. Signed build run:
https://github.com/douglastkaiser/stones/actions/runs/38058148684

## Proposed English Play release notes

New three-player Hex mode with human and AI seats, tutorials and puzzles.
Improved game rules, puzzle progression, movement controls and stack inspection.
Five ornate themes, with players' selected pieces visible in online games.
Resume saved online matches and use Court Mode for move advice and takebacks.
Improved Google account sign-in, mobile layouts and responsiveness.

## Release checks

- Existing upload keystore retained; invalid alias resolved by one matching
  registered private-key certificate. Release preflight passed in GitHub CI.
- Play Console upload-key SHA-1 matches the existing Firebase Android client:
  FA:63:FB:8F:BB:9B:27:F6:90:54:1B:E7:BC:11:62:AC:90:3A:30:CB.
- Current published closed-testing bundle is version code 354. New code 385 is
  greater; no existing release/version is replaced in the bundle history.
- Google Play production access is locked. The dashboard requires at least
  12 opted-in closed testers for 14 continuous days; currently three are shown.
- Credential exchange on a physical signed install remains a device trial.
- Play's current app-signing SHA-256 shown in Digital Asset Links is
  C1:B2:D1:79:4D:94:7B:D3:F1:73:94:01:72:11:56:30:85:75:EF:21:EE:33:C2:E9:45:AF:0E:67:F1:88:08:A2.
  This is distinct from the upload certificate. Do not rotate either key.

## Build result

The signed Android Release workflow completed successfully. Strict analysis,
433 Flutter tests, APK builds, the AAB build and all four APK signature checks
passed. All signatures matched Play's existing upload certificate. CI's separate
analysis, web and debug Android jobs passed too. Twelve Python preflight tests
passed locally and in CI.

- [Signed APK artifacts](https://github.com/douglastkaiser/stones/actions/runs/38058148684/artifacts/11672571192)
- [Play AAB artifact](https://github.com/douglastkaiser/stones/actions/runs/38058148684/artifacts/11672785945)
- [Checksums and release report](https://github.com/douglastkaiser/stones/actions/runs/38058148684/artifacts/11672676080)

The AAB artifact's downloaded ZIP SHA-256 matched GitHub's recorded digest:
1996fe64f1c42c922b8d406831eef21786a851b724254246015d1ae7340eb802.
Release metadata confirms package com.douglastkaiser.stones, code 385 and source
7c87c54. Optional Play Games is disabled; Firebase Google sign-in is independent.

The user selected internal testing. A draft with release notes was saved and
the existing Stones Testing list (three users) was selected and saved. The AAB
was accepted by Play Console (code 385, version name 1.0.0, minimum API 24,
target SDK 36). Release preview showed Ready to release, with no blocking
errors and an estimated 14.5 MB new-install download.

## Publication

Published to internal testing on 2026-10-10 at 07:38 America/Los_Angeles.
The track is Active and Play Console confirms **Available to internal testers**.

- [Tester opt-in/install link](https://play.google.com/apps/internaltest/4700980853067149320)
- [Play release details](https://play.google.com/console/u/0/developers/5337506295675098460/app/4973099668503873920/tracks/4700980853067149320/releases/1/details)

Google's confirmation says changes usually appear on Play within one hour,
occasionally longer. Use a Google account in the existing Stones Testing list.
No emails or invitations were sent, no signing key was rotated and no GitHub
secret was changed. Publication uses Play App Signing; standalone APKs use the
upload key and cannot update an install signed with Play's different certificate.

Physical-device installation, Google sign-in, online room resumption and a short
square/Hex play session remain the internal-testing trials. The older closed
track was left in place. Internal testing does not satisfy Google's separate
12-tester/14-day closed-testing prerequisite for production access.


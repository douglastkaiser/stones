# Stones Android 1.0.0 (403)

Source: main at `6788062be808533d63d50ae56c497153b53e037b`.
Package: `com.douglastkaiser.stones`. Flutter: 3.47.7.

## Build and acceptance

- [Signed release workflow](https://github.com/douglastkaiser/stones/actions/runs/38105834167) passed signing/Firebase preflight, strict analysis, tests, APK/AAB builds and APK signature verification. Existing signing credentials were retained.
- [Full CI](https://github.com/douglastkaiser/stones/actions/runs/38105796262) passed 668 Flutter tests, strict analysis, release web and Android compilation.
- [APK artifacts](https://github.com/douglastkaiser/stones/actions/runs/38105834167/artifacts/11689303245).
- [Play bundle](https://github.com/douglastkaiser/stones/actions/runs/38105834167/artifacts/11689333258).
- [Checksums/release report](https://github.com/douglastkaiser/stones/actions/runs/38105834167/artifacts/11689318177).

The downloaded AAB ZIP SHA-256 matches GitHub's digest:
`9e33de4fb6838cb8eb4bd8f6f198005c6dce60689d42d89471e0a2ad07d7d0ff`.
Extracted AAB SHA-256:
`48b6bb96fa06b3d3bdd8aac2be47ad43a5bdf5c64c75c4cdadcbb70380698f3c`.
Optional Play Games remains disabled; Firebase Google sign-in is independent.

Play Console accepted code 403/version 1.0.0, minimum API 24 and target SDK 36.
Preview reported Ready to release, no supported-device losses, and estimated
14.6 MB for a new install (63.7 KB above bundle 385). These are Play estimates,
not measured runtime performance or an actual device install.

## Release notes

Square and Hex now share one setup and control system. Play with 2–4 players
and mix local friends, online friends and AI.
Improved stack movement, themed pieces, saved-game recovery, clocks and Court
guidance. New tutorials and puzzles for multiplayer boards, plus fixes to
learning feedback and achievement attribution.

## Closed testing

The release was saved to the existing Alpha track with 100% rollout to its
selected testers. The publishing overview listed exactly one new change:
version 403. Submission was confirmed on 2026-10-10: Publishing overview shows **Changes in
review** for version 403. Google quick checks are running; changes go to review
after those succeed. Managed publishing is off, so approval publishes the update
automatically. It is not yet available on the Play Store. Existing tester/country
settings were retained.

Physical-device install/update, Google sign-in and multi-device play remain
necessary testing evidence. Use the [existing friends-testing checklist](ANDROID_385.md)
with version 403 once approved. Standalone upload-key-signed APKs cannot update
an installation signed with the different Play app-signing certificate.

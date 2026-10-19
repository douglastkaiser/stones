# Lightweight player feedback

2026-10-18. Settings and About now have **Send feedback**, available to guests
and signed-in players. This opens an editable form for a Problem, Idea or Other
report, with a short summary and details. No new package, service or account is
required. The destination is the support address already listed on the privacy
page: `douglastkaiser@gmail.com`.

The player reviews the report, optionally includes version/platform details, then
opens an email draft and sends it themselves. Opening a composer is never
represented as successful delivery. If launching email fails, times out or opens
nothing, the form remains editable and **Copy report** provides the complete
report for manual email. **Preview report** is selectable if clipboard access is
unavailable. Report content is not persisted in Stones; leaving this screen can
discard it. Email provider delivery and mailbox receipt require a real trial.

Automatic context is restricted to the generated app version/commit and Web/App
plus platform. No account ID, email, room code, browser URL/query, logs, screenshots
or saved moves are read or attached. A sent email exposes the sender's email
address and whatever they wrote. Clipboard export is explicitly user initiated.
The checked-in privacy page describes this behavior; it is not yet published.

## Addressing reports

Use the subject prefix `[Stones feedback]` to find reports in the support inbox.
The kind and summary follow it; optional version/platform details help identify
whether an issue affects a released version, a preview or a local build.

For each report:

1. Confirm the affected version and reproduction steps; ask only for the missing
   details needed to reproduce. Never request passwords or authentication tokens.
2. Check for an existing issue. Record a minimal reproduction and expected/actual
   behavior in the repository issue tracker, grouping duplicate reports.
3. Keep raw emails, sender addresses, invitation codes and private game details
   out of public issues. Obtain permission before quoting personal material.
4. Fix and verify the regression, recording the affected and fixed build versions.
   Track the issue until the corrected build is released; a local patch is not a
   delivered fix. Reply to the reporter when authorized to do so.

This change does not send email, read the inbox, create public issues or configure
mailbox rules. Those are follow-up triage actions. A lightweight shared issue
tracker plus this searchable inbox avoids another anonymous backend/spam queue.

## Qualification

Tests cover draft encoding, optional diagnostics, required-field validation,
launcher failures, editable recovery, clipboard export, guest About navigation
and 320-pixel layout at 200% text. Real Android email-composer and browser mailto
handling, actual receipt, and copy behavior on permission-restricted browsers
remain release checks. No test or development report was sent to the inbox.

Final local qualification on the working tree based on main `7036dd9`, using
Flutter 3.47.7 / Dart 3.13.5:

- Full `flutter test`: all 862 tests passed (5m34s).
- Focused feedback/progress suites: all 29 passed.
- `flutter analyze --fatal-infos`: no issues.
- `flutter build web --release --base-href /stones/`: passed.
- Formatting and `git diff --check`: passed.

The full run exposed an error-future/timeout callback interaction in the email
launcher fallback. The timeout now throws into the same guarded recovery path as
launcher failures; the final focused and complete runs passed after this fix.
The normal JavaScript build succeeded; existing dependency Wasm-dry-run and
Cupertino-font warnings remain. No Wasm or physical Android qualification is
claimed. Changes and build outputs are local; no deployment or email was sent.

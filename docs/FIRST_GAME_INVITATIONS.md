# First game and invitation implementation

Packet 3 in progress after owner approval of the revised design, 2026-10-17.
Production code and the review entry point now share GameMenu. The real home
routes to Square/Hex setup, learning, a separate Join screen and device My games.
The existing seat editor remains authoritative. Starter/clock/practice and rating
explanations are grouped under Game settings without rewriting MatchConfig.
Shared app typography uses the bundled sans/serif fonts and approved colors.

Invitations use `https://www.douglastkaiser.com/stones/?room=UABCDEF` and contain no
identity or authentication token. The parser also accepts old six-character and
H-prefixed codes and recognized old site hosts. Foreign origins, credentials,
ports, duplicate room parameters and unrelated paths/fragments are rejected.
Cold web URLs and native initial routes, warm native route pushes, and manually
pasted links lead to the same Join screen. Opening a link never authenticates or
claims a seat; the player presses Join. Switching an active game asks first;
cancelling does not leave its controller or change its durable save. Saved-room
recovery checks the original identity before leaving a current session.

Room sharing provides a canonical selectable link, copy-link and copy-code
buttons. Android invokes the OS sharesheet with ACTION_SEND; unsupported platforms
and older installed app binaries fall back to copying. Web uses the copy fallback.
The manifest declares HTTPS app links only for the canonical host and /stones/.
Do not claim verified Android association until the domain-root assetlinks file
matches the Play app-signing certificate and a Play installation passes cold/warm
invitation trials. A failed association should leave a functioning browser link.

Code qualification passed at `b8666a5`: 833 Flutter tests, strict analysis, normal
web and Android debug compilation. The isolated review workflow passed 81 focused
tests and 16 AI probes and captured 30 views, including the real home/setup at
320/1366 widths with 150% text. Live Square Court play, AI reply/explanation,
My games recovery, Hex 2/3/4-seat setup, invalid-link recovery and cancellation
of local-save replacement were exercised. Remaining gates: an independent
invitee trial and Play-signed app-link/install qualification. No Firebase access
rule, game schema, rating policy or Play track is changed in this packet.

References: [Flutter deep linking](https://docs.flutter.dev/ui/navigation/deep-linking),
[Android app links](https://docs.flutter.dev/cookbook/navigation/set-up-app-links),
[Android sharesheet](https://developer.android.com/training/sharing/send).

## Android association source

The public domain-root association initially returned HTTP 404. The exact Digital
Asset Links snippet was read from Play Console App signing on 2026-10-17 and
is retained in `docs/android/assetlinks.json`. The certificate is Play's app-signing
certificate, not the upload certificate. The statement was committed as
`ba451723d035df7683570d3f96c1b983d855e8e3` in the domain-root repository
`douglastkaiser/douglastkaiser.github.io`, preserving its existing tree. Root-site
run 39097313842 succeeded. The public endpoint returned HTTP 200, application/json,
and exactly the verified Play statement. Device verification remains pending. The Android intent
filter restricts handling to HTTPS www.douglastkaiser.com/stones/; browser fallback
continues to serve that URL. No signing key or account permission was changed.

## Qualified sources and review URLs

- Functional source: `b8666a5c0da0a231f36a48a6abc8d8fa8c88d8ed`.
- Full CI: https://github.com/douglastkaiser/stones/actions/runs/39097647956
- Review CI: https://github.com/douglastkaiser/stones/actions/runs/39097647931
- Actual app: https://www.douglastkaiser.com/stones/pr/finishing-game/?review=b8666a5
- Design-only sample: https://www.douglastkaiser.com/stones/pr/finishing/?review=b8666a5
- The actual app's live revision, HTML/bootstrap linkage and startup hashes passed
  the baseline check. Review output is in `build/qa/first-game-final/` locally and
  in the workflow artifacts. The final handoff commit only applies CI formatting
  to tests and records evidence. It does not change Dart runtime behavior.

## Main promotion requested by owner

On 2026-10-18, the owner explicitly requested committing/pushing all remaining
finishing work to main before closing the thread. This supersedes the earlier
branch-only status above. The qualified implementation is being promoted intact;
remaining device/invitee gates and later finishing packets are still outstanding.
Deploy Main is manual and no new web publication or Play release is part of this
final commit/push. Continue from the latest main in the next environment.

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

Verification pending: focused/full Flutter CI, web/Android compilation, real
production-entry-point layout and navigation capture, independent invitee trial,
and Play-signed app-link association/install qualification. No Firebase access
rule, game schema, rating policy or Play track is changed in this packet.

References: [Flutter deep linking](https://docs.flutter.dev/ui/navigation/deep-linking),
[Android app links](https://docs.flutter.dev/cookbook/navigation/set-up-app-links),
[Android sharesheet](https://developer.android.com/training/sharing/send).

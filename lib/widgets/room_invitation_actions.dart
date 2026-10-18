import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/room_invitation.dart';
import '../services/invitation_share.dart';

class RoomInvitationActions extends StatelessWidget {
  const RoomInvitationActions({super.key, required this.code});
  final String code;
  Future<void> _copy(BuildContext context, String text, String message) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Could not copy. Select this invitation instead: $text')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = roomInvitation(code);
    return Column(children: [
      SelectableText(link.toString(), textAlign: TextAlign.center),
      Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
                onPressed: () async {
                  final shown = await shareInvitation(link);
                  if (!shown && context.mounted) {
                    await _copy(
                        context, link.toString(), 'Invitation link copied');
                  }
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share invitation')),
            TextButton.icon(
                onPressed: () =>
                    _copy(context, link.toString(), 'Invitation link copied'),
                icon: const Icon(Icons.link),
                label: const Text('Copy link')),
            TextButton.icon(
                onPressed: () => _copy(context, code, 'Room code copied'),
                icon: const Icon(Icons.copy),
                label: const Text('Copy code')),
          ]),
    ]);
  }
}

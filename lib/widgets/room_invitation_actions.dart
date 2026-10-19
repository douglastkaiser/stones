import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/room_invitation.dart';
import '../services/invitation_share.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SelectableText(code,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontFamily: 'monospace', letterSpacing: 3)),
      const SizedBox(height: 12),
      Semantics(
          label: 'Room invitation QR code',
          excludeSemantics: true,
          image: true,
          child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: SizedBox.square(
                  dimension: 180,
                  child: QrImageView(
                      data: link.toString(),
                      size: 180,
                      backgroundColor: Colors.white)))),
      const SizedBox(height: 12),
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

class RoomInvitationBar extends StatelessWidget {
  const RoomInvitationBar({super.key, required this.code});
  final String code;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                SelectableText('Room $code',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                TextButton.icon(
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Invite / QR'),
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                                title: const Text('Invite players'),
                                scrollable: true,
                                content: SizedBox(
                                    width: 400,
                                    child: RoomInvitationActions(code: code)),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'))
                                ]))),
              ])));
}

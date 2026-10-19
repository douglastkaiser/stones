import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../game/room_invitation.dart';

class RoomQrScanner extends StatefulWidget {
  const RoomQrScanner({super.key});
  @override
  State<RoomQrScanner> createState() => _RoomQrScannerState();
}

class _RoomQrScannerState extends State<RoomQrScanner> {
  bool _accepted = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final supported = kIsWeb ||
        [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS]
            .contains(defaultTargetPlatform);
    return SafeArea(
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .8,
            child: Column(children: [
              ListTile(
                  title: const Text('Scan room QR code'),
                  trailing: IconButton(
                      tooltip: 'Close scanner',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context))),
              Expanded(
                  child: supported
                      ? MobileScanner(
                          errorBuilder: (context, error, child) => const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                      'Camera unavailable. Allow camera access in your browser or device settings, or close this scanner and paste the invitation instead.'))),
                          onDetect: (capture) {
                            if (_accepted) return;
                            for (final barcode in capture.barcodes) {
                              final value = barcode.rawValue;
                              if (value == null) continue;
                              try {
                                final code = roomCodeFromInvitation(value);
                                _accepted = true;
                                Navigator.pop(context, code);
                                return;
                              } catch (_) {
                                setState(() => _error =
                                    'This is not a valid Stones invitation. Try another QR code.');
                              }
                            }
                          })
                      : const Center(
                          child: Text(
                              'Camera scanning is unavailable here. Paste an invitation link or room code instead.'))),
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error ??
                      'Scan a Stones invitation. You will review the code before joining.')),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Enter code instead')),
            ])));
  }
}

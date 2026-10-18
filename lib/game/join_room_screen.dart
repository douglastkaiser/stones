import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tavern_theme.dart';
import 'room_navigation.dart';

/// Links and typed codes meet here. Joining always requires an explicit action.
class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key, this.invitation = ''});
  final String invitation;
  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}
class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  late final _code = TextEditingController(text: widget.invitation);
  bool _joining = false;
  String? _error;
  @override
  void dispose() { _code.dispose(); super.dispose(); }
  Future<void> _join() async {
    if (_joining) return;
    FocusScope.of(context).unfocus();
    setState(() { _joining = true; _error = null; });
    try {
      final screen = await loadInvitedRoom(ref, _code.text);
      if (!mounted || screen == null) return;
      await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => screen));
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is StateError
          ? error.message.toString()
          : 'Could not join. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Join a friend')),
    body: TavernBackdrop(child: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.all(20), child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: TavernPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Got an invitation?', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text('Paste the link or enter the room code. Your friend’s board and player setup come with it.'),
          const SizedBox(height: 20),
          TextField(controller: _code, enabled: !_joining,
              autocorrect: false, enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Invitation link or room code', hintText: 'UABCDEF'),
              onSubmitted: (_) => _join()),
          const SizedBox(height: 12),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, semanticsLabel: _error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error))),
          FilledButton.icon(onPressed: _joining ? null : _join,
              icon: const Icon(Icons.login), label: Text(_joining ? 'Joining...' : 'Join room')),
          const SizedBox(height: 12),
          const Text('Joining claims an available seat for this account or guest identity. To resume a seat, use its original account or browser profile.'),
        ]))))))));
}

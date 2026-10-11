import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'match_config.dart';
import 'match_provider.dart';
import 'match_screen.dart';
import 'match_setup_form.dart';

class MatchSetupScreen extends ConsumerStatefulWidget {
  const MatchSetupScreen({super.key, required this.shape});
  final BoardShape shape;
  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
  final _code = TextEditingController();
  bool _joining = false;
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_joining) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await ref.read(matchProvider.notifier).join(_code.text);
      if (!mounted) return;
      await Navigator.push<void>(context,
          MaterialPageRoute(builder: (context) => const MatchScreen()));
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(
              '${widget.shape == BoardShape.square ? 'Square' : 'Hex'} · set up a game')),
      body: SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            MatchSetupForm(
                                initialConfig:
                                    MatchConfig.defaults(widget.shape),
                                onStart: (config) async {
                                  await ref
                                      .read(matchProvider.notifier)
                                      .start(config);
                                  if (!context.mounted) return;
                                  await Navigator.push<void>(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const MatchScreen()));
                                }),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 12),
                            Text('Have an invitation?',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            const Text(
                                'Joining uses the host’s board and seat setup.'),
                            const SizedBox(height: 12),
                            TextField(
                                controller: _code,
                                enabled: !_joining,
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp('[a-zA-Z]')),
                                  LengthLimitingTextInputFormatter(7)
                                ],
                                decoration: const InputDecoration(
                                    labelText: 'Room code',
                                    hintText: 'UABCDEF'),
                                onSubmitted: (value) => _join()),
                            if (_error != null)
                              Text(_error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                                onPressed: _joining ? null : _join,
                                icon: const Icon(Icons.login),
                                label:
                                    Text(_joining ? 'Joining…' : 'Join room')),
                          ]))))));
}

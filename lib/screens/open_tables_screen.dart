import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/open_tables.dart';
import '../game/join_room_screen.dart';
import '../providers/account_provider.dart';
import '../widgets/player_name.dart';

class OpenTablesScreen extends ConsumerStatefulWidget {
  const OpenTablesScreen({super.key});
  @override
  ConsumerState<OpenTablesScreen> createState() => _OpenTablesScreenState();
}

class _OpenTablesScreenState extends ConsumerState<OpenTablesScreen> {
  List<OpenTable> _tables = [];
  bool _loading = true;
  String? _error;
  Timer? _expiry;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _expiry = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(accountProvider.notifier).ensurePlayer();
      final tables = await ref.read(openTablesRepositoryProvider).list();
      if (mounted) setState(() => _tables = tables);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Open tables could not load. Check your connection and retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tables =
        _tables.where((table) => table.fresh(DateTime.now())).toList();
    return Scaffold(
        appBar: AppBar(title: const Text('Open tables'), actions: [
          IconButton(
              tooltip: 'Refresh open tables',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh))
        ]),
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 740),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                  'Choose a table and review its invitation before joining. Hosts must opt in; private games are never listed.'),
                              const SizedBox(height: 16),
                              if (_loading) const LinearProgressIndicator(),
                              if (_error != null) ...[
                                Text(_error!),
                                TextButton(
                                    onPressed: _load,
                                    child: const Text('Retry'))
                              ] else if (!_loading && tables.isEmpty)
                                const Text(
                                    'No open tables right now. Start an online game and turn on Open to anyone to invite the next player.'),
                              for (final table in tables)
                                Card(
                                    child: ListTile(
                                        title: PlayerName(
                                            uid: table.host,
                                            fallback: 'Open table'),
                                        subtitle: Text(
                                            '${table.shape == 'square' ? 'Square' : 'Hex'} · size ${table.size} · ${table.players} players'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () => Navigator.push<void>(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => JoinRoomScreen(
                                                    invitation: table.code))))),
                            ]))))));
  }
}

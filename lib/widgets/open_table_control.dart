import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/match_provider.dart';
import '../providers/account_provider.dart';
import '../game/open_tables.dart';

class OpenTableControl extends ConsumerStatefulWidget {
  const OpenTableControl({super.key, required this.uid, required this.code});
  final String uid, code;
  @override
  ConsumerState<OpenTableControl> createState() => _OpenTableControlState();
}

class _OpenTableControlState extends ConsumerState<OpenTableControl>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _open = false, _busy = false, _foreground = true;
  String? _error;
  late final _repository = ref.read(openTablesRepositoryProvider);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(accountProvider).ready) unawaited(_restore());
  }

  Future<void> _restore() async {
    _timer?.cancel();
    setState(() => _busy = true);
    try {
      final open = await _repository.isPublished(widget.uid, widget.code);
      if (!mounted) return;
      setState(() => _open = open);
      if (open) {
        _timer = Timer.periodic(
            const Duration(minutes: 1), (_) => unawaited(_refresh()));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Listing status could not load. Retry before changing its visibility.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_open) {
      unawaited(_repository
          .withdraw(widget.uid, widget.code)
          .catchError((Object _) {}));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_open && _foreground) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (!_open || !_foreground || _busy) return;
    final room = ref.read(matchProvider).room;
    if (room == null ||
        room.code != widget.code ||
        !canPublishTable(room, widget.uid)) {
      await _toggle(false);
      return;
    }
    await _toggle(true, refresh: true);
  }

  Future<void> _toggle(bool value, {bool refresh = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (value) {
        await _repository.publish(widget.uid, widget.code, refresh: refresh);
      } else {
        await _repository.withdraw(widget.uid, widget.code);
      }
      if (!mounted) return;
      _timer?.cancel();
      setState(() => _open = value);
      if (value) {
        _timer = Timer.periodic(
            const Duration(minutes: 1), (_) => unawaited(_refresh()));
      }
    } on OpenTableReplaced {
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _open = false;
          _error = 'This listing was closed or replaced on another device.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not update Open tables. Your invitation still works. Retry when connected.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(matchProvider).room;
    final available = room != null && canPublishTable(room, widget.uid);
    if (_open && !available && !_busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open) unawaited(_toggle(false));
      });
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SwitchListTile(
          title: const Text('Open to anyone'),
          subtitle: const Text(
              'Show this invitation in Open tables so another player can join.'),
          value: _open,
          onChanged: _busy || (!available && !_open) ? null : _toggle),
      if (_error != null) ...[
        Text(_error!, textAlign: TextAlign.center),
        TextButton(
            onPressed: _busy ? null : _restore,
            child: const Text('Refresh listing status'))
      ],
    ]);
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/room_navigation.dart';
import '../providers/account_games_provider.dart';
import '../providers/account_provider.dart';
import '../services/account_game_repository.dart';

class AccountOnlineGames extends ConsumerStatefulWidget {
  const AccountOnlineGames({super.key, required this.uid});
  final String uid;
  @override
  ConsumerState<AccountOnlineGames> createState() => _AccountOnlineGamesState();
}

class _AccountOnlineGamesState extends ConsumerState<AccountOnlineGames>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;
  bool _archived = false, _loading = true;
  String? _error, _opening;
  AccountGamePage? _page;
  final _cursors = <Object?>[null];
  final _subscriptions = <StreamSubscription<AccountRoomStatus>>[];
  final _statuses = <String, String>{};
  int _generation = 0;
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    if (!visible) {
      _generation++;
      _cancel();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_current) unawaited(_load());
      });
    }
  }

  bool get _current =>
      mounted && ref.read(accountProvider).identity?.uid == widget.uid;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _opening == null) {
      unawaited(_load());
    }
  }

  void _cancel() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _cancel();
    if (!_current || !_visible) return;
    setState(() {
      _loading = true;
      _error = null;
      _statuses.clear();
    });
    try {
      final repository = ref.read(accountGameRepositoryProvider);
      final page = await repository
          .page(widget.uid, archived: _archived, after: _cursors.last)
          .timeout(const Duration(seconds: 20));
      if (!_current || generation != _generation) return;
      setState(() => _page = page);
      for (final game in page.games) {
        _subscriptions.add(repository.watch(game).listen((status) {
          if (_current && generation == _generation) {
            setState(() => _statuses[game.room.code] = status.label);
          }
        }, onError: (Object error) {
          if (_current && generation == _generation) {
            setState(() => _statuses[game.room.code] = error is StateError
                ? error.message.toString()
                : 'Room unavailable · retry or check your account');
          }
        }));
      }
    } catch (_) {
      if (_current && generation == _generation) {
        setState(() => _error =
            'Your online games could not be refreshed. Check your connection and retry.');
      }
    } finally {
      if (_current && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resume(AccountGame game) async {
    setState(() {
      _opening = game.room.code;
      _error = null;
    });
    try {
      final screen =
          await loadInvitedRoom(ref, game.room.code, expectedUid: widget.uid);
      if (!mounted || !_current || screen == null) return;
      await Navigator.push<void>(
          context, MaterialPageRoute(builder: (_) => screen));
    } catch (error) {
      if (_current) {
        setState(() => _error = error is StateError
            ? error.message.toString()
            : 'Could not resume. Check your connection and retry.');
      }
    } finally {
      if (_current) setState(() => _opening = null);
    }
  }

  Future<void> _change(AccountGame game, String action) async {
    try {
      await ref
          .read(accountGameRepositoryProvider)
          .update(widget.uid, game.room.code,
              archived: action == 'archive' ? !game.archived : null,
              muted: action == 'mute' ? !game.muted : null)
          .timeout(const Duration(seconds: 15));
      if (_current) await _load();
    } catch (_) {
      if (_current) {
        setState(() => _error =
            'Could not save that change. Retry when you are connected.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(importAccountRoomsProvider(widget.uid), (previous, next) {
      if (next.hasValue && !next.hasError && _opening == null) {
        unawaited(_load());
      }
    });
    final migration = ref.watch(importAccountRoomsProvider(widget.uid));
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Online games on your account',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Text('Resume on any device signed into this account.'),
                  Row(children: [
                    FilterChip(
                        label: const Text('Active'),
                        selected: !_archived,
                        onSelected: _loading || _opening != null
                            ? null
                            : (_) {
                                _archived = false;
                                _cursors
                                  ..clear()
                                  ..add(null);
                                unawaited(_load());
                              }),
                    const SizedBox(width: 8),
                    FilterChip(
                        label: const Text('Archived'),
                        selected: _archived,
                        onSelected: _loading || _opening != null
                            ? null
                            : (_) {
                                _archived = true;
                                _cursors
                                  ..clear()
                                  ..add(null);
                                unawaited(_load());
                              }),
                    const Spacer(),
                    IconButton(
                        tooltip: 'Refresh online games',
                        icon: const Icon(Icons.refresh),
                        onPressed: _loading || _opening != null ? null : _load),
                  ]),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  if (migration.hasError || (migration.valueOrNull ?? 0) > 0)
                    TextButton(
                        onPressed: () => ref
                            .invalidate(importAccountRoomsProvider(widget.uid)),
                        child: const Text('Retry importing device shortcuts')),
                  if (!_loading &&
                      _error == null &&
                      _page?.games.isEmpty == true)
                    Text(_archived
                        ? 'No archived online games.'
                        : 'No online games yet. Host a table or join a friend.'),
                  for (final game in _page?.games ?? <AccountGame>[])
                    ListTile(
                        key: ValueKey(game.room.code),
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(game.room.hex
                            ? Icons.hexagon_outlined
                            : Icons.grid_view),
                        title: Text(
                            '${game.room.hex ? 'Hex' : 'Square'} · ${game.room.code}'),
                        subtitle: Text(_opening == game.room.code
                            ? 'Loading confirmed game…'
                            : '${_statuses[game.room.code] ?? 'Checking current turn…'}${game.muted ? ' · Muted' : ''}'),
                        onTap: _opening != null ? null : () => _resume(game),
                        trailing: PopupMenuButton<String>(
                            enabled: _opening == null,
                            tooltip: 'Game options',
                            onSelected: (action) => _change(game, action),
                            itemBuilder: (_) => [
                                  PopupMenuItem(
                                      value: 'archive',
                                      child: Text(game.archived
                                          ? 'Restore to active games'
                                          : 'Archive game')),
                                  PopupMenuItem(
                                      value: 'mute',
                                      child: Text(game.muted
                                          ? 'Unmute turn notifications'
                                          : 'Mute turn notifications')),
                                ])),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                            onPressed: _loading ||
                                    _opening != null ||
                                    _cursors.length == 1
                                ? null
                                : () {
                                    _cursors.removeLast();
                                    unawaited(_load());
                                  },
                            child: const Text('Previous')),
                        TextButton(
                            onPressed: _loading ||
                                    _opening != null ||
                                    _page?.hasMore != true
                                ? null
                                : () {
                                    _cursors.add(_page!.cursor);
                                    unawaited(_load());
                                  },
                            child: const Text('Next')),
                      ]),
                  const Text(
                      'Archiving keeps the room and your seat. Online clocks keep running.',
                      style: TextStyle(fontSize: 12)),
                ])));
  }
}

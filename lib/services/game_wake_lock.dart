import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Only page routes cover a game; dialogs and menus keep its display awake.
final gameWakeLockRoutes = RouteObserver<PageRoute<dynamic>>();

final gameWakeLockProvider = Provider<GameWakeLock>((ref) => GameWakeLock());

/// Shares one platform lock across game screens and orders platform operations.
class GameWakeLock {
  GameWakeLock({Future<void> Function(bool)? toggle})
      : _toggle = toggle ?? ((enabled) => WakelockPlus.toggle(enable: enabled));

  final Future<void> Function(bool) _toggle;
  final Set<Object> _owners = {};
  Future<void> _pending = Future.value();
  bool? _enabled = false;

  Future<void> update(Object owner, bool active, {bool reassert = false}) {
    if (active) {
      _owners.add(owner);
    } else {
      _owners.remove(owner);
    }
    _pending = _pending.then((_) async {
      final wanted = _owners.isNotEmpty;
      if (_enabled == wanted && !reassert) return;
      try {
        await _toggle(wanted);
        _enabled = wanted;
      } catch (_) {
        // Unsupported browsers and denied requests must never block play.
        _enabled = null;
      }
    });
    return _pending;
  }

  void retry(Object owner) {
    if (_enabled == null && _owners.contains(owner)) {
      unawaited(update(owner, true));
    }
  }
}

/// Keeps an eligible game awake only while its page is visible and foregrounded.
class GameKeepAwake extends ConsumerStatefulWidget {
  const GameKeepAwake({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  ConsumerState<GameKeepAwake> createState() => _GameKeepAwakeState();
}

class _GameKeepAwakeState extends ConsumerState<GameKeepAwake>
    with WidgetsBindingObserver, RouteAware {
  final _owner = Object();
  late final GameWakeLock _lock;
  PageRoute<dynamic>? _route;
  bool _visible = true;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _lock = ref.read(gameWakeLockProvider);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  void _sync({bool reassert = false}) =>
      unawaited(_lock.update(_owner, widget.active && _visible && _foreground,
          reassert: reassert));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      gameWakeLockRoutes.unsubscribe(this);
      _route = route;
      _visible = route.isCurrent;
      gameWakeLockRoutes.subscribe(this, route);
    }
    _sync();
  }

  @override
  void didUpdateWidget(GameKeepAwake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  @override
  void didPushNext() {
    _visible = false;
    _sync();
  }

  @override
  void didPopNext() {
    _visible = true;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync(reassert: _foreground);
  }

  @override
  void dispose() {
    gameWakeLockRoutes.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_lock.update(_owner, false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _lock.retry(_owner),
        child: widget.child,
      );
}

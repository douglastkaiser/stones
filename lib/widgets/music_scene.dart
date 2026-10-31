import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/music_service.dart';

/// Only page routes select music. Sheets and dialogs keep the underlying cue.
class MusicDirector extends NavigatorObserver {
  final cue = ValueNotifier(MusicCue.menu);
  final _pages = <Route<dynamic>>[];
  final _scenes = <Route<dynamic>, MusicCue>{};

  void register(Route<dynamic> route, MusicCue value) {
    _scenes[route] = value;
    _refresh();
  }

  void unregister(Route<dynamic> route) {
    _scenes.remove(route);
    _refresh();
  }

  void _refresh() {
    cue.value =
        _pages.isEmpty ? MusicCue.menu : _scenes[_pages.last] ?? MusicCue.menu;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic>) _pages.add(route);
    _refresh();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pages.remove(route);
    _scenes.remove(route);
    _refresh();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      didPop(route, previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = _pages.indexOf(oldRoute!);
    if (index >= 0) {
      _pages.removeAt(index);
      if (newRoute is PageRoute<dynamic>) _pages.insert(index, newRoute);
    }
    _scenes.remove(oldRoute);
    _refresh();
  }

  void dispose() => cue.dispose();
}

final musicDirectorProvider = Provider<MusicDirector>((ref) {
  final director = MusicDirector();
  ref.onDispose(director.dispose);
  return director;
});

/// Optional so isolated previews/review pages can still render without audio or
/// an application ProviderScope. The app's single audio owner supplies this.
class MusicScope extends InheritedWidget {
  const MusicScope({super.key, required this.director, required super.child});
  final MusicDirector director;

  @override
  bool updateShouldNotify(MusicScope oldWidget) =>
      director != oldWidget.director;
}

/// Registration lives with the actual page, including isolated study providers,
/// instead of inferring gameplay from route names or the global match state.
class MusicScene extends StatefulWidget {
  const MusicScene({super.key, required this.cue, required this.child});
  final MusicCue cue;
  final Widget child;

  @override
  State<MusicScene> createState() => _MusicSceneState();
}

class _MusicSceneState extends State<MusicScene> {
  MusicDirector? _director;
  Route<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final director =
        context.dependOnInheritedWidgetOfExactType<MusicScope>()?.director;
    if (_route != route || _director != director) {
      if (_route != null) _director?.unregister(_route!);
      _route = route;
      _director = director;
    }
    if (route != null) _director?.register(route, widget.cue);
  }

  @override
  void didUpdateWidget(MusicScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_route != null && oldWidget.cue != widget.cue) {
      _director?.register(_route!, widget.cue);
    }
  }

  @override
  void dispose() {
    if (_route != null) _director?.unregister(_route!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

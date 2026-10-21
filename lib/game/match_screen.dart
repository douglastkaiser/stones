import '../widgets/room_invitation_actions.dart';
import 'dart:async';
import 'package:flutter/material.dart' hide Step;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/piece.dart';
import '../models/cosmetics.dart';
import '../providers/account_provider.dart';
import '../providers/cosmetics_provider.dart';
import '../providers/elite_theme_provider.dart';
import '../providers/elo_provider.dart';
import '../providers/settings_provider.dart';
import '../services/sound_manager.dart';
import 'board_view.dart';
import 'match_table_layout.dart';
import 'match_threats.dart';
import '../widgets/open_table_control.dart';
import 'board_geometry.dart';
import 'clock_label.dart';
import 'match_config.dart';
import 'match_controller.dart';
import 'match_provider.dart';
import 'match_rules.dart';
import 'match_state.dart';
import 'move_selection.dart';
import 'seat_appearance.dart';
import 'stack_move_tray.dart';
import 'rating_pool.dart';
import 'rating_submission.dart';
import 'match_completed.dart';
import 'match_standings.dart';
import 'result_share_dialog.dart';
import 'result_share_data.dart';
import 'result_explanation.dart';
import 'completed_match.dart';
import 'match_history_provider.dart';
import 'match_review_screen.dart';
import '../providers/player_profile_provider.dart';
import '../widgets/player_rating_label.dart';
import '../widgets/match_chat.dart';

class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key, this.title, this.studyPanel, this.objective});
  final String? title, objective;
  final Widget? studyPanel;
  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen>
    with WidgetsBindingObserver {
  final _selection = MoveSelection();
  bool _inspectPicking = false;
  bool _startingAgain = false;
  String? _lastTurnCue, _threatMatch;
  Set<SeatId> _announcedThreats = {};
  void _cueTurn(MatchSession current) {
    if (!_humanTurn(current)) return;
    final key = '${current.id}:${current.game!.ply}';
    if (_lastTurnCue == key) return;
    _lastTurnCue = key;
    if (!ref.read(appSettingsProvider).isSoundMuted) {
      unawaited(ref
          .read(soundManagerProvider)
          .play(GameSound.yourTurn)
          .catchError((Object _) {}));
    }
  }

  bool _humanTurn(MatchSession current) {
    final game = current.game;
    if (widget.studyPanel != null || game == null || !current.canPlay) {
      return false;
    }
    return current.room != null ||
        game.config.seats.where((s) => s.control != SeatControl.ai).length > 1;
  }

  late MatchController _controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ref.read(matchProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cueTurn(ref.read(matchProvider));
    });
    if (widget.objective != null) {
      WidgetsBinding.instance.addPostFrameCallback((time) {
        if (mounted) _objective();
      });
    }
  }

  void _objective() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: Text(widget.title ?? 'Objective'),
              scrollable: true,
              content: Text(widget.objective!),
              actions: [
                FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Let’s play'))
              ]));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.suspend();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(matchProvider).room != null &&
        ref.read(matchProvider).game?.finished != true) {
      unawaited(_controller.reconnect());
    }
    if ((state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) &&
        ref.read(matchProvider).room == null) {
      _controller.suspend();
    }
  }

  Future<void> _confirm() async {
    final move = _selection.planned;
    if (move == null || !ref.read(matchProvider).canPlay) return;
    if (await _controller.play(move) && mounted) setState(_selection.clear);
  }

  Future<void> _playAgain(MatchSession match) async {
    final rating = ref.read(ratingStatusProvider);
    if (_startingAgain ||
        match.room != null ||
        (rating?.$1 == match.id && rating!.$2.retryable) ||
        _controller.resultUpdatePending ||
        _controller.canRetryRewards) {
      return;
    }
    setState(() => _startingAgain = true);
    try {
      final completed =
          CompletedMatch.capture(match, _controller.confirmedMoves);
      await ref.read(completedMatchStorageProvider).save(completed);
      if (!mounted || ref.read(matchProvider).id != match.id) return;
      ref.invalidate(completedMatchesProvider);
      await _controller.start(completed.config
          .copyWith(starter: completed.config.next(completed.config.starter)));
      if (mounted) setState(_selection.clear);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not start another game. Your finished game is kept; try again.')));
      }
    } finally {
      if (mounted) setState(() => _startingAgain = false);
    }
  }

  void _tap(MatchState game, Cell cell) {
    if (_inspectPicking || !ref.read(matchProvider).canPlay) {
      _inspect(game, cell);
      return;
    }
    var confirm = false;
    setState(() => confirm = _selection.tap(game, cell));
    if (confirm) unawaited(_confirm());
  }

  void _inspect(MatchState game, Cell cell) => setState(() {
        final position =
            cell == _selection.source ? game : _selection.preview(game) ?? game;
        _selection.inspect(position, cell);
        if (position.stackAt(cell).isNotEmpty) _inspectPicking = false;
      });

  Future<void> _resign(MatchSession match) async {
    final game = match.game!;
    final owned = game.config.seats
        .where((s) =>
            s.control != SeatControl.ai &&
            (match.room == null || match.room!.owners[s.id] == match.uid))
        .toList();
    if (owned.isEmpty) return;
    final seat = await showDialog<SeatId>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(game.config.seats.length == 2
                    ? 'Resign?'
                    : 'End this match?'),
                content: Text(game.config.seats.length == 2
                    ? 'The other player wins. Select the player resigning.'
                    : 'This ends the match for everyone without a winner or win rewards.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Keep playing')),
                  for (final player in owned)
                    TextButton(
                        onPressed: () => Navigator.pop(context, player.id),
                        child: Text('${player.id.label} resigns')),
                ]));
    if (seat != null && mounted) await _controller.resign(seat);
  }

  void _help() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
          title: const Text('Playing Stones'),
          scrollable: true,
          content: const Text(
              'Every player can build a road between any opposite sides. '
              'Only exposed flats and capstones connect. Walls block roads.\n\n'
              'During the opening exchange each player places the next player’s flat. '
              'Then place your own flat, wall or cap on an empty cell, or move a stack you control.\n\n'
              'Tap an empty cell to preview; tap it again to place. Tap a stack to see its stones '
              'and choose the top portion to take. Tap a neighbor to drop one bottom stone in preview. '
              'Tap there again to add another, or tap the next cell to continue straight. '
              'Drop remaining here stages the rest. Confirm move commits the displayed result. '
              'Undo last drop revises; Cancel discards the draft. Inspect lets you examine another stack.\n\n'
              'Square has four directions; Hex has six. Carry is limited by the board’s longest row. '
              'A lone capstone can flatten a wall only at the final drop.\n\n'
              'Roads resolve after the complete move. The mover wins simultaneous roads if they have one; '
              'multiple opponent roads draw. Without a road, a full board or exhausted reserve ends play. '
              'Only exposed flats score; tied leaders draw.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))]));

  @override
  Widget build(BuildContext context) {
    final match = ref.watch(matchProvider);
    final game = match.game;
    final threats = game != null && game.config.court
        ? ref.watch(courtThreatsProvider(game)).valueOrNull ?? <SeatId>{}
        : <SeatId>{};
    if (_threatMatch != match.id) {
      _threatMatch = match.id;
      _announcedThreats = {};
    }
    if (game != null && game.config.court) {
      ref.listen(courtThreatsProvider(game), (previous, next) {
        final value = next.valueOrNull;
        if (value == null) return;
        final appeared = value.difference(_announcedThreats).isNotEmpty;
        _announcedThreats = value;
        if (appeared && !ref.read(appSettingsProvider).isSoundMuted) {
          unawaited(ref
              .read(soundManagerProvider)
              .play(GameSound.tak)
              .catchError((Object _) {}));
        }
      });
    }
    final myTurn = _humanTurn(match);
    ref.listen(matchProvider.select((s) => (s.id, s.game?.ply, s.canPlay)),
        (previous, next) {
      _cueTurn(ref.read(matchProvider));
    });
    ref.listen(matchProvider, (previous, next) {
      final before = previous?.game;
      final after = next.game;
      if (before == null ||
          after == null ||
          previous?.id != next.id ||
          after.ply != before.ply + 1 ||
          ref.read(appSettingsProvider).isSoundMuted) {
        return;
      }
      final sound = ref.read(soundManagerProvider);
      final flattened = before.board.keys.any((cell) =>
          before.topAt(cell)?.type == PieceType.standing &&
          after.stackAt(cell).any((p) => p.type == PieceType.flat) &&
          after.topAt(cell)?.type == PieceType.capstone);
      final placed = after.reserves.entries
          .any((e) => e.value.total < before.reserves[e.key]!.total);
      final feedback = after.finished
          ? sound.playWin()
          : flattened
              ? sound.playWallFlatten()
              : placed
                  ? sound.playThemedPiecePlace(next.room?.boardTheme ??
                      ref.read(currentBoardThemeProvider).theme)
                  : sound.playThemedStackMove(
                      next.room?.styles[before.current] ??
                          ref.read(currentPieceStyleProvider).style);
      unawaited(feedback.catchError((Object _) {}));
    });
    ref.listen(matchProvider.select((s) => (s.id, s.game)), (previous, next) {
      if (previous != next && mounted) {
        setState(() {
          _selection.clear();
          if (previous?.$1 != next.$1 || previous?.$2?.ply != next.$2?.ply) {
            _selection.type = PieceType.flat;
          }
          _inspectPicking = false;
        });
      }
    });
    if (game == null) {
      return const Scaffold(body: Center(child: Text('No match loaded')));
    }
    final preview = _selection.preview(game);
    final styles = match.room?.styles ??
        {
          for (final id in game.config.ids)
            id: ref.watch(currentPieceStyleProvider).style
        };
    final BoardTheme selectedBoard =
        match.room?.boardTheme ?? ref.watch(shareableBoardThemeProvider);
    final boardTheme = ref.watch(effectiveBoardThemeProvider((
      selectedBoard,
      match.room?.host ?? ref.watch(accountProvider).identity?.uid
    )));
    final ratingStatus = ref.watch(ratingStatusProvider);
    final ratingMessage =
        ratingStatus?.$1 == match.id ? ratingStatus?.$2 : null;
    final winner = game.result?.winner;
    final road = winner == null ? <Cell>{} : MatchRules.road(game, winner);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final practiceEnded = widget.studyPanel != null && match.inputLocked;
    final status = practiceEnded
        ? 'Practice finished'
        : game.finished
            ? '${winner?.label ?? (game.result!.draw ? 'Draw' : 'Match ended')} · ${game.result!.reason.name}'
            : !match.ready
                ? 'Waiting for online players'
                : match.reconnecting
                    ? 'Reconnecting · your board is retained'
                    : !match.connected
                        ? 'Disconnected · your board is retained'
                        : match.paused && match.room == null
                            ? 'Match paused'
                            : match.paused &&
                                    game.config.seat(game.current).control ==
                                        SeatControl.ai
                                ? 'AI paused'
                                : match.busy
                                    ? '${game.current.label} · ${game.config.seat(game.current).control == SeatControl.ai ? 'AI thinking' : 'Saving move'}'
                                    : '${game.current.label} to play${game.opening ? ' · opening exchange' : ''}';
    return Scaffold(
        appBar: AppBar(
            title: Text(
                widget.title ??
                    '${game.config.shape == BoardShape.square ? 'Square' : 'Hex'} · ${game.config.seats.length} players',
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            actions: [
              if (match.room != null &&
                  (!match.connected || match.error != null))
                IconButton(
                    tooltip: 'Reconnect',
                    onPressed: match.busy ? null : _controller.reconnect,
                    icon: const Icon(Icons.refresh)),
              if (match.room == null)
                IconButton(
                    tooltip: match.paused ? 'Resume match' : 'Pause match',
                    onPressed: () => _controller.pause(!match.paused),
                    icon: Icon(match.paused ? Icons.play_arrow : Icons.pause)),
              if (game.config.court) ...[
                IconButton(
                    tooltip: 'Explain a suggested move',
                    onPressed: !match.canPlay
                        ? null
                        : () async {
                            final move = await _controller.hint();
                            if (move != null && mounted) {
                              setState(() {
                                _selection.choose(move);
                              });
                            }
                          },
                    icon: const Icon(Icons.lightbulb_outline)),
                IconButton(
                    tooltip: 'Take back your last move and AI replies',
                    onPressed: match.busy
                        ? null
                        : () async {
                            if (await _controller.takeBack() && mounted) {
                              setState(_selection.clear);
                            }
                          },
                    icon: const Icon(Icons.undo)),
              ],
              IconButton(
                  tooltip: 'How to play',
                  onPressed: _help,
                  icon: const Icon(Icons.help_outline)),
              if (widget.objective != null)
                IconButton(
                    tooltip: 'Lesson objective',
                    onPressed: _objective,
                    icon: const Icon(Icons.menu_book_outlined)),
              if (widget.studyPanel == null &&
                  !game.finished &&
                  match.ready &&
                  game.config.seats.any((s) =>
                      s.control != SeatControl.ai &&
                      (match.room == null ||
                          match.room!.owners[s.id] == match.uid)))
                IconButton(
                    tooltip:
                        game.config.seats.length == 2 ? 'Resign' : 'End match',
                    onPressed: match.busy || !match.connected
                        ? null
                        : () => _resign(match),
                    icon: const Icon(Icons.flag_outlined)),
            ]),
        body: MatchTableLayout(
          invitation: match.room == null
              ? null
              : RoomInvitationBar(code: match.room!.code),
          players: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).width >= 1000
                      ? double.infinity
                      : 150 * scale),
              child: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final seat in game.config.seats)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          color: seat.id == game.current
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.transparent,
                                          width: 2),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                            radius: 12,
                                            backgroundColor:
                                                SeatAppearance.marker(seat.id),
                                            child: Text(seat.id.symbol,
                                                textScaler:
                                                    TextScaler.noScaling,
                                                style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 10))),
                                        const SizedBox(width: 6),
                                        Flexible(
                                            child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                              Text(
                                                  '${seat.id.label}: ${game.reserves[seat.id]!.stones} + ${game.reserves[seat.id]!.caps} caps'),
                                              if (seat
                                                      .control ==
                                                  SeatControl.ai)
                                                PlayerRatingLabel(
                                                    uid:
                                                        'ai_${game.config.aiEngine}_${seat.level.name}',
                                                    pool: RatingPool.forConfig(
                                                        game.config),
                                                    fallback:
                                                        '${seat.level.name} AI'),
                                              if (match.room?.owners[seat.id] !=
                                                  null)
                                                PlayerRatingLabel(
                                                    uid: match
                                                        .room!.owners[seat.id]!,
                                                    pool: RatingPool.forConfig(
                                                        game.config),
                                                    fallback: seat.id.label),
                                              if (match.clock != null)
                                                ClockLabel(
                                                    clock: match.clock!,
                                                    seat: seat.id,
                                                    finished: game.finished),
                                            ])),
                                      ])),
                          ])))),
          status: Semantics(
              liveRegion: true,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: myTurn
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                      '${myTurn ? match.room == null ? "${game.current.label}’s turn · " : "Your turn · " : ""}$status',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium))),
          board: BoardView(
              game: preview ?? game,
              original: preview == null ? null : game,
              selected: _selection.source ?? _selection.inspected,
              drops: _selection.drops,
              routeSource: _selection.source,
              routeDirection: _selection.direction,
              carried: _selection.hand(game),
              handCell: _selection.current,
              destinations: match.canPlay ? _selection.destinations(game) : {},
              road: road,
              styles: styles,
              theme: boardTheme,
              onCell: (cell) => _tap(game, cell),
              onInspect: (cell) => _inspect(game, cell),
              onSwipe: !match.canPlay || _inspectPicking
                  ? null
                  : (cell, direction) =>
                      setState(() => _selection.swipe(game, cell, direction))),
          primaryActions: _primaryActions(match, game),
          controls: Padding(
              padding: const EdgeInsets.all(8),
              child: _controls(match, game, styles)),
          details: Column(mainAxisSize: MainAxisSize.min, children: [
            if (threats.isNotEmpty)
              Semantics(
                  liveRegion: true,
                  child: Card(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                              'Tak! ${threats.map((s) => s.label).join(", ")} can win next move if the position stays unchanged.')))),
            if (match.room != null &&
                match.uid != null &&
                match.room!.owners.values.contains(match.uid))
              MatchChat(
                  key: ValueKey('chat-${match.id}-${match.uid}'),
                  room: match.id!,
                  uid: match.uid!,
                  finished: game.finished,
                  names: {
                    for (final e in match.room!.owners.entries)
                      if (e.value != null) e.value!: e.key.label
                  }),
            if (match.room != null && match.uid == match.room!.host)
              OpenTableControl(
                  key: ValueKey(match.room!.code),
                  uid: match.uid!,
                  code: match.room!.code),
            if (widget.studyPanel == null && ratingMessage != null)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Text(ratingMessage.message, textAlign: TextAlign.center),
                    if (game.finished && ratingMessage.retryable)
                      TextButton(
                          onPressed: () async {
                            final uid = ref.read(accountProvider).identity?.uid;
                            publishRating(
                                ref.read(ratingStatusProvider.notifier),
                                match.id!,
                                const RatingSubmission.pending());
                            try {
                              final message = await ref
                                  .read(ratingRepositoryProvider)
                                  .submitResult(
                                      match, _controller.confirmedMoves);
                              if (mounted &&
                                  ref.read(matchProvider).id == match.id &&
                                  ref.read(accountProvider).identity?.uid ==
                                      uid) {
                                publishRating(
                                    ref.read(ratingStatusProvider.notifier),
                                    match.id!,
                                    message);
                              }
                            } catch (error) {
                              if (mounted &&
                                  ref.read(matchProvider).id == match.id &&
                                  ref.read(accountProvider).identity?.uid ==
                                      uid) {
                                publishRating(
                                    ref.read(ratingStatusProvider.notifier),
                                    match.id!,
                                    RatingSubmission(
                                        RatingSubmissionState.failed,
                                        ratingFailureMessage(error),
                                        failure: ratingFailure(error)));
                              }
                            }
                          },
                          child: const Text('Retry rating update')),
                  ])),
            if (match.shortcutWarning != null)
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(match.shortcutWarning!)),
            if (match.error != null)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(match.error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            if (match.explanation != null && !practiceEnded)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(match.explanation!)),
            if (widget.studyPanel != null && !practiceEnded) widget.studyPanel!,
          ]),
        ));
  }

  Widget _controls(
    MatchSession match,
    MatchState game,
    Map<SeatId, PieceStyle> styles,
  ) {
    final inspected = _selection.inspected;
    final source = _selection.source;
    final position =
        inspected == source ? game : _selection.preview(game) ?? game;
    final stones =
        inspected == null ? const <Stone>[] : position.stackAt(inspected);
    final isCarry = inspected != null && inspected == source;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (match.elapsed != null) ElapsedLabel(elapsed: match.elapsed!),
        if (stones.isNotEmpty)
          StackMoveTray(
            label:
                '${!isCarry && !identical(position, game) ? 'Preview stack' : 'Stack'} $inspected',
            stones: stones,
            styles: styles,
            carry: isCarry ? _selection.carry : 0,
            dropped: isCarry ? _selection.dropped : 0,
            started: isCarry && _selection.started,
            carryLimit: game.geometry.carryLimit,
            showNextDrop: false,
            onCarry: isCarry && match.canPlay && !_selection.started
                ? (count) => setState(() => _selection.setCarry(count))
                : null,
            onReturn: source != null && !isCarry
                ? () => setState(() => _selection.inspected = source)
                : null,
          ),
        if (source == null) _moveControls(match, game),
        if (source != null) _draftActions(match, game, styles),
      ],
    );
  }

  Widget? _primaryActions(MatchSession match, MatchState game) {
    final source = _selection.source;
    final inspected = _selection.inspected;
    if (source != null || _selection.planned != null) {
      return Wrap(
        spacing: 12,
        alignment: WrapAlignment.center,
        children: [
          TextButton(
            onPressed: () => setState(() {
              _selection.clear();
              _inspectPicking = false;
            }),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: match.canPlay && previewLegal(game) ? _confirm : null,
            child: Text(source == null ? 'Confirm' : 'Confirm move'),
          ),
        ],
      );
    }
    if (inspected != null) {
      return Wrap(
        spacing: 8,
        alignment: WrapAlignment.center,
        children: [
          TextButton(
            onPressed: () => setState(() => _selection.inspected = null),
            child: const Text('Close inspection'),
          ),
          if (match.canPlay &&
              !game.opening &&
              game.topAt(inspected)?.seat == game.current)
            FilledButton(
              onPressed: () => setState(() => _selection.tap(game, inspected)),
              child: const Text('Move this stack'),
            ),
        ],
      );
    }
    return null;
  }

  String _resultSeatName(MatchSession match, SeatId id) {
    final seat = match.game!.config.seat(id);
    if (seat.control == SeatControl.ai) {
      return '${seat.level.name[0].toUpperCase()}${seat.level.name.substring(1)} AI';
    }
    final uid = match.room?.owners[id];
    return uid == null
        ? id.label
        : ref.watch(playerNameProvider(uid)).asData?.value ?? id.label;
  }

  Widget _moveControls(MatchSession match, MatchState game) {
    if (widget.studyPanel != null && match.inputLocked) {
      return Column(children: [
        if (match.explanation != null)
          Text(match.explanation!, textAlign: TextAlign.center),
        widget.studyPanel!,
      ]);
    }
    if (game.finished) {
      final rating = ref.watch(ratingStatusProvider)?.$1 == match.id
          ? ref.watch(ratingStatusProvider)!.$2
          : const RatingSubmission.unrated();
      final ratingLabel = rating.labelFor(MatchCompleted(match).participant);
      return Column(children: [
        const Text('Match complete'),
        const SizedBox(height: 8),
        Text(
            explainResult(game,
                winnerName: game.result!.winner == null
                    ? null
                    : _resultSeatName(match, game.result!.winner!)),
            textAlign: TextAlign.center),
        if (widget.studyPanel == null) ...[
          Wrap(alignment: WrapAlignment.center, spacing: 12, children: [
            OutlinedButton.icon(
                onPressed: () {
                  final record =
                      CompletedMatch.capture(match, _controller.confirmedMoves);
                  Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MatchReviewScreen(match: record)));
                },
                icon: const Icon(Icons.history),
                label: const Text('Review game')),
            if (match.room == null)
              OutlinedButton.icon(
                  onPressed: _startingAgain ||
                          rating.retryable ||
                          _controller.resultUpdatePending ||
                          _controller.canRetryRewards
                      ? null
                      : () => _playAgain(match),
                  icon: const Icon(Icons.replay),
                  label: Text(_startingAgain ? 'Starting…' : 'Play again')),
          ]),
          if (_controller.resultUpdatePending)
            const Text('Saving result…')
          else if (match.room == null && rating.retryable)
            const Text('Finish the rating update below before playing again.'),
          if (MatchStandings.forGame(game) case final standings?)
            for (final id in standings.ordered)
              Text(
                  '${game.config.ratingVersion >= 3 ? game.result!.winner == null ? "Draw" : game.result!.winner == id ? "Won" : "Lost" : ResultShareData.ordinal(standings.ranks[id]!)} · ${_resultSeatName(match, id)} · ${standings.flats[id]} flats'),
          Text(game.config.ratingVersion >= 3
              ? ratingLabel.replaceFirst('Elo', 'Rating')
              : ratingLabel),
          const SizedBox(height: 8),
          FilledButton.icon(
              onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ResultShareDialog(
                      session: match,
                      styles: {
                        for (final id in game.config.ids)
                          id: match.room?.styles[id] ??
                              ref.read(currentPieceStyleProvider).style
                      },
                      boardTheme: match.room?.boardTheme ??
                          ref.read(currentBoardThemeProvider).theme)),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share result')),
        ],
        Text(
            'Exposed flats: ${MatchRules.flatCounts(game).entries.map((e) => '${e.key.label} ${e.value}').join(' · ')}'),
        if (widget.studyPanel == null &&
            match.error != null &&
            ref.read(matchProvider.notifier).canRetryRewards)
          TextButton.icon(
              onPressed: ref.read(matchProvider.notifier).retryRewards,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry reward update')),
        if (widget.studyPanel == null)
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to play selection')),
      ]);
    }
    if (!match.canPlay) {
      return Text(match.ready
          ? 'Waiting for the current player.'
          : 'Share the room code with your friends.');
    }
    final move = _selection.planned;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final type
                in game.opening ? [PieceType.flat] : PieceType.values)
              ChoiceChip(
                  label: Text(switch (type) {
                    PieceType.flat => 'Flat',
                    PieceType.standing => 'Wall',
                    PieceType.capstone => 'Capstone'
                  }),
                  selected: _selection.type == type,
                  onSelected: !game.reserves[game.opening
                              ? game.config.next(game.current)
                              : game.current]!
                          .has(type)
                      ? null
                      : (_) => setState(() {
                            _selection.clear();
                            _selection.type = type;
                          })),
          ]),
      if (move == null && _selection.inspected == null)
        const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
                'Tap a stack to look inside. Tap an empty cell to preview a stone.')),
    ]);
  }

  Widget _draftActions(
      MatchSession match, MatchState game, Map<SeatId, PieceStyle> styles) {
    final hand = _selection.hand(game);
    final compact = TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_selection.feedback != null)
        Semantics(
            liveRegion: true,
            child: Text(_selection.feedback!, textAlign: TextAlign.center)),
      if (_inspectPicking)
        const Text('Tap any stack to inspect. Your draft is retained.'),
      if (hand.isNotEmpty) StackMoveTray.nextDrop(hand.first, styles),
      if (!_selection.started)
        const Text('Choose top stones, then tap a highlighted neighbor.',
            textAlign: TextAlign.center),
      if (_selection.started) ...[
        Text(
            _selection.remaining == 0
                ? 'All stones staged · ready to confirm'
                : 'Tap the current cell to add one, or the next highlighted cell to continue.',
            textAlign: TextAlign.center),
        Text('Drops along path: ${_selection.drops.join(', ')}'),
      ],
      Wrap(alignment: WrapAlignment.center, spacing: 4, children: [
        if (_selection.started && _selection.remaining > 0)
          TextButton(
              style: compact,
              onPressed: !match.canPlay
                  ? null
                  : () => setState(() => _selection.dropRemaining(game)),
              child: const Text('Drop remaining here')),
        if (_selection.started)
          Tooltip(
              message: 'Undo last drop',
              child: TextButton.icon(
                  style: compact,
                  onPressed: !match.canPlay
                      ? null
                      : () => setState(_selection.undoDrop),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Undo'))),
        Tooltip(
            message: _inspectPicking ? 'Back to move' : 'Inspect another stack',
            child: TextButton.icon(
                style: compact,
                onPressed: () =>
                    setState(() => _inspectPicking = !_inspectPicking),
                icon: Icon(
                    _inspectPicking ? Icons.close : Icons.layers_outlined,
                    size: 18),
                label: Text(_inspectPicking ? 'Back to move' : 'Inspect'))),
      ]),
    ]);
  }

  bool previewLegal(MatchState game) =>
      _selection.planned != null &&
      MatchRules.apply(game, _selection.planned!) != null;
}

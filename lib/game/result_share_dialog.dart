import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cosmetics.dart';
import '../providers/account_provider.dart';
import '../providers/player_profile_provider.dart';
import '../services/result_image_download.dart';
import '../services/result_share_service.dart';
import '../providers/elo_provider.dart';
import 'board_view.dart';
import 'match_completed.dart';
import 'match_config.dart';
import 'match_controller.dart';
import 'match_provider.dart';
import 'match_rules.dart';
import 'rating_submission.dart';
import 'result_share_data.dart';

final resultShareServiceProvider =
    Provider<ResultShareService>((ref) => const ResultShareService());

class ResultShareDialog extends ConsumerStatefulWidget {
  const ResultShareDialog(
      {super.key,
      required this.session,
      required this.styles,
      required this.boardTheme});
  final MatchSession session;
  final Map<SeatId, PieceStyle> styles;
  final BoardTheme boardTheme;
  @override
  ConsumerState<ResultShareDialog> createState() => _ResultShareDialogState();
}

class _ResultShareDialogState extends ConsumerState<ResultShareDialog> {
  final _boundary = GlobalKey();
  bool _includeBoard = false, _sharing = false;
  Uint8List? _png;
  String? _captureSignature;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(ratingStatusProvider)?.$1 != widget.session.id) {
        _refreshRating();
      }
    });
  }

  Future<void> _refreshRating() async {
    final identity = ref.read(accountProvider).identity;
    final session = widget.session;
    if (identity == null ||
        identity.guest ||
        ref.read(matchProvider).id != session.id) {
      return;
    }
    ref.read(ratingStatusProvider.notifier).state =
        (session.id!, const RatingSubmission.pending());
    try {
      final result = await ref.read(ratingRepositoryProvider).submitResult(
          session, ref.read(matchProvider.notifier).confirmedMoves);
      if (mounted &&
          ref.read(accountProvider).identity?.uid == identity.uid &&
          ref.read(matchProvider).id == session.id) {
        ref.read(ratingStatusProvider.notifier).state = (session.id!, result);
      }
    } catch (_) {
      if (mounted &&
          ref.read(accountProvider).identity?.uid == identity.uid &&
          ref.read(matchProvider).id == session.id) {
        ref.read(ratingStatusProvider.notifier).state =
            (session.id!, const RatingSubmission.failed());
      }
    }
  }

  Future<void> _copy(String value, String message) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      _message(message);
    } catch (_) {
      _message('Could not copy. Select the result text above.');
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _prepareImage(String signature) {
    if (_captureSignature == signature) return;
    _captureSignature = signature;
    _png = null;
    _imageError = null;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ui.Image? image;
      try {
        final boundary = _boundary.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null || !mounted) return;
        image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (mounted && _captureSignature == signature) {
          setState(() => _png = data?.buffer.asUint8List());
        }
      } catch (_) {
        if (mounted && _captureSignature == signature) {
          setState(() => _imageError =
              'Could not prepare the board image. You can still share the text.');
        }
      } finally {
        image?.dispose();
      }
    });
  }

  Future<void> _share(ResultShareData data) async {
    final render = context.findRenderObject() as RenderBox?;
    final origin =
        render == null ? null : render.localToGlobal(Offset.zero) & render.size;
    setState(() => _sharing = true);
    final result = await ref
        .read(resultShareServiceProvider)
        .share(data.text, png: _includeBoard ? _png : null, origin: origin);
    if (!mounted) return;
    setState(() => _sharing = false);
    if (result == ResultShareOutcome.unsupported) {
      if (_includeBoard && _png != null && downloadResultImage(_png!)) {
        _message('Board image downloaded. Use Copy result to share the text.');
      } else {
        await _copy(data.text, 'Sharing is unavailable here. Result copied.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final names = <SeatId, String>{};
    for (final seat in session.game!.config.seats) {
      final uid = session.room?.owners[seat.id] ??
          (session.room == null &&
                  seat.control != SeatControl.ai &&
                  session.game!.config.seats
                          .where((s) => s.control != SeatControl.ai)
                          .length ==
                      1
              ? session.uid
              : null);
      if (uid != null) {
        final name = ref.watch(playerNameProvider(uid)).asData?.value;
        if (name != null) names[seat.id] = name;
      }
    }
    final status = ref.watch(ratingStatusProvider);
    final identity = ref.watch(accountProvider).identity;
    final rating = status?.$1 == session.id
        ? status!.$2
        : const RatingSubmission.unrated();
    final participant = MatchCompleted(session).participant;
    final viewer = session.room != null && identity?.uid != session.uid
        ? null
        : participant;
    final data =
        ResultShareData(session, names: names, viewer: viewer, rating: rating);
    final signature =
        '${data.text}|${session.game!.config.ids.map((id) => '${data.name(id)}:${rating.labelFor(id)}').join('|')}';
    if (_includeBoard) _prepareImage(signature);
    return AlertDialog(
      title: const Text('Share result'),
      scrollable: true,
      content: SizedBox(
          width: 480,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SelectableText(data.text),
            if (rating.retryable)
              TextButton(
                  onPressed: _refreshRating, child: const Text('Refresh Elo')),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include final board'),
                value: _includeBoard,
                onChanged: _sharing
                    ? null
                    : (value) => setState(() {
                          _includeBoard = value;
                          _captureSignature = null;
                        })),
            if (_includeBoard) ...[
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: FittedBox(
                      alignment: Alignment.topCenter,
                      child: RepaintBoundary(
                          key: _boundary,
                          child: MediaQuery(
                              data: const MediaQueryData(),
                              child: ResultShareCard(
                                  data: data,
                                  styles: widget.styles,
                                  boardTheme: widget.boardTheme))))),
              if (_png == null && _imageError == null)
                const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Preparing board image…')),
              if (_imageError != null) Text(_imageError!),
              if (kIsWeb && _png != null)
                TextButton.icon(
                    onPressed: () => downloadResultImage(_png!),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download image')),
            ],
            const SizedBox(height: 12),
            Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                      onPressed: _sharing || (_includeBoard && _png == null)
                          ? null
                          : () => _share(data),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share')),
                  OutlinedButton.icon(
                      onPressed: _sharing
                          ? null
                          : () async {
                              final launched = await ref
                                  .read(resultShareServiceProvider)
                                  .sms(data.text);
                              if (!launched) {
                                await _copy(data.text,
                                    'Messaging is unavailable here. Result copied.');
                              }
                            },
                      icon: const Icon(Icons.sms_outlined),
                      label: const Text('Text message')),
                  TextButton.icon(
                      onPressed: () => _copy(data.text, 'Result copied'),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy result')),
                  TextButton.icon(
                      onPressed: () => _copy(stonesPlayUrl, 'Play link copied'),
                      icon: const Icon(Icons.link),
                      label: const Text('Copy link')),
                ]),
          ])),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close'))
      ],
    );
  }
}

/// A fixed-width export surface independent of viewport, selection, and controls.
class ResultShareCard extends StatelessWidget {
  const ResultShareCard(
      {super.key,
      required this.data,
      required this.styles,
      required this.boardTheme});
  final ResultShareData data;
  final Map<SeatId, PieceStyle> styles;
  final BoardTheme boardTheme;
  @override
  Widget build(BuildContext context) {
    final game = data.game;
    final winner = game.result?.winner;
    return Material(
        color: const Color(0xfff6f0e6),
        child: DefaultTextStyle(
          style: const TextStyle(
              fontFamily: 'StonesSans', color: Color(0xff29343b), fontSize: 16),
          child: Container(
              width: 540,
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('STONES',
                    style: TextStyle(
                        fontFamily: 'StonesLora',
                        fontSize: 32,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(data.outcome,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600)),
                Text(
                    '${data.boardLabel} · ${game.ply} moves · ${data.reason}${data.durationLabel == null ? '' : ' · ${data.durationLabel}'}',
                    textAlign: TextAlign.center),
                SizedBox.square(
                    dimension: 500,
                    child: IgnorePointer(
                        child: BoardView(
                            game: game,
                            styles: styles,
                            theme: boardTheme,
                            road: winner == null
                                ? {}
                                : MatchRules.road(game, winner)))),
                if (data.standings != null)
                  for (final id in data.standings!.ordered)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          SizedBox(
                              width: 44,
                              child: Text(ResultShareData.ordinal(
                                  data.standings!.ranks[id]!))),
                          Expanded(
                              child: Text(data.name(id),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          Text(data.rating.labelFor(id)),
                        ])),
                const SizedBox(height: 12),
                const Text('Play: www.douglastkaiser.com/stones/',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ])),
        ));
  }
}

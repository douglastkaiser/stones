import '../game/match_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/rating_pool.dart';
import '../models/elo_rating.dart';
import '../providers/elo_provider.dart';
import 'player_detail_screen.dart';
import 'settings_screen.dart';
import '../widgets/player_name.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _filter = 'All';
  late final EloController _controller;
  @override
  void initState() {
    super.initState();
    _controller = ref.read(eloProvider.notifier);
    Future<void>.microtask(() async {
      if (!mounted) return;
      await _controller.fetchLeaderboard();
      if (!mounted) return;
      _controller.startLive();
    });
  }

  @override
  void dispose() {
    _controller.stopLive();
    super.dispose();
  }

  void _pool(RatingPool pool) {
    ref.read(eloProvider.notifier).selectPool(pool);
    ref.read(eloProvider.notifier).fetchLeaderboard();
  }

  void _rules() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SafeArea(
          child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Text(
                  'How Stones ratings work\n\nEvery rated game updates Overall and its format ladder: board shape, size, player count, rules and clock category. '
                  'Humans and shared AI profiles use the same uncertainty-aware Glicko-based system. Live standings include both. '
                  'The winner beats every other seat. All other players receive a loss, without being ranked against one another. Larger games carry proportionally smaller loss penalties. A drawn game counts as a draw for everyone. '
                  'Changes depend on skill estimates and uncertainty.\n\n'
                  'Profiles show an approximate 95% skill range. It narrows as evidence accumulates and describes skill, not a range of leaderboard positions. '
                  'Ratings are provisional for at least ten games and until uncertainty is sufficiently low. Only humans receive rank numbers; equal established human ratings share a rank.\n\n'
                  'Signed-in players can record completed human, AI and mixed games. Online humans confirm the result. '
                  'Guest games, learning, Court Mode, abandoned games and shared human seats are unrated. '
                  'AI results are reported by the player’s device. '
                  'Player display names and competitive statistics are public. These are Stones ratings, not chess ratings.'))));
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eloProvider);
    ref.listen(eloProvider, (previous, next) {
      if (!identical(previous?.leaderboard, next.leaderboard)) {
        ref.invalidate(playerRankProvider);
      }
    });
    final pool = state.selectedPool;
    final own = state.localPlayerRating;
    final entries = state.leaderboard
        .where((entry) =>
            _filter == 'All' || (_filter == 'AI' ? entry.isAi : !entry.isAi))
        .toList();
    return Scaffold(
        appBar: AppBar(title: const Text('Competition'), actions: [
          IconButton(
              onPressed: state.loading
                  ? null
                  : ref.read(eloProvider.notifier).fetchLeaderboard,
              tooltip: 'Refresh standings',
              icon: const Icon(Icons.refresh)),
          IconButton(
              onPressed: _rules,
              tooltip: 'How ratings work',
              icon: const Icon(Icons.help_outline))
        ]),
        body: RefreshIndicator(
            onRefresh: () => ref.read(eloProvider.notifier).fetchLeaderboard(),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 840),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Find your standing',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            Text(pool.label),
                            const SizedBox(height: 16),
                            _select(
                                'Leaderboard',
                                pool.isOverall ? 'overall' : 'format',
                                ['overall', 'format'],
                                (value) => _pool(value == 'overall'
                                    ? const RatingPool.overall()
                                    : RatingPool.standard)),
                            if (!pool.isOverall)
                              Wrap(spacing: 12, runSpacing: 12, children: [
                                _select(
                                    'Board', pool.shape.name, ['square', 'hex'],
                                    (value) {
                                  final shape = BoardShape.values.byName(value);
                                  _pool(RatingPool(
                                      shape,
                                      shape == BoardShape.square ? 5 : 2,
                                      pool.players,
                                      shape == BoardShape.square &&
                                              pool.players == 2
                                          ? RulesProfile.standardTak
                                          : RulesProfile.sharedRoads,
                                      pool.clock));
                                }),
                                _select(
                                    'Size',
                                    '${pool.size}',
                                    MatchConfig.sizesFor(pool.shape)
                                        .map((s) => '$s')
                                        .toList(),
                                    (v) => _pool(RatingPool(
                                        pool.shape,
                                        int.parse(v),
                                        pool.players,
                                        pool.profile,
                                        pool.clock))),
                                _select('Players', '${pool.players}',
                                    ['2', '3', '4'], (v) {
                                  final players = int.parse(v);
                                  _pool(RatingPool(
                                      pool.shape,
                                      pool.size,
                                      players,
                                      pool.shape == BoardShape.square &&
                                              players == 2
                                          ? RulesProfile.standardTak
                                          : RulesProfile.sharedRoads,
                                      pool.clock));
                                }),
                                _select(
                                    'Clock category',
                                    pool.clock,
                                    ['open', 'fast', 'long'],
                                    (v) => _pool(RatingPool(
                                        pool.shape,
                                        pool.size,
                                        pool.players,
                                        pool.profile,
                                        v))),
                              ]),
                            const SizedBox(height: 16),
                            if (state.uid == null)
                              Card(
                                  child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                                'Sign in with Google for your account rating and rank.'),
                                            TextButton(
                                                onPressed: () => Navigator.push<
                                                        void>(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            const SettingsScreen())),
                                                child: const Text(
                                                    'Open account settings'))
                                          ])))
                            else
                              Card(
                                  child: InkWell(
                                      onTap: () => _openPlayer(own ??
                                          EloRating(
                                              id: state.uid!,
                                              displayName: 'You',
                                              pool: pool.id)),
                                      child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text('Your standing',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium),
                                                Text(own == null
                                                    ? 'Unrated · complete a rated game'
                                                    : '${own.ratingLabel} · ${own.provisional ? "Provisional · ${own.gamesPlayed} games" : state.rank == null ? "Rank pending" : "Rank #${state.rank}"}'),
                                                if (own?.uncertaintyLabel !=
                                                    null)
                                                  Text(own!.uncertaintyLabel!),
                                                if (own?.skill != null)
                                                  Text(own!.confidenceLabel),
                                                if (own != null)
                                                  Text(
                                                      '${own.wins} wins · ${own.losses} losses · ${own.draws} draws'),
                                              ])))),
                            if (state.loading) const LinearProgressIndicator(),
                            if (state.errorMessage != null)
                              Card(
                                  child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(state.errorMessage!),
                                            TextButton(
                                                onPressed: () => ref
                                                    .read(eloProvider.notifier)
                                                    .fetchLeaderboard(),
                                                child: const Text('Retry'))
                                          ]))),
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, children: [
                              for (final filter in ['All', 'Humans', 'AI'])
                                ChoiceChip(
                                    label: Text(filter),
                                    selected: _filter == filter,
                                    onSelected: (_) =>
                                        setState(() => _filter = filter)),
                            ]),
                            const SizedBox(height: 12),
                            Text(
                                '${pool.isOverall ? "Overall" : "Format"} standings · provisional ratings are marked ?'),
                            if (entries.isEmpty &&
                                !state.loading &&
                                state.errorMessage == null)
                              const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                      'No rated players in this ladder yet.')),
                            for (final player in entries)
                              _entry(
                                  player,
                                  player.isAi || player.provisional
                                      ? null
                                      : competitionRank(
                                          player.rating, state.leaderboard),
                                  state.uid),
                          ]))),
            ])));
  }

  Widget _select(String label, String value, List<String> options,
          ValueChanged<String> onChanged) =>
      SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
              initialValue: value,
              key: ValueKey('$label-$value'),
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: options
                  .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                          switch (item) {
                            'open' => 'Untimed',
                            'fast' => 'Under 10 min',
                            'long' => '10+ min',
                            'square' => 'Square',
                            'hex' => 'Hex',
                            'overall' => 'Overall',
                            'format' => 'By format',
                            _ => item
                          },
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (next) {
                if (next != null) onChanged(next);
              }));
  void _openPlayer(EloRating player) => Navigator.push<void>(context,
      MaterialPageRoute(builder: (_) => PlayerDetailScreen(player: player)));

  Widget _entry(EloRating rating, int? rank, String? uid) {
    return Card(
        child: InkWell(
            onTap: rating.gamesPlayed == 0 ? null : () => _openPlayer(rating),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 12, runSpacing: 6, children: [
                        if (rank != null) Text('#$rank'),
                        PlayerName(
                            uid: rating.id,
                            fallback: rating.displayName,
                            suffix: rating.id == uid ? ' (You)' : '',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(rating.ratingLabel),
                      ]),
                      Text(
                          '${rating.wins}W · ${rating.losses}L · ${rating.draws}D · ${rating.gamesPlayed} games'),
                      if (rating.isAi) const Text('AI · shared global rating'),
                      if (rating.uncertaintyLabel != null)
                        Text(rating.uncertaintyLabel!),
                      if (rating.provisional && rating.gamesPlayed > 0)
                        Text('Provisional · ${rating.gamesPlayed} games'),
                    ]))));
  }
}

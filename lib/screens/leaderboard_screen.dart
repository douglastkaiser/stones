import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/match_config.dart';
import '../game/rating_pool.dart';
import '../models/elo_rating.dart';
import '../providers/elo_provider.dart';
import 'player_detail_screen.dart';
import 'settings_screen.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  bool _bots = false;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(eloProvider.notifier).fetchLeaderboard());
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
                  'How Stones ratings work\n\nEach board size, shape, player count and clock category has its own ladder. '
                  'The first 10 games are provisional. Equal ratings share a rank. '
                  'Only completed online games between distinct signed-in accounts affect human ratings. '
                  'Local games, Court Mode, learning and AI games do not. Duels ending before both players move are unrated; later resignations and timeouts count. '
                  'In multiplayer, the winner beats each rival; losing rivals tie each other. A draw ties every pair.\n\n'
                  'AI community estimates use locally played, replay-checked untimed games against established human players. '
                  'Calibration needs 30 games and 10 distinct opponents, counting at most one sample per person per day. '
                  'Modified clients can falsify AI reports. Human ratings require all players to agree on the result. Each engine revision starts a new sample. A question mark means provisional or still calibrating. '
                  'These are Stones ratings, not chess ratings. Player display names and competitive statistics are public.'))));
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eloProvider);
    final pool = state.selectedPool;
    final own = state.localPlayerRating;
    final bots = [
      for (final level in BotLevel.values)
        state.aiRatings.values
                .where((r) => r.aiDifficulty == level.name)
                .firstOrNull ??
            EloRating(
                id: 'ai_shared-search-v1_${level.name}',
                displayName:
                    '${level.name[0].toUpperCase()}${level.name.substring(1)} AI',
                pool: pool.id,
                isAi: true,
                aiDifficulty: level.name)
    ];
    bots.sort((a, b) => b.rating.compareTo(a.rating));
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
                              _select(
                                  'Players', '${pool.players}', ['2', '3', '4'],
                                  (v) {
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
                                  (v) => _pool(RatingPool(pool.shape, pool.size,
                                      pool.players, pool.profile, v))),
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
                                                ? 'Unrated Â· play a competitive online game'
                                                : '${own.ratingLabel} Â· ${own.provisional ? "Provisional ${own.gamesPlayed}/10" : state.rank == null ? "Rank pending" : "Rank #${state.rank}"}'),
                                            if (own != null)
                                              Text(
                                                  '${own.wins} wins Â· ${own.losses} losses Â· ${own.draws} draws'),
                                          ]))),
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
                              ChoiceChip(
                                  label: const Text('Players'),
                                  selected: !_bots,
                                  onSelected: (_) =>
                                      setState(() => _bots = false)),
                              ChoiceChip(
                                  label: const Text('AI benchmarks'),
                                  selected: _bots,
                                  onSelected: (_) =>
                                      setState(() => _bots = true)),
                            ]),
                            const SizedBox(height: 12),
                            if (_bots &&
                                (pool.players != 2 || pool.clock != 'open'))
                              const Text(
                                  'AI benchmarks use untimed two-player duels. Choose 2 players and Untimed.')
                            else if (_bots) ...[
                              const Text(
                                  'Measured from play Â· ? means still calibrating. AI games do not change your competitive rating.'),
                              for (final bot in bots)
                                _entry(bot, null, state.uid),
                            ] else if (state.leaderboard.isEmpty &&
                                !state.loading &&
                                state.errorMessage == null)
                              const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                      'This ladder is waiting for its first established players. Complete 10 competitive games to join.'))
                            else ...[
                              const Text(
                                  'Top 50 established players Â· equal ratings share a rank'),
                              for (final player in state.leaderboard)
                                _entry(
                                    player,
                                    competitionRank(
                                        player.rating, state.leaderboard),
                                    state.uid),
                            ],
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
                            _ => item
                          },
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (next) {
                if (next != null) onChanged(next);
              }));
  Widget _entry(EloRating rating, int? rank, String? uid) => Card(
      child: InkWell(
          onTap: rating.gamesPlayed == 0
              ? null
              : () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PlayerDetailScreen(player: rating))),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 12, runSpacing: 6, children: [
                      if (rank != null) Text('#$rank'),
                      Text(
                          '${rating.displayName}${rating.id == uid ? " (You)" : ""}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(rating.ratingLabel),
                    ]),
                    Text(
                        '${rating.wins}W Â· ${rating.losses}L Â· ${rating.draws}D Â· ${rating.gamesPlayed} games'),
                    if (rating.isAi)
                      Text(
                          '${rating.opponents} opponents Â· ${rating.calibrated ? "Community estimate" : "Calibrating: needs 30 games and 10 opponents"}'),
                  ]))));
}

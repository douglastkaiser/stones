import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/elo_rating.dart';
import '../providers/elo_provider.dart';
import '../theme/game_colors.dart';
import 'player_detail_screen.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(eloProvider.notifier).fetchLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    final eloState = ref.watch(eloProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
      ),
      body: eloState.loading
          ? const Center(child: CircularProgressIndicator())
          : eloState.leaderboard.isEmpty
              ? _buildEmptyState(context)
              : _buildLeaderboard(context, eloState, isDark),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.leaderboard,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No ratings yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Play games to see ratings here!',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.read(eloProvider.notifier).fetchLeaderboard(),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(BuildContext context, EloState eloState, bool isDark) {
    final localRating = eloState.localPlayerRating;

    return RefreshIndicator(
      onRefresh: () => ref.read(eloProvider.notifier).fetchLeaderboard(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User's own rating card at the top
          if (localRating != null) ...[
            _buildOwnRatingCard(context, localRating, eloState.leaderboard, isDark),
            const SizedBox(height: 16),
          ],

          // Leaderboard header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Top Players',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          // Leaderboard entries
          for (int i = 0; i < eloState.leaderboard.length; i++)
            _LeaderboardEntry(
              rank: i + 1,
              rating: eloState.leaderboard[i],
              isCurrentUser: localRating != null &&
                  eloState.leaderboard[i].id == localRating.id,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerDetailScreen(
                      player: eloState.leaderboard[i],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOwnRatingCard(
    BuildContext context,
    EloRating rating,
    List<EloRating> leaderboard,
    bool isDark,
  ) {
    // Find user's rank in leaderboard
    final rank = leaderboard.indexWhere((r) => r.id == rating.id);
    final rankText = rank >= 0 ? '#${rank + 1}' : 'Unranked';

    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: isDark
                ? [Colors.amber.shade900.withValues(alpha: 0.3), Colors.transparent]
                : [Colors.amber.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Rating',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.amber.shade800 : Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    rankText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.amber.shade100 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatColumn(label: 'Rating', value: rating.rating.toString()),
                _StatColumn(label: 'Wins', value: rating.wins.toString()),
                _StatColumn(label: 'Losses', value: rating.losses.toString()),
                _StatColumn(label: 'Draws', value: rating.draws.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LeaderboardEntry extends StatelessWidget {
  final int rank;
  final EloRating rating;
  final bool isCurrentUser;
  final VoidCallback? onTap;

  const _LeaderboardEntry({
    required this.rank,
    required this.rating,
    this.isCurrentUser = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Medal colors for top 3
    Color? medalColor;
    if (rank == 1) medalColor = Colors.amber;
    if (rank == 2) medalColor = Colors.grey.shade400;
    if (rank == 3) medalColor = Colors.brown.shade300;

    final bgColor = isCurrentUser
        ? (isDark
            ? Colors.amber.shade900.withValues(alpha: 0.2)
            : Colors.amber.shade50)
        : null;

    final borderColor = isCurrentUser
        ? (isDark ? Colors.amber.shade700 : Colors.amber.shade300)
        : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
        children: [
          // Rank
          SizedBox(
            width: 36,
            child: medalColor != null
                ? Icon(Icons.emoji_events, color: medalColor, size: 24)
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Player info
          Expanded(
            child: Row(
              children: [
                // AI indicator or player avatar
                if (rating.isAi)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? GameColors.boardFrameInner.withValues(alpha: 0.3)
                          : GameColors.boardFrameInner.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.smart_toy,
                      size: 18,
                      color: isDark ? Colors.white70 : GameColors.boardFrameInner,
                    ),
                  )
                else
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isDark
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.blue.shade100,
                    child: Text(
                      rating.displayName.isNotEmpty
                          ? rating.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Colors.blue.shade800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating.displayName,
                        style: TextStyle(
                          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${rating.wins}W - ${rating.losses}L - ${rating.draws}D',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Rating
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${rating.rating}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: _ratingColor(rating.rating, isDark),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Color _ratingColor(int rating, bool isDark) {
    if (rating >= 1800) return isDark ? Colors.purple.shade300 : Colors.purple.shade700;
    if (rating >= 1500) return isDark ? Colors.amber.shade300 : Colors.amber.shade800;
    if (rating >= 1200) return isDark ? Colors.blue.shade300 : Colors.blue.shade700;
    return isDark ? Colors.grey.shade400 : Colors.grey.shade700;
  }
}

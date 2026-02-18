import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/elo_rating.dart';
import '../providers/elo_provider.dart';
import '../theme/game_colors.dart';

/// Shows a player's profile, stats, and ELO rating history chart.
class PlayerDetailScreen extends ConsumerStatefulWidget {
  final EloRating player;

  const PlayerDetailScreen({super.key, required this.player});

  @override
  ConsumerState<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends ConsumerState<PlayerDetailScreen> {
  List<EloHistoryEntry>? _history;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final history =
        await ref.read(eloProvider.notifier).fetchRatingHistory(widget.player.id);
    if (mounted) {
      setState(() {
        _history = history;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(player.displayName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Player header card
          _buildHeaderCard(context, player, isDark),
          const SizedBox(height: 24),

          // Rating history chart
          Text(
            'Rating History',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _buildChartSection(context, isDark),

          // Recent games list
          if (_history != null && _history!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Recent Games',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _buildRecentGames(context, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, EloRating player, bool isDark) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor: player.isAi
                      ? (isDark
                          ? GameColors.boardFrameInner.withValues(alpha: 0.3)
                          : GameColors.boardFrameInner.withValues(alpha: 0.15))
                      : (isDark
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.blue.shade100),
                  child: player.isAi
                      ? Icon(
                          Icons.smart_toy,
                          size: 28,
                          color: isDark ? Colors.white70 : GameColors.boardFrameInner,
                        )
                      : Text(
                          player.displayName.isNotEmpty
                              ? player.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Colors.blue.shade800,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (player.isAi)
                        Text(
                          '${player.aiDifficulty?[0].toUpperCase()}${player.aiDifficulty?.substring(1)} difficulty',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                // Rating badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${player.rating}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _ratingColor(player.rating, isDark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Games',
                  value: player.gamesPlayed.toString(),
                  isDark: isDark,
                ),
                _StatItem(
                  label: 'Wins',
                  value: player.wins.toString(),
                  color: Colors.green,
                  isDark: isDark,
                ),
                _StatItem(
                  label: 'Losses',
                  value: player.losses.toString(),
                  color: Colors.red,
                  isDark: isDark,
                ),
                _StatItem(
                  label: 'Draws',
                  value: player.draws.toString(),
                  isDark: isDark,
                ),
                _StatItem(
                  label: 'Win %',
                  value: player.gamesPlayed > 0
                      ? '${(player.wins * 100 / player.gamesPlayed).round()}%'
                      : '-',
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(BuildContext context, bool isDark) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_history == null || _history!.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No games played yet',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      child: CustomPaint(
        size: Size.infinite,
        painter: _RatingChartPainter(
          history: _history!,
          isDark: isDark,
        ),
      ),
    );
  }

  Widget _buildRecentGames(BuildContext context, bool isDark) {
    // Show last 20 games in reverse chronological order
    final recentGames = _history!.reversed.take(20).toList();

    return Column(
      children: [
        for (final entry in recentGames)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                // Win/loss/draw indicator
                Icon(
                  entry.score == 1.0
                      ? Icons.arrow_upward
                      : entry.score == 0.0
                          ? Icons.arrow_downward
                          : Icons.remove,
                  size: 16,
                  color: entry.score == 1.0
                      ? Colors.green
                      : entry.score == 0.0
                          ? Colors.red
                          : Colors.grey,
                ),
                const SizedBox(width: 8),
                // Opponent name
                Expanded(
                  child: Text(
                    entry.score == 1.0
                        ? 'Won vs ${entry.opponentName ?? "Unknown"}'
                        : entry.score == 0.0
                            ? 'Lost vs ${entry.opponentName ?? "Unknown"}'
                            : 'Drew vs ${entry.opponentName ?? "Unknown"}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Rating after game
                Text(
                  '${entry.rating}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _ratingColor(int rating, bool isDark) {
    if (rating >= 1800) return isDark ? Colors.purple.shade300 : Colors.purple.shade700;
    if (rating >= 1500) return isDark ? Colors.amber.shade300 : Colors.amber.shade800;
    if (rating >= 1200) return isDark ? Colors.blue.shade300 : Colors.blue.shade700;
    return isDark ? Colors.grey.shade400 : Colors.grey.shade700;
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool isDark;

  const _StatItem({
    required this.label,
    required this.value,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

/// Custom painter that draws a line chart of rating history.
class _RatingChartPainter extends CustomPainter {
  final List<EloHistoryEntry> history;
  final bool isDark;

  _RatingChartPainter({required this.history, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    const leftPadding = 40.0;
    const bottomPadding = 20.0;
    const topPadding = 8.0;
    final chartWidth = size.width - leftPadding;
    final chartHeight = size.height - bottomPadding - topPadding;

    // Compute rating range
    final ratings = history.map((e) => e.rating).toList();
    final minRating = ratings.reduce(min);
    final maxRating = ratings.reduce(max);
    // Pad range so the line isn't squished to edges
    final range = max(100, maxRating - minRating);
    final ratingFloor = minRating - (range * 0.1).round();
    final ratingCeil = maxRating + (range * 0.1).round();
    final ratingRange = (ratingCeil - ratingFloor).toDouble();

    // Map data to pixel positions
    double xForIndex(int i) {
      if (history.length == 1) return leftPadding + chartWidth / 2;
      return leftPadding + (i / (history.length - 1)) * chartWidth;
    }

    double yForRating(int rating) {
      return topPadding + chartHeight - ((rating - ratingFloor) / ratingRange) * chartHeight;
    }

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = isDark
          ? Colors.grey.shade800
          : Colors.grey.shade300
      ..strokeWidth = 0.5;
    final gridLabelStyle = TextStyle(
      fontSize: 10,
      color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
    );

    // Pick ~4 nice grid lines
    final gridStep = _niceStep(ratingRange / 4);
    final firstGrid = (ratingFloor / gridStep).ceil() * gridStep;
    for (var r = firstGrid; r <= ratingCeil; r += gridStep) {
      final y = yForRating(r);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width, y),
        gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(text: '$r', style: gridLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 4, y - tp.height / 2));
    }

    // Draw the rating line
    final linePaint = Paint()
      ..color = isDark ? Colors.amber.shade300 : Colors.amber.shade700
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < history.length; i++) {
      final x = xForIndex(i);
      final y = yForRating(history[i].rating);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Draw gradient fill under the line
    final fillPath = Path.from(path);
    fillPath.lineTo(xForIndex(history.length - 1), topPadding + chartHeight);
    fillPath.lineTo(xForIndex(0), topPadding + chartHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [Colors.amber.shade300.withValues(alpha: 0.25), Colors.transparent]
            : [Colors.amber.shade700.withValues(alpha: 0.15), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight));
    canvas.drawPath(fillPath, fillPaint);

    // Draw dots for each data point (if not too many)
    if (history.length <= 50) {
      final dotPaint = Paint()
        ..color = isDark ? Colors.amber.shade300 : Colors.amber.shade700;
      for (var i = 0; i < history.length; i++) {
        final x = xForIndex(i);
        final y = yForRating(history[i].rating);
        canvas.drawCircle(Offset(x, y), 3, dotPaint);
      }
    }

    // Draw start and end labels on the x-axis
    if (history.length >= 2) {
      final xLabelStyle = TextStyle(
        fontSize: 9,
        color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
      );
      final firstDate = history.first.timestamp;
      final lastDate = history.last.timestamp;
      final firstLabel = '${firstDate.month}/${firstDate.day}';
      final lastLabel = '${lastDate.month}/${lastDate.day}';

      final tp1 = TextPainter(
        text: TextSpan(text: firstLabel, style: xLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp1.paint(canvas, Offset(leftPadding, topPadding + chartHeight + 4));

      final tp2 = TextPainter(
        text: TextSpan(text: lastLabel, style: xLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp2.paint(canvas, Offset(size.width - tp2.width, topPadding + chartHeight + 4));
    }
  }

  /// Returns a "nice" step value for grid lines (e.g. 25, 50, 100, 200, 500).
  int _niceStep(double rawStep) {
    if (rawStep <= 25) return 25;
    if (rawStep <= 50) return 50;
    if (rawStep <= 100) return 100;
    if (rawStep <= 200) return 200;
    return 500;
  }

  @override
  bool shouldRepaint(covariant _RatingChartPainter oldDelegate) {
    return oldDelegate.history != history || oldDelegate.isDark != isDark;
  }
}

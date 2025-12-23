import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/achievement.dart';
import '../providers/achievements_provider.dart';
import '../theme/game_colors.dart';

/// Achievements screen showing all achievements and their unlock status
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementState = ref.watch(achievementProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // Count unlocked achievements
    final unlockedCount = achievementState.unlockedAchievements.length;
    final totalCount = AchievementType.values.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: GameColors.boardFrameInner,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Progress summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  GameColors.boardFrameInner,
                  GameColors.boardFrameInner.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '$unlockedCount / $totalCount',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Achievements Unlocked',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 16),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: totalCount > 0 ? unlockedCount / totalCount : 0,
                    minHeight: 12,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stats section
          _StatsSection(achievementState: achievementState, isDark: isDark),
          const SizedBox(height: 24),

          // Achievement list
          Text(
            'All Achievements',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Achievement cards
          ...achievements.map((achievement) {
            final isUnlocked = achievementState.isUnlocked(achievement.type);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AchievementCard(
                achievement: achievement,
                isUnlocked: isUnlocked,
                isDark: isDark,
                colorScheme: colorScheme,
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Stats section showing game statistics
class _StatsSection extends StatelessWidget {
  final AchievementState achievementState;
  final bool isDark;

  const _StatsSection({
    required this.achievementState,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.public,
                  label: 'Online Wins',
                  value: '${achievementState.onlineWins}',
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.school,
                  label: 'Tutorials',
                  value: '${achievementState.completedTutorials.length}/${AchievementState.allTutorialIds.length}',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.extension,
                  label: 'Puzzles',
                  value: '${achievementState.completedPuzzles.length}/${AchievementState.allPuzzleIds.length}',
                  color: Colors.purple,
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}

/// Individual stat item
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Achievement card widget
class _AchievementCard extends StatelessWidget {
  final GameAchievement achievement;
  final bool isUnlocked;
  final bool isDark;
  final ColorScheme colorScheme;

  const _AchievementCard({
    required this.achievement,
    required this.isUnlocked,
    required this.isDark,
    required this.colorScheme,
  });

  IconData get _achievementIcon {
    return switch (achievement.type) {
      AchievementType.student => Icons.school,
      AchievementType.puzzleSolver => Icons.extension,
      AchievementType.firstSteps => Icons.directions_walk,
      AchievementType.competitor => Icons.sports_martial_arts,
      AchievementType.strategist => Icons.psychology,
      AchievementType.grandmaster => Icons.military_tech,
      AchievementType.connected => Icons.public,
      AchievementType.dedicated => Icons.favorite,
      AchievementType.veteran => Icons.star,
      AchievementType.clockManager => Icons.timer,
      AchievementType.domination => Icons.grid_on,
    };
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isUnlocked
        ? (isDark ? colorScheme.primaryContainer : Colors.amber.shade50)
        : (isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100);

    final iconColor = isUnlocked ? Colors.amber : Colors.grey;
    final textColor = isUnlocked
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: isUnlocked
            ? Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 2)
            : null,
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Achievement icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? Colors.amber.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _achievementIcon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Achievement details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (isUnlocked)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 24,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
                if (achievement.unlocksReward != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.card_giftcard,
                          size: 14,
                          color: isUnlocked ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isUnlocked
                              ? 'Unlocked: ${achievement.unlocksReward}'
                              : 'Unlocks: ${achievement.unlocksReward}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isUnlocked ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

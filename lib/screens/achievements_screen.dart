import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/learning_hub.dart';
import '../models/achievement.dart';
import '../providers/achievements_provider.dart';
import 'settings_screen.dart';

enum _AchievementFilter { all, inProgress, earned }

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});
  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  AchievementTrack? _track;
  _AchievementFilter _filter = _AchievementFilter.all;
  @override
  void initState() {
    super.initState();
    ref.read(achievementProvider.notifier).load();
  }

  void _rules() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const SafeArea(
          child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Earning achievements',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),
                    Text(
                        'Square and Hex both count. Square match awards require 5×5 or larger. Each result is recorded once from its confirmed move history.'),
                    SizedBox(height: 12),
                    Text(
                        'Court Mode, tutorials, puzzle positions, spectators and pass-and-play do not earn match wins. Online seats must belong to different players. Online wins require a human opponent.'),
                    SizedBox(height: 12),
                    Text(
                        'AI tiers require standard two-player Square games won by road or flats. Stronger AI wins also advance lower tiers. Board craft needs Medium+ AI or independent online opponents; every AI opponent must meet the requirement.'),
                    SizedBox(height: 12),
                    Text(
                        'Early resignations and timeouts do not count. Online endings count toward general wins only after four full turn cycles; they never earn AI or board-craft awards. Winning a timed game by road or flats counts for Under Pressure.'),
                    SizedBox(height: 12),
                    Text(
                        'Hints never block learning completion. Clear Mind needs unaided solves on both shapes; revealing a hint marks the entire visit as assisted, including retries.'),
                    SizedBox(height: 12),
                    Text(
                        'Progress is saved on this device. Signing in does not synchronize it. Previously earned achievements and their full cosmetic sets are retained; historical evidence is not invented for new skill challenges. Achievement points are a collection rank, not a competitive rating.'),
                  ]))));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(achievementProvider);
    final colors = Theme.of(context).colorScheme;
    final visible = achievements
        .where((a) =>
            (_track == null || a.track == _track) &&
            switch (_filter) {
              _AchievementFilter.all => true,
              _AchievementFilter.inProgress =>
                !state.isUnlocked(a.type) && state.progress(a) > 0,
              _AchievementFilter.earned => state.isUnlocked(a.type),
            })
        .toList();
    final goals = achievements.where((a) => !state.isUnlocked(a.type)).toList()
      ..sort((a, b) => state.progress(b).compareTo(state.progress(a)));
    final next = goals.firstOrNull;
    return Scaffold(
        appBar: AppBar(
            title: const Text('Achievements',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                  onPressed: _rules,
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Earning rules'),
              IconButton(
                  tooltip: 'Use rewards',
                  icon: const Icon(Icons.palette_outlined),
                  onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()))),
            ]),
        body: SafeArea(
            child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      if (!state.loaded && state.storageError == null)
                        const LinearProgressIndicator(),
                      if (state.storageError != null)
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(state.storageError!,
                                          style:
                                              TextStyle(color: colors.error)),
                                      if (!state.loaded)
                                        TextButton(
                                            onPressed: ref
                                                .read(achievementProvider
                                                    .notifier)
                                                .load,
                                            child: const Text(
                                                'Retry loading progress')),
                                    ]))),
                      Card(
                          color: colors.primaryContainer,
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Achievement rank · ${state.rank}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 8),
                                    Text('${state.points} points',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineLarge),
                                    const SizedBox(height: 12),
                                    Text(
                                        '${state.unlockedAchievements.length} of ${achievements.length} earned'),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                        value:
                                            state.unlockedAchievements.length /
                                                achievements.length,
                                        semanticsLabel: 'Achievements earned'),
                                    const SizedBox(height: 16),
                                    Wrap(spacing: 16, runSpacing: 8, children: [
                                      Text(
                                          '${state.totalWins} qualifying wins'),
                                      Text('${state.onlineWins} online wins'),
                                      Text(
                                          '${state.metrics['hardStreak'] ?? 0} current Hard+ streak'),
                                    ]),
                                  ]))),
                      const SizedBox(height: 12),
                      const Text(
                          'Earn your collection through learning, precise play and strong opponents. Progress stays on this device.'),
                      if (next != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Card(
                                child: ListTile(
                                    isThreeLine: true,
                                    leading: const Icon(Icons.flag_outlined),
                                    title:
                                        Text('Next challenge · ${next.name}'),
                                    subtitle: Text(next.description),
                                    onTap: () => _details(next, state)))),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        ChoiceChip(
                            label: const Text('All tracks'),
                            selected: _track == null,
                            onSelected: (_) => setState(() => _track = null)),
                        for (final track in AchievementTrack.values)
                          ChoiceChip(
                              label: Text(track.label),
                              selected: _track == track,
                              onSelected: (_) =>
                                  setState(() => _track = track)),
                      ]),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        for (final filter in _AchievementFilter.values)
                          ChoiceChip(
                              label: Text(switch (filter) {
                                _AchievementFilter.all => 'All',
                                _AchievementFilter.inProgress => 'In progress',
                                _AchievementFilter.earned => 'Earned'
                              }),
                              selected: _filter == filter,
                              onSelected: (_) =>
                                  setState(() => _filter = filter)),
                      ]),
                      const SizedBox(height: 16),
                      Text('${visible.length} challenges',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      if (visible.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                                'No achievements in this view yet. Choose All to find your next goal.')),
                      LayoutBuilder(builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 800 ? 2 : 1;
                        final width =
                            (constraints.maxWidth - 12 * (columns - 1)) /
                                columns;
                        return Wrap(spacing: 12, runSpacing: 12, children: [
                          for (final a in visible)
                            SizedBox(
                                width: width,
                                child: _AchievementCard(
                                    achievement: a,
                                    state: state,
                                    onTap: () => _details(a, state)))
                        ]);
                      }),
                      const SizedBox(height: 20),
                      TextButton(
                          onPressed: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LearningHub())),
                          child: const Text('Explore tutorials & studies',
                              textAlign: TextAlign.center)),
                    ])))));
  }

  void _details(GameAchievement achievement, AchievementState state) {
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(achievement.name,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(achievement.description),
                      const SizedBox(height: 16),
                      for (final r in achievement.requirements)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                                '${state.value(r.metric)} / ${state.target(r)} ${r.label}')),
                      if (state.legacyUnlocks.contains(achievement.type))
                        const Text(
                            'Previously earned · retained through the progression upgrade.'),
                      if (achievement.unlocksReward != null)
                        Text(
                            'Reward: full ${achievement.unlocksReward!} board and pieces.'),
                      const SizedBox(height: 12),
                      if (achievement.track == AchievementTrack.learning)
                        FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push<void>(
                                  this.context,
                                  MaterialPageRoute(
                                      builder: (_) => const LearningHub()));
                            },
                            child: const Text('Open learning library')),
                    ]))));
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard(
      {required this.achievement, required this.state, required this.onTap});
  final GameAchievement achievement;
  final AchievementState state;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final earned = state.isUnlocked(achievement.type);
    final colors = Theme.of(context).colorScheme;
    final date = state.earnedAt[achievement.type]
        ?.toLocal()
        .toIso8601String()
        .split('T')
        .first;
    final icon = switch (achievement.track) {
      AchievementTrack.learning => Icons.school_outlined,
      AchievementTrack.craft => Icons.architecture_outlined,
      AchievementTrack.competition => Icons.emoji_events_outlined,
      AchievementTrack.mastery => Icons.military_tech_outlined,
    };
    return Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: earned ? colors.secondaryContainer : colors.surfaceContainerLow,
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Icon(icon, color: colors.primary),
                            Text(
                                '${achievement.tier.label} · ${achievement.points} points',
                                style: Theme.of(context).textTheme.labelLarge),
                            if (earned)
                              const Icon(Icons.check_circle_outline,
                                  semanticLabel: 'Earned'),
                          ]),
                      const SizedBox(height: 10),
                      Text(achievement.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(achievement.description),
                      const SizedBox(height: 14),
                      for (final r in achievement.requirements)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${state.value(r.metric)} / ${state.target(r)} ${r.label}'),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                      value: earned
                                          ? 1
                                          : (state.value(r.metric) /
                                                  state.target(r))
                                              .clamp(0.0, 1.0),
                                      semanticsLabel:
                                          '${achievement.name}: ${r.label}'),
                                ])),
                      if (earned)
                        Text(
                            state.legacyUnlocks.contains(achievement.type)
                                ? 'Previously earned · retained'
                                : date == null
                                    ? 'Earned'
                                    : 'Earned $date',
                            style: Theme.of(context).textTheme.labelMedium),
                      if (achievement.unlocksReward != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                '${earned ? 'Available' : 'Reward'}: ${achievement.unlocksReward!} · board & pieces',
                                style: Theme.of(context).textTheme.labelLarge)),
                    ]))));
  }
}

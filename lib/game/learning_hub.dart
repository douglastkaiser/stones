import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/achievements_provider.dart';
import 'match_config.dart';
import 'match_study.dart';
import 'study_catalog.dart';
import 'study_screen.dart';
import 'fundamentals.dart';
import 'match_preset.dart';
import 'match_setup_screen.dart';

class LearningHub extends ConsumerStatefulWidget {
  const LearningHub({super.key});
  @override
  ConsumerState<LearningHub> createState() => _LearningHubState();
}

class _LearningHubState extends ConsumerState<LearningHub> {
  BoardShape _shape = BoardShape.square;
  @override
  void initState() {
    super.initState();
    ref.read(achievementProvider.notifier).load();
  }

  Future<void> _solved(MatchStudy study, bool unassisted) async {
    final awards = ref.read(achievementProvider.notifier);
    if (study.puzzle) {
      await awards.completePuzzle(study.id, unassisted: unassisted);
    } else {
      await awards.completeTutorial(study.id);
    }
  }

  Future<void> _practice() async {
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => const MatchSetupScreen(
                shape: BoardShape.square, preset: MatchPreset.learn)));
  }

  Future<void> _openStudy(MatchStudy study) async {
    var current = study;
    while (mounted) {
      final index = squareFundamentals.indexOf(current.id);
      final next = index >= 0 && index + 1 < squareFundamentals.length
          ? matchStudies
              .firstWhere((s) => s.id == squareFundamentals[index + 1])
          : null;
      final action = await Navigator.push<StudyExit>(
          context,
          MaterialPageRoute(
              builder: (_) => StudyScreen(
                  study: current,
                  onSolved: (study) => _solved(study, false),
                  onResult: _solved,
                  nextLesson: next?.title,
                  offerPractice: index >= 0)));
      if (!mounted) return;
      if (action == StudyExit.practice) {
        // Start from the parent scope, never the lesson's sandbox controller.
        await _practice();
        return;
      }
      if (action != StudyExit.next || next == null) return;
      current = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    final awards = ref.watch(achievementProvider);
    final completed = {
      ...awards.completedTutorials,
      ...awards.completedPuzzles
    };
    final nextId = nextFundamental(completed);
    final learned = squareFundamentals.where(completed.contains).length;
    return Scaffold(
        appBar: AppBar(title: const Text('Tutorials & Puzzles')),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child:
                        ListView(padding: const EdgeInsets.all(20), children: [
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text('Square fundamentals',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 8),
                                    const Text(
                                        'Learn roads, walls, capstones, stacks and the opening. Then try a coached game.'),
                                    const SizedBox(height: 8),
                                    Text(
                                        '$learned of ${squareFundamentals.length} lessons · earn the Morocco theme'),
                                    const SizedBox(height: 12),
                                    if (!awards.loaded &&
                                        awards.storageError == null)
                                      const LinearProgressIndicator(),
                                    if (awards.storageError != null) ...[
                                      Text(awards.storageError!),
                                      TextButton(
                                          onPressed: ref
                                              .read(
                                                  achievementProvider.notifier)
                                              .load,
                                          child: const Text(
                                              'Retry loading progress')),
                                    ],
                                    if (nextId != null)
                                      FilledButton(
                                          onPressed: !awards.loaded
                                              ? null
                                              : () => _openStudy(
                                                  matchStudies.firstWhere(
                                                      (s) => s.id == nextId)),
                                          child: Text(learned == 0
                                              ? 'Start learning'
                                              : 'Continue learning')),
                                    OutlinedButton(
                                        onPressed: _practice,
                                        child:
                                            const Text('Try a coached game')),
                                  ]))),
                      const SizedBox(height: 20),
                      Text('Explore all lessons and studies',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      Wrap(spacing: 12, children: [
                        for (final shape in BoardShape.values)
                          ChoiceChip(
                              label: Text(shape == BoardShape.square
                                  ? 'Square'
                                  : 'Hex'),
                              selected: shape == _shape,
                              onSelected: (value) =>
                                  setState(() => _shape = shape))
                      ]),
                      const SizedBox(height: 12),
                      const Text(
                          'Practice in a separate sandbox. The controls match regular play; puzzles keep their verified player counts and rules.'),
                      for (final puzzle in [false, true]) ...[
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                                puzzle
                                    ? 'Progressive tactical studies'
                                    : 'Interactive tutorials',
                                style: Theme.of(context).textTheme.titleLarge)),
                        for (final study in matchStudies.where((s) =>
                            s.initial.config.shape == _shape &&
                            s.puzzle == puzzle))
                          Card(
                              child: ListTile(
                                  leading: Icon(completed.contains(study.id)
                                      ? Icons.check_circle
                                      : puzzle
                                          ? Icons.extension_outlined
                                          : Icons.school_outlined),
                                  title: Text(study.title),
                                  subtitle: Text(
                                      '${study.initial.config.seats.length} players · ${study.initial.config.size}${_shape == BoardShape.hex ? ' radius' : ' × ${study.initial.config.size}'}\n${study.goal}'),
                                  trailing: Icon(study.prerequisites
                                          .every(completed.contains)
                                      ? Icons.chevron_right
                                      : Icons.lock_outline),
                                  onTap: !study.prerequisites
                                          .every(completed.contains)
                                      ? null
                                      : () => _openStudy(study))),
                      ],
                    ])))));
  }
}

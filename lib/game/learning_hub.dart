import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/achievements_provider.dart';
import 'match_config.dart';
import 'match_study.dart';
import 'study_catalog.dart';
import 'study_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final awards = ref.watch(achievementProvider);
    final completed = {
      ...awards.completedTutorials,
      ...awards.completedPuzzles
    };
    return Scaffold(
        appBar: AppBar(title: const Text('Tutorials & Puzzles')),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child:
                        ListView(padding: const EdgeInsets.all(20), children: [
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
                                      '${study.initial.config.seats.length} players Â· ${study.initial.config.size}${_shape == BoardShape.hex ? ' radius' : ' Ã— ${study.initial.config.size}'}\n${study.goal}'),
                                  trailing: Icon(study.prerequisites
                                          .every(completed.contains)
                                      ? Icons.chevron_right
                                      : Icons.lock_outline),
                                  onTap: !study.prerequisites
                                          .every(completed.contains)
                                      ? null
                                      : () => Navigator.push<void>(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) => StudyScreen(
                                                  study: study,
                                                  onSolved: (study) => _solved(study, false),
                                                  onResult: _solved))))),
                      ],
                    ])))));
  }
}

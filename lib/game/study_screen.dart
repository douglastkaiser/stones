import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/puzzle_hints.dart';
import 'match_provider.dart';
import 'match_screen.dart';
import 'match_study.dart';
import 'study_controller.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key, required this.study, required this.onSolved});
  final MatchStudy study;
  final Future<void> Function(MatchStudy) onSolved;
  @override
  Widget build(BuildContext context) => ProviderScope(
          overrides: [
            matchProvider.overrideWith(
                (ref) => StudyController(study, onSolved: onSolved))
          ],
          child:
              MatchScreen(title: study.title, studyPanel: _StudyPanel(study)));
}

class _StudyPanel extends ConsumerWidget {
  const _StudyPanel(this.study);
  final MatchStudy study;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(matchProvider);
    final controller = ref.read(matchProvider.notifier) as StudyController;
    return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(study.goal, textAlign: TextAlign.center),
          if (study.puzzle)
            Text('${controller.steps}/${study.moveLimit} learner moves'),
          Wrap(alignment: WrapAlignment.center, spacing: 12, children: [
            if (study.hints.isNotEmpty) PuzzleHints(hints: study.hints),
            TextButton.icon(
                onPressed: controller.reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry')),
          ]),
          if (controller.solved)
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done')),
        ]));
  }
}

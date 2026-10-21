import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/puzzle_hints.dart';
import '../providers/achievements_provider.dart';
import 'match_provider.dart';
import 'match_screen.dart';
import 'match_study.dart';
import 'study_controller.dart';
import 'study_catalog.dart';
import 'fundamentals.dart';
import 'match_config.dart';
import 'match_preset.dart';
import 'match_setup_screen.dart';

class StudyScreen extends ConsumerWidget {
  const StudyScreen(
      {super.key, required this.study, this.onSolved, this.onResult});
  final MatchStudy study;
  final Future<void> Function(MatchStudy)? onSolved;
  final Future<void> Function(MatchStudy, bool)? onResult;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = squareFundamentals.indexOf(study.id);
    final next = index >= 0 && index + 1 < squareFundamentals.length
        ? matchStudies.firstWhere((s) => s.id == squareFundamentals[index + 1])
        : null;
    final awards = ref.read(achievementProvider.notifier);
    Future<void> save(MatchStudy value, bool unassisted) => value.puzzle
        ? awards.completePuzzle(value.id, unassisted: unassisted)
        : awards.completeTutorial(value.id);
    return ProviderScope(
        overrides: [
          matchProvider.overrideWith((ref) {
            late final StudyController controller;
            controller = StudyController(study,
                onSolved: (study) =>
                    onResult?.call(study, !controller.hintsUsed) ??
                    onSolved?.call(study) ??
                    save(study, !controller.hintsUsed));
            return controller;
          })
        ],
        child: MatchScreen(
            title: study.title,
            objective: study.goal,
            studyPanel:
                _StudyPanel(study, next: next, offerPractice: index >= 0)));
  }
}

class _StudyPanel extends ConsumerWidget {
  const _StudyPanel(this.study, {this.next, required this.offerPractice});
  final MatchStudy study;
  final MatchStudy? next;
  final bool offerPractice;
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
            if (study.hints.isNotEmpty)
              PuzzleHints(
                  hints: study.hints, onRevealed: controller.markHintUsed),
            TextButton.icon(
                onPressed: controller.reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry')),
          ]),
          if (study.puzzle)
            Text(controller.hintsUsed
                ? 'Hints used · completion still counts'
                : 'Unaided solve eligible'),
          if (controller.savingProgress) const Text('Saving progress…'),
          if (controller.canRetryProgress && !controller.savingProgress)
            TextButton.icon(
                onPressed: controller.retryProgress,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Retry saving progress')),
          if (controller.solved && !controller.canRetryProgress) ...[
            if (next != null)
              FilledButton(
                  onPressed: () => Navigator.pushReplacement<void, void>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => StudyScreen(study: next!))),
                  child: Text('Next lesson: ${next!.title}')),
            if (offerPractice)
              OutlinedButton(
                  onPressed: () => Navigator.pushReplacement<void, void>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MatchSetupScreen(
                              shape: BoardShape.square,
                              preset: MatchPreset.learn))),
                  child: const Text('Try a coached game')),
          ],
          if (controller.solved)
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done')),
        ]));
  }
}

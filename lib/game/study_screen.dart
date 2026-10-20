import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/puzzle_hints.dart';
import 'match_provider.dart';
import 'match_screen.dart';
import 'match_study.dart';
import 'study_controller.dart';

enum StudyExit { next, practice }

class StudyScreen extends StatelessWidget {
  const StudyScreen(
      {super.key,
      required this.study,
      required this.onSolved,
      this.onResult,
      this.nextLesson,
      this.offerPractice = false});
  final MatchStudy study;
  final Future<void> Function(MatchStudy) onSolved;
  final Future<void> Function(MatchStudy, bool)? onResult;
  final String? nextLesson;
  final bool offerPractice;
  @override
  Widget build(BuildContext context) => ProviderScope(
          overrides: [
            matchProvider.overrideWith((ref) {
              late final StudyController controller;
              controller = StudyController(study,
                  onSolved: (study) =>
                      onResult?.call(study, !controller.hintsUsed) ??
                      onSolved(study));
              return controller;
            })
          ],
          child: MatchScreen(
              title: study.title,
              objective: study.goal,
              studyPanel: _StudyPanel(study,
                  nextLesson: nextLesson, offerPractice: offerPractice)));
}

class _StudyPanel extends ConsumerWidget {
  const _StudyPanel(this.study, {this.nextLesson, required this.offerPractice});
  final MatchStudy study;
  final String? nextLesson;
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
            if (nextLesson != null)
              FilledButton(
                  onPressed: () => Navigator.pop(context, StudyExit.next),
                  child: Text('Next lesson: $nextLesson')),
            if (offerPractice)
              OutlinedButton(
                  onPressed: () => Navigator.pop(context, StudyExit.practice),
                  child: const Text('Try a coached game')),
          ],
          if (controller.solved)
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done')),
        ]));
  }
}

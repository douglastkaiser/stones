import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scenario.dart';
import '../services/ai/ai.dart';

class ScenarioState {
  final GameScenario? activeScenario;
  final int scriptedMoveIndex;
  final bool introShown;
  final bool completionShown;
  final bool guidedStepComplete;

  const ScenarioState({
    this.activeScenario,
    this.scriptedMoveIndex = 0,
    this.introShown = false,
    this.completionShown = false,
    this.guidedStepComplete = false,
  });

  ScenarioState copyWith({
    GameScenario? activeScenario,
    int? scriptedMoveIndex,
    bool? introShown,
    bool? completionShown,
    bool? guidedStepComplete,
    bool clearScenario = false,
  }) {
    return ScenarioState(
      activeScenario: clearScenario ? null : (activeScenario ?? this.activeScenario),
      scriptedMoveIndex: scriptedMoveIndex ?? this.scriptedMoveIndex,
      introShown: introShown ?? this.introShown,
      completionShown: completionShown ?? this.completionShown,
      guidedStepComplete: guidedStepComplete ?? this.guidedStepComplete,
    );
  }

  bool get hasScenario => activeScenario != null;

  AIMove? get nextScriptedMove {
    if (activeScenario == null) return null;
    if (scriptedMoveIndex >= activeScenario!.scriptedResponses.length) return null;
    return activeScenario!.scriptedResponses[scriptedMoveIndex];
  }
}

class ScenarioStateNotifier extends StateNotifier<ScenarioState> {
  ScenarioStateNotifier() : super(const ScenarioState());

  void startScenario(GameScenario scenario) {
    state = ScenarioState(
      activeScenario: scenario,
      scriptedMoveIndex: 0,
      introShown: false,
      completionShown: false,
      guidedStepComplete: false,
    );
  }

  void clearScenario() {
    state = const ScenarioState();
  }

  void advanceScript() {
    state = state.copyWith(scriptedMoveIndex: state.scriptedMoveIndex + 1);
  }

  void markIntroShown() {
    state = state.copyWith(introShown: true);
  }

  void markCompletionShown() {
    state = state.copyWith(completionShown: true);
  }

  void markGuidedStepComplete() {
    state = state.copyWith(guidedStepComplete: true);
  }
}

final scenarioStateProvider =
    StateNotifierProvider<ScenarioStateNotifier, ScenarioState>((ref) {
  return ScenarioStateNotifier();
});

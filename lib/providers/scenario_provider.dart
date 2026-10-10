import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scenario.dart';
import '../models/game_state.dart';
import '../models/piece.dart';
import '../services/ai/ai.dart';
import '../puzzles/certificates.dart';
import '../puzzles/square_forcing_position.dart';

class ScenarioState {
  final GameScenario? activeScenario;
  final int scriptedMoveIndex;
  final bool introShown;
  final bool completionShown;
  final bool guidedStepComplete;
  final int puzzleMoves;
  final AIMove? puzzleReply;
  final bool certificateError;

  const ScenarioState({
    this.activeScenario,
    this.scriptedMoveIndex = 0,
    this.introShown = false,
    this.completionShown = false,
    this.guidedStepComplete = false,
    this.puzzleMoves = 0,
    this.puzzleReply,
    this.certificateError = false,
  });

  ScenarioState copyWith({
    GameScenario? activeScenario,
    int? scriptedMoveIndex,
    bool? introShown,
    bool? completionShown,
    bool? guidedStepComplete,
    bool clearScenario = false,
    int? puzzleMoves,
    AIMove? puzzleReply,
    bool clearPuzzleReply = false,
    bool? certificateError,
  }) {
    return ScenarioState(
      activeScenario:
          clearScenario ? null : (activeScenario ?? this.activeScenario),
      scriptedMoveIndex: scriptedMoveIndex ?? this.scriptedMoveIndex,
      introShown: introShown ?? this.introShown,
      completionShown: completionShown ?? this.completionShown,
      guidedStepComplete: guidedStepComplete ?? this.guidedStepComplete,
      puzzleMoves: puzzleMoves ?? this.puzzleMoves,
      puzzleReply: clearPuzzleReply ? null : puzzleReply ?? this.puzzleReply,
      certificateError: certificateError ?? this.certificateError,
    );
  }

  bool get hasScenario => activeScenario != null;

  /// Finishing a puzzle is success only when its learner wins. A scripted
  /// puzzle must reach that result; its first guided step is not completion.
  bool isSuccessful(GameState game) {
    final scenario = activeScenario;
    if (scenario == null) return false;
    final learner = scenario.buildInitialState().currentPlayer;
    final won = game.result ==
        (learner == PlayerColor.white
            ? GameResult.whiteWins
            : GameResult.blackWins);
    if (scenario.type == ScenarioType.puzzle) {
      return game.isGameOver &&
          won &&
          puzzleMoves > 0 &&
          puzzleMoves <= scenario.puzzleMoveLimit &&
          !certificateError;
    }
    return guidedStepComplete || won;
  }

  AIMove? get nextScriptedMove {
    if (activeScenario == null) return null;
    if (activeScenario!.type == ScenarioType.puzzle) return puzzleReply;
    if (scriptedMoveIndex >= activeScenario!.scriptedResponses.length) {
      return null;
    }
    return activeScenario!.scriptedResponses[scriptedMoveIndex];
  }

  bool isFailed(GameState game) =>
      activeScenario?.type == ScenarioType.puzzle &&
      !isSuccessful(game) &&
      (certificateError ||
          game.isGameOver ||
          puzzleMoves >= activeScenario!.puzzleMoveLimit);
}

class ScenarioStateNotifier extends StateNotifier<ScenarioState> {
  ScenarioStateNotifier() : super(const ScenarioState());

  void startScenario(GameScenario scenario) {
    state = ScenarioState(
      activeScenario: scenario,
    );
  }

  void clearScenario() {
    state = const ScenarioState();
  }

  void advanceScript() {
    state = state.copyWith(
        scriptedMoveIndex: state.scriptedMoveIndex + 1, clearPuzzleReply: true);
  }

  void recordPuzzleMove(AIMove move) {
    final scenario = state.activeScenario;
    if (scenario?.type != ScenarioType.puzzle) return;
    final certificate = puzzleCertificates[scenario!.id];
    final replies = certificate?['replies'] as Map<String, dynamic>?;
    final keys =
        replies?[SquareForcingPosition().moveKey(move)] as List<dynamic>?;
    state = state.copyWith(
        puzzleMoves: state.puzzleMoves + 1,
        clearPuzzleReply: true,
        certificateError: state.puzzleMoves == 0 && keys == null);
    if (state.puzzleMoves == 1 && keys != null && keys.isNotEmpty) {
      state = state.copyWith(
          puzzleReply: SquareForcingPosition.decode(keys.first as String));
    }
  }

  void failCertificate() =>
      state = state.copyWith(certificateError: true, clearPuzzleReply: true);

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

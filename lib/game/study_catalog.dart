import '../hex/hex_exercises.dart';
import '../models/piece.dart';
import '../models/scenario.dart';
import 'match_config.dart';
import 'match_state.dart';
import 'match_study.dart';
import 'multiplayer_studies.dart';

const hexLearningProgressKey = 'hex_learning_completed_v1';
const unifiedLearningProgressKey = 'unified_learning_completed_v1';
final matchStudies = <MatchStudy>[
  ...tutorialAndPuzzleLibrary.map(MatchStudy.square),
  ...hexExercises.map(MatchStudy.hex),
  for (final shape in BoardShape.values)
    for (var count = 2; count <= 4; count++)
      MatchStudy(
          id: 'unified_v1_${shape.name}_exchange_$count',
          title: '$count-player opening exchange',
          goal:
              'Control all $count seats. Each places the next player’s flat; complete the whole opening cycle.',
          initial: MatchState.initial(MatchConfig(
              shape: shape,
              size: shape == BoardShape.square ? 5 : 2,
              seats: SeatId.values.take(count).map(SeatConfig.new).toList())),
          puzzle: false,
          moveLimit: count,
          lessonSteps: count,
          accepts: (move, step) => move.type == PieceType.flat,
          replies: (move) => const [],
          hints: [
            'Choose any empty cell. The color you place belongs to the next seat, not yours.'
          ],
          explanation:
              'Every seat has now given its successor one flat. Normal play uses your own pieces.'),
  ...multiplayerStudies,
];

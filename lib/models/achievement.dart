/// Achievement types available in the game
enum AchievementType {
  student,
  puzzleSolver,
  firstSteps,
  competitor,
  strategist,
  grandmaster,
  connected,
  dedicated,
  veteran,
  clockManager,
  domination,
}

/// Achievement definition with metadata
class GameAchievement {
  final AchievementType type;
  final String name;
  final String description;
  final String? unlocksReward;

  const GameAchievement({
    required this.type,
    required this.name,
    required this.description,
    this.unlocksReward,
  });

  /// Get achievement definition by type
  static GameAchievement forType(AchievementType type) {
    return achievements.firstWhere((a) => a.type == type);
  }
}

/// All achievements in the game
const List<GameAchievement> achievements = [
  GameAchievement(
    type: AchievementType.student,
    name: 'Student',
    description: 'Complete all tutorials',
    unlocksReward: 'Minimalist board theme',
  ),
  GameAchievement(
    type: AchievementType.puzzleSolver,
    name: 'Puzzle Solver',
    description: 'Complete all puzzles',
    unlocksReward: 'Polished Marble piece style',
  ),
  GameAchievement(
    type: AchievementType.firstSteps,
    name: 'First Steps',
    description: 'Beat Easy AI',
    unlocksReward: 'Minimalist piece style',
  ),
  GameAchievement(
    type: AchievementType.competitor,
    name: 'Competitor',
    description: 'Beat Medium AI',
    unlocksReward: 'Pixel Art piece style',
  ),
  GameAchievement(
    type: AchievementType.strategist,
    name: 'Strategist',
    description: 'Beat Hard AI',
    unlocksReward: 'Dark Stone board theme',
  ),
  GameAchievement(
    type: AchievementType.grandmaster,
    name: 'Grandmaster',
    description: 'Beat Expert AI',
    unlocksReward: 'Marble board theme',
  ),
  GameAchievement(
    type: AchievementType.connected,
    name: 'Connected',
    description: 'Win first online game',
    unlocksReward: 'Chiseled Stone piece style',
  ),
  GameAchievement(
    type: AchievementType.dedicated,
    name: 'Dedicated',
    description: 'Win 10 games (any mode)',
  ),
  GameAchievement(
    type: AchievementType.veteran,
    name: 'Veteran',
    description: 'Win 50 games (any mode)',
    unlocksReward: 'Pixel Art board theme',
  ),
  GameAchievement(
    type: AchievementType.clockManager,
    name: 'Clock Manager',
    description: 'Win by clock timeout',
  ),
  GameAchievement(
    type: AchievementType.domination,
    name: 'Domination',
    description: 'Win by flat count',
  ),
];

/// All supported achievement identifiers.
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

/// Metadata for presenting an achievement unlock.
class AchievementDetail {
  final AchievementType type;
  final String name;
  final String description;
  final String? unlocksText;

  const AchievementDetail({
    required this.type,
    required this.name,
    required this.description,
    this.unlocksText,
  });
}

/// Static registry of achievements with short descriptions and rewards.
const Map<AchievementType, AchievementDetail> achievementDetails = {
  AchievementType.student: AchievementDetail(
    type: AchievementType.student,
    name: 'Student',
    description: 'Complete all tutorials',
    unlocksText: 'Minimalist board theme',
  ),
  AchievementType.puzzleSolver: AchievementDetail(
    type: AchievementType.puzzleSolver,
    name: 'Puzzle Solver',
    description: 'Complete all puzzles',
    unlocksText: 'Polished Marble pieces',
  ),
  AchievementType.firstSteps: AchievementDetail(
    type: AchievementType.firstSteps,
    name: 'First Steps',
    description: 'Beat Easy AI',
  ),
  AchievementType.competitor: AchievementDetail(
    type: AchievementType.competitor,
    name: 'Competitor',
    description: 'Beat Medium AI',
  ),
  AchievementType.strategist: AchievementDetail(
    type: AchievementType.strategist,
    name: 'Strategist',
    description: 'Beat Hard AI',
    unlocksText: 'Dark Stone board',
  ),
  AchievementType.grandmaster: AchievementDetail(
    type: AchievementType.grandmaster,
    name: 'Grandmaster',
    description: 'Beat Expert AI',
    unlocksText: 'Marble board',
  ),
  AchievementType.connected: AchievementDetail(
    type: AchievementType.connected,
    name: 'Connected',
    description: 'Win your first online game',
    unlocksText: 'Hand Carved pieces',
  ),
  AchievementType.dedicated: AchievementDetail(
    type: AchievementType.dedicated,
    name: 'Dedicated',
    description: 'Win 10 games (any mode)',
  ),
  AchievementType.veteran: AchievementDetail(
    type: AchievementType.veteran,
    name: 'Veteran',
    description: 'Win 50 games (any mode)',
    unlocksText: 'Pixel Art board',
  ),
  AchievementType.clockManager: AchievementDetail(
    type: AchievementType.clockManager,
    name: 'Clock Manager',
    description: 'Win by clock',
  ),
  AchievementType.domination: AchievementDetail(
    type: AchievementType.domination,
    name: 'Domination',
    description: 'Win by flat count',
  ),
};

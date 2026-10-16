/// Stable wire names: never reorder or repurpose an earned ID.
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
  roadBuilder,
  hexStrategist,
  dualMaster,
  tripleCrown,
  fourCorners,
  giantSlayer,
  capstoneArchitect,
  wallBreaker,
  masterSpreader,
  precision,
  squareScholar,
  hexScholar,
  winningStreak,
  seasoned,
}

enum AchievementTrack {
  learning('Learning'),
  craft('Board craft'),
  competition('Competition'),
  mastery('Mastery');

  const AchievementTrack(this.label);
  final String label;
}

enum AchievementTier {
  bronze('Bronze', 15),
  silver('Silver', 35),
  gold('Gold', 70),
  platinum('Platinum', 120);

  const AchievementTier(this.label, this.points);
  final String label;
  final int points;
}

class AchievementRequirement {
  const AchievementRequirement(this.metric, this.target, this.label);
  final String metric, label;

  /// Zero means the current learning catalog supplies the target.
  final int target;
}

class GameAchievement {
  const GameAchievement(
      {required this.type,
      required this.name,
      required this.description,
      required this.track,
      required this.tier,
      required this.requirements,
      this.unlocksReward});
  final AchievementType type;
  final String name, description;
  final String? unlocksReward;
  final AchievementTrack track;
  final AchievementTier tier;
  final List<AchievementRequirement> requirements;
  int get points => tier.points;
  static GameAchievement forType(AchievementType type) =>
      achievements.firstWhere((a) => a.type == type);
}

const achievements = <GameAchievement>[
  GameAchievement(
      type: AchievementType.student,
      name: 'Student',
      description:
          'Complete every Square and Hex tutorial, including multiplayer openings.',
      track: AchievementTrack.learning,
      tier: AchievementTier.bronze,
      requirements: [AchievementRequirement('tutorials', 0, 'tutorials')],
      unlocksReward: 'Morocco theme'),
  GameAchievement(
      type: AchievementType.puzzleSolver,
      name: 'Puzzle Master',
      description:
          'Solve the complete tactical study collection on both board shapes. Hints are allowed.',
      track: AchievementTrack.learning,
      tier: AchievementTier.platinum,
      requirements: [AchievementRequirement('puzzles', 0, 'studies')],
      unlocksReward: 'Marble theme'),
  GameAchievement(
      type: AchievementType.firstSteps,
      name: 'First Steps',
      description:
          'Win 3 standard Square duels against Easy AI or stronger on 5×5 or larger.',
      track: AchievementTrack.competition,
      tier: AchievementTier.bronze,
      requirements: [AchievementRequirement('easyWins', 3, 'AI duel wins')],
      unlocksReward: 'Morocco theme'),
  GameAchievement(
      type: AchievementType.competitor,
      name: 'Competitor',
      description:
          'Win 5 standard Square duels against Medium AI or stronger on 5×5 or larger.',
      track: AchievementTrack.competition,
      tier: AchievementTier.silver,
      requirements: [
        AchievementRequirement('mediumWins', 5, 'Medium+ duel wins')
      ],
      unlocksReward: 'Kyoto theme'),
  GameAchievement(
      type: AchievementType.strategist,
      name: 'Strategist',
      description:
          'Win 10 standard Square duels against Hard AI or stronger on 5×5 or larger.',
      track: AchievementTrack.competition,
      tier: AchievementTier.gold,
      requirements: [AchievementRequirement('hardWins', 10, 'Hard+ duel wins')],
      unlocksReward: 'Slate theme'),
  GameAchievement(
      type: AchievementType.grandmaster,
      name: 'Grandmaster',
      description:
          'Win 12 standard Square duels against Expert AI across at least two board sizes (5×5 or larger).',
      track: AchievementTrack.mastery,
      tier: AchievementTier.platinum,
      requirements: [
        AchievementRequirement('expertWins', 12, 'Expert duel wins'),
        AchievementRequirement('expertSizes', 2, 'board sizes')
      ],
      unlocksReward: 'Marble theme'),
  GameAchievement(
      type: AchievementType.connected,
      name: 'Connected',
      description:
          'Win 5 online games against at least 3 different human opponents.',
      track: AchievementTrack.competition,
      tier: AchievementTier.silver,
      requirements: [
        AchievementRequirement('onlineWins', 5, 'online wins'),
        AchievementRequirement('opponents', 3, 'human opponents')
      ],
      unlocksReward: 'Slate theme'),
  GameAchievement(
      type: AchievementType.dedicated,
      name: 'Dedicated',
      description: 'Earn 25 qualifying wins across either board shape.',
      track: AchievementTrack.competition,
      tier: AchievementTier.silver,
      requirements: [AchievementRequirement('wins', 25, 'wins')]),
  GameAchievement(
      type: AchievementType.veteran,
      name: 'Veteran',
      description: 'Earn 100 qualifying wins across either board shape.',
      track: AchievementTrack.mastery,
      tier: AchievementTier.gold,
      requirements: [AchievementRequirement('wins', 100, 'wins')],
      unlocksReward: 'Kyoto theme'),
  GameAchievement(
      type: AchievementType.clockManager,
      name: 'Under Pressure',
      description:
          'Win 5 timed games by road or flat count against Medium+ AI or independent online opponents.',
      track: AchievementTrack.craft,
      tier: AchievementTier.silver,
      requirements: [
        AchievementRequirement('timedWins', 5, 'timed board wins')
      ]),
  GameAchievement(
      type: AchievementType.domination,
      name: 'Territory Expert',
      description:
          'Win 10 games by flat count against Medium+ AI or independent online opponents.',
      track: AchievementTrack.craft,
      tier: AchievementTier.gold,
      requirements: [
        AchievementRequirement('flatWins', 10, 'flat-count wins')
      ]),
  GameAchievement(
      type: AchievementType.roadBuilder,
      name: 'Road Builder',
      description:
          'Win 25 games by road against Medium+ AI or independent online opponents.',
      track: AchievementTrack.craft,
      tier: AchievementTier.gold,
      requirements: [AchievementRequirement('roadWins', 25, 'road wins')]),
  GameAchievement(
      type: AchievementType.hexStrategist,
      name: 'Hex Strategist',
      description:
          'Win 10 Hex games with every opponent set to Hard AI or stronger.',
      track: AchievementTrack.mastery,
      tier: AchievementTier.gold,
      requirements: [
        AchievementRequirement('hexHardWins', 10, 'Hard+ Hex wins')
      ]),
  GameAchievement(
      type: AchievementType.dualMaster,
      name: 'Two Worlds',
      description: 'Win 5 Square games and 5 Hex games against only Hard+ AI.',
      track: AchievementTrack.mastery,
      tier: AchievementTier.platinum,
      requirements: [
        AchievementRequirement('squareHardWins', 5, 'Square wins'),
        AchievementRequirement('hexHardWins', 5, 'Hex wins')
      ]),
  GameAchievement(
      type: AchievementType.tripleCrown,
      name: 'Triple Crown',
      description: 'Win 5 three-player games against two Hard+ AI opponents.',
      track: AchievementTrack.mastery,
      tier: AchievementTier.gold,
      requirements: [
        AchievementRequirement('threeHardWins', 5, 'three-player wins')
      ]),
  GameAchievement(
      type: AchievementType.fourCorners,
      name: 'Against Three',
      description: 'Win 5 four-player games against three Hard+ AI opponents.',
      track: AchievementTrack.mastery,
      tier: AchievementTier.platinum,
      requirements: [
        AchievementRequirement('fourHardWins', 5, 'four-player wins')
      ]),
  GameAchievement(
      type: AchievementType.giantSlayer,
      name: 'Grand Design',
      description:
          'Win 5 games on Square 7×7/8×8 or Hex radius 4 against only Hard+ AI.',
      track: AchievementTrack.mastery,
      tier: AchievementTier.platinum,
      requirements: [
        AchievementRequirement('largeHardWins', 5, 'large-board wins')
      ]),
  GameAchievement(
      type: AchievementType.capstoneArchitect,
      name: 'Capstone Architect',
      description:
          'Win 10 roads whose connecting road includes your capstone, against Medium+ AI or independent online opponents.',
      track: AchievementTrack.craft,
      tier: AchievementTier.gold,
      requirements: [
        AchievementRequirement('capRoadWins', 10, 'capstone roads')
      ]),
  GameAchievement(
      type: AchievementType.wallBreaker,
      name: 'Breakthrough',
      description:
          'Flatten an enemy wall on the winning road move in 5 games against Medium+ AI or independent online opponents.',
      track: AchievementTrack.craft,
      tier: AchievementTier.gold,
      requirements: [
        AchievementRequirement('crushingWins', 5, 'winning wall crushes')
      ]),
  GameAchievement(
      type: AchievementType.masterSpreader,
      name: 'Master Spreader',
      description:
          'Win a road with a spread across at least 3 cells in 5 games against Medium+ AI or independent online opponents.',
      track: AchievementTrack.craft,
      tier: AchievementTier.gold,
      requirements: [
        AchievementRequirement('spreadWins', 5, 'winning long spreads')
      ]),
  GameAchievement(
      type: AchievementType.precision,
      name: 'Clear Mind',
      description:
          'Solve 3 Square and 3 Hex tactical studies without opening a hint during that visit. Replaying a solved study can earn its unaided mark.',
      track: AchievementTrack.learning,
      tier: AchievementTier.gold,
      requirements: [
        AchievementRequirement('cleanSquare', 3, 'unaided Square studies'),
        AchievementRequirement('cleanHex', 3, 'unaided Hex studies')
      ]),
  GameAchievement(
      type: AchievementType.squareScholar,
      name: 'Square Scholar',
      description:
          'Solve every Square tactical study, including multiplayer positions.',
      track: AchievementTrack.learning,
      tier: AchievementTier.gold,
      requirements: [
        AchievementRequirement('squarePuzzles', 0, 'Square studies')
      ]),
  GameAchievement(
      type: AchievementType.hexScholar,
      name: 'Hex Scholar',
      description:
          'Solve every Hex tactical study, including multiplayer positions.',
      track: AchievementTrack.learning,
      tier: AchievementTier.gold,
      requirements: [AchievementRequirement('hexPuzzles', 0, 'Hex studies')]),
  GameAchievement(
      type: AchievementType.winningStreak,
      name: 'Unbroken',
      description:
          'Win 5 consecutive standard Square duels against Hard+ AI on 5×5 or larger. A loss or draw in an eligible duel resets the streak.',
      track: AchievementTrack.mastery,
      tier: AchievementTier.platinum,
      requirements: [
        AchievementRequirement('bestHardStreak', 5, 'consecutive Hard+ wins')
      ]),
  GameAchievement(
      type: AchievementType.seasoned,
      name: 'Seasoned Rival',
      description:
          'Win 25 online games against at least 10 different human opponents.',
      track: AchievementTrack.competition,
      tier: AchievementTier.platinum,
      requirements: [
        AchievementRequirement('onlineWins', 25, 'online wins'),
        AchievementRequirement('opponents', 10, 'human opponents')
      ]),
];

import 'dart:math';
import '../game/skill_rating.dart';

/// Public competition record; version 3 includes an estimate and uncertainty.
class EloRating {
  final String id;
  final String displayName;
  final int rating;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;
  final bool isAi;
  final String? aiDifficulty;
  final DateTime? lastUpdated;
  final String pool;
  final String? engineVersion;
  final int opponents;
  final SkillEstimate? skill;
  bool get provisional =>
      gamesPlayed < 10 || (skill != null && skill!.deviation > 150);
  String? get uncertaintyLabel => skill == null || gamesPlayed == 0
      ? null
      : 'Estimated skill range ${skill!.lower}–${skill!.upper} (95%)';
  String get confidenceLabel => skill == null
      ? ''
      : skill!.deviation > 150
          ? 'Strength still uncertain'
          : skill!.deviation > 80
              ? 'Confidence improving'
              : 'Well established';
  bool get calibrated => !provisional;
  String get ratingLabel =>
      gamesPlayed == 0 ? 'Unrated' : '$rating${provisional ? "?" : ""}';

  const EloRating({
    required this.id,
    required this.displayName,
    this.rating = 1200,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.isAi = false,
    this.aiDifficulty,
    this.lastUpdated,
    this.pool = 'square-5-2-standardTak-open',
    this.engineVersion,
    this.opponents = 0,
    this.skill,
  });

  EloRating copyWith({
    String? displayName,
    int? rating,
    int? gamesPlayed,
    int? wins,
    int? losses,
    int? draws,
    DateTime? lastUpdated,
    SkillEstimate? skill,
  }) {
    return EloRating(
      id: id,
      displayName: displayName ?? this.displayName,
      rating: rating ?? this.rating,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      isAi: isAi,
      aiDifficulty: aiDifficulty,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      pool: pool,
      engineVersion: engineVersion,
      opponents: opponents,
      skill: skill ?? this.skill,
    );
  }

  Map<String, dynamic> toMap() => {
        if (skill != null) ...skill!.toMap(),
        'pool': pool,
        'opponents': opponents,
        if (engineVersion != null) 'engineVersion': engineVersion,
        if (lastUpdated != null)
          'lastUpdated': lastUpdated!.millisecondsSinceEpoch,
        'displayName': displayName,
        'rating': rating,
        'gamesPlayed': gamesPlayed,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'isAi': isAi,
        if (aiDifficulty != null) 'aiDifficulty': aiDifficulty,
      };

  factory EloRating.fromMap(String id, Map<String, dynamic> map) {
    return EloRating(
      id: id,
      displayName: map['displayName'] as String? ?? 'Unknown',
      rating: (map['rating'] as num?)?.toInt() ?? 1200,
      gamesPlayed: (map['gamesPlayed'] as num?)?.toInt() ?? 0,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      draws: (map['draws'] as num?)?.toInt() ?? 0,
      isAi: map['isAi'] as bool? ?? false,
      aiDifficulty: map['aiDifficulty'] as String?,
      skill: map.containsKey('deviation') ? SkillEstimate.fromMap(map) : null,
      pool: map['pool'] as String? ?? 'square-5-2-standardTak-open',
      engineVersion: map['engineVersion'] as String?,
      opponents: (map['opponents'] as num?)?.toInt() ?? 0,
      lastUpdated: map['lastUpdated'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'] as int)
          : null,
    );
  }
}

/// A single point in a player's rating history
class EloHistoryEntry {
  final int rating;
  final DateTime timestamp;
  final String? opponentName;
  final double? score;
  final int? before, delta;
  final List<int> placements;
  final int seat, appearances;
  final String? aiEngine;
  final SkillEstimate? skill;

  const EloHistoryEntry({
    required this.rating,
    required this.timestamp,
    this.opponentName,
    this.score,
    this.before,
    this.delta,
    this.placements = const [],
    this.seat = 0,
    this.appearances = 1,
    this.aiEngine,
    this.skill,
  });

  Map<String, dynamic> toMap() => {
        if (skill != null) ...skill!.toMap(),
        'rating': rating,
        'timestamp': timestamp.millisecondsSinceEpoch,
        if (opponentName != null) 'opponentName': opponentName,
        if (score != null) 'score': score,
        if (before != null) 'before': before,
        if (delta != null) 'delta': delta,
        if (placements.isNotEmpty) 'placements': placements,
        if (placements.isNotEmpty) 'seat': seat,
        if (placements.isNotEmpty) 'appearances': appearances,
        if (aiEngine != null) 'aiEngine': aiEngine,
      };

  factory EloHistoryEntry.fromMap(Map<String, dynamic> map) {
    return EloHistoryEntry(
      rating: (map['rating'] as num?)?.toInt() ?? 1200,
      timestamp: map['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      opponentName: map['opponentName'] as String?,
      aiEngine: map['aiEngine'] as String?,
      score: (map['score'] as num?)?.toDouble(),
      before: map['before'] as int?,
      delta: map['delta'] as int?,
      placements: (map['placements'] as List?)?.cast<int>() ?? const [],
      seat: map['seat'] as int? ?? 0,
      appearances: map['appearances'] as int? ?? 1,
      skill: map.containsKey('deviation') ? SkillEstimate.fromMap(map) : null,
    );
  }
}

/// Standard ELO rating calculation
class EloCalculator {
  const EloCalculator();

  /// Default starting rating for new human players
  static const int defaultRating = 1200;

  /// K-factor determines how much ratings change per game.
  /// Higher K = more volatile ratings.
  static int kFactor(int gamesPlayed) {
    if (gamesPlayed < 30) return 40;
    return 20;
  }

  /// Calculate expected score for player A against player B.
  /// Returns value between 0 and 1.
  static double expectedScore(int ratingA, int ratingB) {
    return 1.0 / (1.0 + pow(10, (ratingB - ratingA) / 400.0));
  }

  /// Calculate new ratings after a game.
  /// [actualScoreA] is 1.0 for win, 0.5 for draw, 0.0 for loss.
  /// Returns (newRatingA, newRatingB).
  static (int, int) calculateNewRatings({
    required int ratingA,
    required int ratingB,
    required int gamesPlayedA,
    required int gamesPlayedB,
    required double actualScoreA,
  }) {
    if (![0.0, 0.5, 1.0].contains(actualScoreA) ||
        gamesPlayedA < 0 ||
        gamesPlayedB < 0) {
      throw ArgumentError('Invalid score or game count');
    }
    final expectedA = expectedScore(ratingA, ratingB);
    final expectedB = 1.0 - expectedA;
    final actualScoreB = 1.0 - actualScoreA;

    final kA = kFactor(gamesPlayedA);
    final kB = kFactor(gamesPlayedB);

    final newRatingA = (ratingA + kA * (actualScoreA - expectedA)).round();
    final newRatingB = (ratingB + kB * (actualScoreB - expectedB)).round();

    // Ensure ratings don't go below 100
    return (max(100, newRatingA), max(100, newRatingB));
  }
}

/// Human competition rank excludes AI and provisional players; ties share rank.
int competitionRank(int rating, Iterable<EloRating> players) =>
    1 +
    players.where((p) => !p.isAi && !p.provisional && p.rating > rating).length;

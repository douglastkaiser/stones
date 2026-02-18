import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../models/elo_rating.dart';
import '../services/ai/ai.dart';

void _debugLog(String message) {
  if (kDebugMode) {
    developer.log('[ELO] $message', name: 'elo');
  }
  if (kIsWeb) {
    // ignore: avoid_print
    print('[ELO] $message');
  }
}

/// State for ELO ratings
class EloState {
  final EloRating? localPlayerRating;
  final Map<String, EloRating> aiRatings;
  final List<EloRating> leaderboard;
  final bool loading;
  final String? errorMessage;

  const EloState({
    this.localPlayerRating,
    this.aiRatings = const {},
    this.leaderboard = const [],
    this.loading = false,
    this.errorMessage,
  });

  EloState copyWith({
    EloRating? localPlayerRating,
    Map<String, EloRating>? aiRatings,
    List<EloRating>? leaderboard,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EloState(
      localPlayerRating: localPlayerRating ?? this.localPlayerRating,
      aiRatings: aiRatings ?? this.aiRatings,
      leaderboard: leaderboard ?? this.leaderboard,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Get AI rating for a difficulty level
  int aiRatingFor(AIDifficulty difficulty) {
    final key = 'ai_${difficulty.name}';
    return aiRatings[key]?.rating ??
        EloCalculator.aiDefaultRatings[difficulty.name] ??
        1200;
  }
}

/// Controller for ELO ratings with Firebase persistence
class EloController extends StateNotifier<EloState> {
  EloController() : super(const EloState());

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _aiRatingsSubscription;
  bool _initialized = false;

  /// Initialize: load cached rating, then sync with Firebase
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    state = state.copyWith(loading: true);

    // Load cached local rating from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRating = prefs.getInt('elo_rating');
      final cachedDisplayName = prefs.getString('elo_displayName');
      if (cachedRating != null) {
        state = state.copyWith(
          localPlayerRating: EloRating(
            id: 'local',
            displayName: cachedDisplayName ?? 'You',
            rating: cachedRating,
            gamesPlayed: prefs.getInt('elo_gamesPlayed') ?? 0,
            wins: prefs.getInt('elo_wins') ?? 0,
            losses: prefs.getInt('elo_losses') ?? 0,
            draws: prefs.getInt('elo_draws') ?? 0,
          ),
        );
      }
    } catch (e) {
      _debugLog('Error loading cached rating: $e');
    }

    // Try to sync with Firebase
    try {
      await _ensureFirebase();
      await _ensureAiRatingsExist();
      await _syncLocalRating();
      _listenToAiRatings();
    } catch (e) {
      _debugLog('Error syncing with Firebase: $e');
    }

    state = state.copyWith(loading: false);
  }

  Future<void> _ensureFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      if (!e.toString().contains('already been initialized') &&
          !e.toString().contains('duplicate-app')) {
        rethrow;
      }
    }
  }

  /// Sync local player rating from Firebase
  Future<void> _syncLocalRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('ratings').doc(user.uid).get();
    if (doc.exists && doc.data() != null) {
      final rating = EloRating.fromMap(user.uid, doc.data()!);
      state = state.copyWith(localPlayerRating: rating);
      await _cacheLocalRating(rating);
    }
  }

  /// Listen to AI ratings in real-time so all users see updates
  void _listenToAiRatings() {
    _aiRatingsSubscription?.cancel();
    _aiRatingsSubscription = _firestore
        .collection('ratings')
        .where('isAi', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      final aiRatings = <String, EloRating>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        aiRatings[doc.id] = EloRating.fromMap(doc.id, data);
      }
      state = state.copyWith(aiRatings: aiRatings);
      _debugLog('AI ratings updated: ${aiRatings.map((k, v) => MapEntry(k, v.rating))}');
    }, onError: (e) {
      _debugLog('Error listening to AI ratings: $e');
    });
  }

  /// Ensure AI rating documents exist in Firebase
  Future<void> _ensureAiRatingsExist() async {
    for (final difficulty in AIDifficulty.values) {
      final docId = 'ai_${difficulty.name}';
      final doc = await _firestore.collection('ratings').doc(docId).get();
      if (!doc.exists) {
        final defaultRating = EloCalculator.aiDefaultRatings[difficulty.name] ?? 1200;
        final displayName = '${difficulty.name[0].toUpperCase()}${difficulty.name.substring(1)} AI';
        await _firestore.collection('ratings').doc(docId).set(
          EloRating(
            id: docId,
            displayName: displayName,
            rating: defaultRating,
            isAi: true,
            aiDifficulty: difficulty.name,
          ).toMap(),
        );
        _debugLog('Created AI rating doc: $docId with rating $defaultRating');
      }
    }
  }

  /// Ensure local player rating document exists in Firebase
  Future<EloRating> _ensurePlayerRating(String userId, String displayName) async {
    final doc = await _firestore.collection('ratings').doc(userId).get();
    if (doc.exists && doc.data() != null) {
      final rating = EloRating.fromMap(userId, doc.data()!);
      // Update display name if it changed
      if (rating.displayName != displayName) {
        await _firestore.collection('ratings').doc(userId).update({
          'displayName': displayName,
        });
        return rating.copyWith(displayName: displayName);
      }
      return rating;
    }

    // Create new rating document
    final newRating = EloRating(
      id: userId,
      displayName: displayName,
      lastUpdated: DateTime.now(),
    );
    await _firestore.collection('ratings').doc(userId).set(newRating.toMap());
    _debugLog('Created player rating doc: $userId');
    return newRating;
  }

  /// Record a game result and update ELO for both players
  /// [winnerId] is null for draws
  /// For vs computer games: playerA is human, playerB is AI doc id (e.g. "ai_hard")
  /// For online games: playerA is local user, playerB is opponent
  Future<void> recordGameResult({
    required String playerAId,
    required String playerAName,
    required String playerBId,
    required String playerBName,
    required double scoreA,
    required bool playerBIsAi,
  }) async {
    try {
      await _ensureFirebase();
      await _ensureAiRatingsExist();

      // Fetch current ratings
      final ratingA = await _ensurePlayerRating(playerAId, playerAName);
      EloRating ratingB;
      if (playerBIsAi) {
        final doc = await _firestore.collection('ratings').doc(playerBId).get();
        if (doc.exists && doc.data() != null) {
          ratingB = EloRating.fromMap(playerBId, doc.data()!);
        } else {
          // AI doc should exist from _ensureAiRatingsExist, but handle edge case
          final difficulty = playerBId.replaceFirst('ai_', '');
          ratingB = EloRating(
            id: playerBId,
            displayName: '${difficulty[0].toUpperCase()}${difficulty.substring(1)} AI',
            rating: EloCalculator.aiDefaultRatings[difficulty] ?? 1200,
            isAi: true,
            aiDifficulty: difficulty,
          );
        }
      } else {
        ratingB = await _ensurePlayerRating(playerBId, playerBName);
      }

      // Calculate new ratings
      final (newRatingA, newRatingB) = EloCalculator.calculateNewRatings(
        ratingA: ratingA.rating,
        ratingB: ratingB.rating,
        gamesPlayedA: ratingA.gamesPlayed,
        gamesPlayedB: ratingB.gamesPlayed,
        actualScoreA: scoreA,
      );

      _debugLog('Rating update: ${ratingA.displayName} ${ratingA.rating}->$newRatingA, '
          '${ratingB.displayName} ${ratingB.rating}->$newRatingB (scoreA=$scoreA)');

      // Determine win/loss/draw increments
      final aWin = scoreA == 1.0 ? 1 : 0;
      final aLoss = scoreA == 0.0 ? 1 : 0;
      final aDraw = scoreA == 0.5 ? 1 : 0;

      // Update both ratings atomically using a batch
      final batch = _firestore.batch();

      batch.set(
        _firestore.collection('ratings').doc(playerAId),
        {
          'displayName': playerAName,
          'rating': newRatingA,
          'gamesPlayed': FieldValue.increment(1),
          'wins': FieldValue.increment(aWin),
          'losses': FieldValue.increment(aLoss),
          'draws': FieldValue.increment(aDraw),
          'isAi': false,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        _firestore.collection('ratings').doc(playerBId),
        {
          'displayName': playerBName,
          'rating': newRatingB,
          'gamesPlayed': FieldValue.increment(1),
          'wins': FieldValue.increment(aLoss), // B wins when A loses
          'losses': FieldValue.increment(aWin), // B loses when A wins
          'draws': FieldValue.increment(aDraw),
          'isAi': playerBIsAi,
          if (playerBIsAi) 'aiDifficulty': playerBId.replaceFirst('ai_', ''),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      // Record history entries for both players
      final now = DateTime.now();
      await _recordHistoryEntry(
        playerAId,
        EloHistoryEntry(
          rating: newRatingA,
          timestamp: now,
          opponentName: playerBName,
          score: scoreA,
        ),
      );
      await _recordHistoryEntry(
        playerBId,
        EloHistoryEntry(
          rating: newRatingB,
          timestamp: now,
          opponentName: playerAName,
          score: 1.0 - scoreA,
        ),
      );

      // Update local state
      final updatedLocalRating = ratingA.copyWith(
        displayName: playerAName,
        rating: newRatingA,
        gamesPlayed: ratingA.gamesPlayed + 1,
        wins: ratingA.wins + aWin,
        losses: ratingA.losses + aLoss,
        draws: ratingA.draws + aDraw,
        lastUpdated: DateTime.now(),
      );
      state = state.copyWith(localPlayerRating: updatedLocalRating);
      await _cacheLocalRating(updatedLocalRating);
    } catch (e) {
      _debugLog('Error recording game result: $e');
    }
  }

  /// Fetch leaderboard (top players + AI, ordered by rating)
  Future<void> fetchLeaderboard() async {
    state = state.copyWith(loading: true);
    try {
      await _ensureFirebase();
      await _ensureAiRatingsExist();

      final snapshot = await _firestore
          .collection('ratings')
          .orderBy('rating', descending: true)
          .limit(50)
          .get();

      final leaderboard = snapshot.docs
          .map((doc) => EloRating.fromMap(doc.id, doc.data()))
          .toList();

      state = state.copyWith(leaderboard: leaderboard, loading: false);
    } catch (e) {
      _debugLog('Error fetching leaderboard: $e');
      state = state.copyWith(loading: false, errorMessage: 'Failed to load leaderboard');
    }
  }

  /// Get a specific player's rating from Firebase
  Future<int?> getPlayerRating(String userId) async {
    try {
      await _ensureFirebase();
      final doc = await _firestore.collection('ratings').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data()!['rating'] as num?)?.toInt();
      }
    } catch (e) {
      _debugLog('Error fetching player rating: $e');
    }
    return null;
  }

  /// Record a history entry for a player's rating over time
  Future<void> _recordHistoryEntry(String playerId, EloHistoryEntry entry) async {
    try {
      await _firestore
          .collection('ratings')
          .doc(playerId)
          .collection('history')
          .add(entry.toMap());
    } catch (e) {
      _debugLog('Error recording history for $playerId: $e');
    }
  }

  /// Fetch rating history for a player, ordered by time
  Future<List<EloHistoryEntry>> fetchRatingHistory(String playerId) async {
    try {
      await _ensureFirebase();
      final snapshot = await _firestore
          .collection('ratings')
          .doc(playerId)
          .collection('history')
          .orderBy('timestamp')
          .limit(200)
          .get();

      return snapshot.docs
          .map((doc) => EloHistoryEntry.fromMap(doc.data()))
          .toList();
    } catch (e) {
      _debugLog('Error fetching rating history for $playerId: $e');
      return [];
    }
  }

  /// Cache local rating to SharedPreferences for offline access
  Future<void> _cacheLocalRating(EloRating rating) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('elo_rating', rating.rating);
      await prefs.setString('elo_displayName', rating.displayName);
      await prefs.setInt('elo_gamesPlayed', rating.gamesPlayed);
      await prefs.setInt('elo_wins', rating.wins);
      await prefs.setInt('elo_losses', rating.losses);
      await prefs.setInt('elo_draws', rating.draws);
    } catch (e) {
      _debugLog('Error caching local rating: $e');
    }
  }

  @override
  void dispose() {
    _aiRatingsSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for ELO state
final eloProvider = StateNotifierProvider<EloController, EloState>((ref) {
  return EloController();
});

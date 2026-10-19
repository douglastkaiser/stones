import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/rating_pool.dart';
import '../game/match_config.dart';
import '../game/rating_evidence.dart';
import '../models/elo_rating.dart';
import '../services/rating_repository.dart';
import 'account_provider.dart';

class EloState {
  const EloState(
      {this.localPlayerRating,
      this.aiRatings = const {},
      this.leaderboard = const [],
      this.loading = false,
      this.errorMessage,
      this.pool,
      this.uid,
      this.rank});
  final EloRating? localPlayerRating;
  final Map<String, EloRating> aiRatings;
  final List<EloRating> leaderboard;
  final bool loading;
  final String? errorMessage;
  final RatingPool? pool;
  final String? uid;
  final int? rank;
  RatingPool get selectedPool => pool ?? const RatingPool.overall();
  String get personalLabel =>
      localPlayerRating?.ratingLabel ??
      (errorMessage == null ? 'Unrated' : 'Rating unavailable');
}

/// Reads account-scoped results. The repository settles confirmed matches;
/// database rules independently validate every participant's rating update.
class EloController extends StateNotifier<EloState> {
  EloController(this.repository,
      {this.bootstrap, this.requestTimeout = const Duration(seconds: 8)})
      : super(const EloState());
  final RatingRepository repository;
  final Future<void> Function()? bootstrap;
  final Duration requestTimeout;
  StreamSubscription<EloRating?>? _subscription;
  StreamSubscription<List<EloRating>>? _leaderSubscription;
  bool _live = false;
  int _generation = 0;
  int _request = 0;
  int _rankRequest = 0;
  String? _uid;
  bool _guest = true;
  Future<void> initialize({bool syncOnline = true}) async {
    if (syncOnline) await bootstrap?.call();
  }

  void bind(String? uid, {required bool guest}) {
    if (uid == _uid && guest == _guest) return;
    _uid = uid;
    _guest = guest;
    selectPool(state.selectedPool);
  }

  void selectPool(RatingPool pool) {
    final generation = ++_generation;
    _request++;
    unawaited(_subscription?.cancel());
    state = EloState(pool: pool, uid: _guest ? null : _uid);
    _watchLive();
    if (_uid == null || _guest) return;
    final uid = _uid!;
    try {
      _subscription =
          repository.watchPlayer(pool.id, uid).listen((rating) async {
        if (!mounted || generation != _generation) return;
        state = EloState(
            pool: pool,
            uid: uid,
            localPlayerRating: rating,
            leaderboard: state.leaderboard,
            aiRatings: state.aiRatings,
            loading: state.loading);
        if (rating == null || rating.provisional) return;
        final rankRequest = ++_rankRequest;
        try {
          final rank = await repository
              .rank(pool.id, rating.rating)
              .timeout(requestTimeout);
          if (mounted &&
              generation == _generation &&
              rankRequest == _rankRequest &&
              identical(state.localPlayerRating, rating)) {
            state = EloState(
                pool: pool,
                uid: uid,
                localPlayerRating: rating,
                leaderboard: state.leaderboard,
                aiRatings: state.aiRatings,
                loading: state.loading,
                errorMessage: state.errorMessage,
                rank: rank);
          }
        } catch (_) {
          if (mounted &&
              generation == _generation &&
              rankRequest == _rankRequest) {
            _error('Your rank could not be refreshed. Try again.');
          }
        }
      }, onError: (Object error) {
        if (mounted && generation == _generation) {
          _error(
              'Ratings could not be loaded. Check your connection and retry.');
        }
      });
    } catch (_) {
      _error('Ratings could not be loaded. Check your connection and retry.');
    }
  }

  void startLive() {
    _live = true;
    _watchLive();
  }

  void stopLive() {
    _live = false;
    unawaited(_leaderSubscription?.cancel());
    _leaderSubscription = null;
  }

  void _watchLive() {
    unawaited(_leaderSubscription?.cancel());
    final repo = repository;
    if (!_live || repo is! LiveRatingRepository) return;
    final generation = _generation;
    final pool = state.selectedPool;
    final Stream<List<EloRating>> stream;
    try {
      stream = (repo as LiveRatingRepository).watchLeaders(pool.id);
    } catch (_) {
      _error('Live standings unavailable. Retry when connected.');
      return;
    }
    _leaderSubscription = stream.listen((values) async {
      if (!mounted || generation != _generation || !_live) return;
      _request++;
      final entries = {for (final player in values) player.id: player};
      for (final level in BotLevel.values) {
        final id = 'ai_${RatingEvidence.engine}_${level.name}';
        entries.putIfAbsent(
            id,
            () => EloRating(
                id: id,
                displayName:
                    '${level.name[0].toUpperCase()}${level.name.substring(1)} AI',
                isAi: true,
                aiDifficulty: level.name,
                pool: pool.id));
      }
      final leaders = entries.values.toList()
        ..sort((a, b) {
          final order = b.rating.compareTo(a.rating);
          return order == 0 ? a.id.compareTo(b.id) : order;
        });
      state = EloState(
          pool: pool,
          uid: state.uid,
          localPlayerRating: state.localPlayerRating,
          leaderboard: leaders,
          aiRatings: {for (final p in values.where((p) => p.isAi)) p.id: p},
          rank: state.rank);
      final personal = state.localPlayerRating;
      if (personal == null || personal.provisional) return;
      final rankRequest = ++_rankRequest;
      try {
        final rank = await repository
            .rank(pool.id, personal.rating)
            .timeout(requestTimeout);
        if (mounted &&
            generation == _generation &&
            rankRequest == _rankRequest &&
            _live &&
            identical(state.localPlayerRating, personal)) {
          state = EloState(
              pool: pool,
              uid: state.uid,
              localPlayerRating: personal,
              leaderboard: state.leaderboard,
              aiRatings: state.aiRatings,
              rank: rank,
              errorMessage: state.errorMessage);
        }
      } catch (_) {
        if (mounted &&
            generation == _generation &&
            rankRequest == _rankRequest &&
            _live) {
          _error('Your rank could not be refreshed. Try again.');
        }
      }
    }, onError: (Object error) {
      if (mounted && generation == _generation && _live) {
        _error('Live standings unavailable. Retry when connected.');
      }
    });
  }

  void _error(String message) {
    state = EloState(
        pool: state.selectedPool,
        uid: state.uid,
        localPlayerRating: state.localPlayerRating,
        leaderboard: state.leaderboard,
        aiRatings: state.aiRatings,
        rank: state.rank,
        errorMessage: message);
  }

  Future<void> fetchLeaderboard() async {
    try {
      await initialize().timeout(requestTimeout);
    } catch (_) {
      if (mounted) {
        _error('Ratings could not be initialized. Retry when connected.');
      }
      return;
    }
    if (!mounted) return;
    if (state.errorMessage != null) selectPool(state.selectedPool);
    final generation = _generation;
    final request = ++_request;
    final pool = state.selectedPool;
    state = EloState(
        pool: pool,
        uid: state.uid,
        localPlayerRating: state.localPlayerRating,
        aiRatings: state.aiRatings,
        leaderboard: state.leaderboard,
        rank: state.rank,
        loading: true);
    try {
      final values = await Future.wait(
              [repository.leaders(pool.id), repository.bots(pool.id)])
          .timeout(requestTimeout);
      if (!mounted || generation != _generation || request != _request) return;
      final combined = {
        for (final entry in [...values[0], ...values[1]]) entry.id: entry
      };
      for (final level in BotLevel.values) {
        final id = 'ai_${RatingEvidence.engine}_${level.name}';
        combined.putIfAbsent(
            id,
            () => EloRating(
                id: id,
                displayName:
                    '${level.name[0].toUpperCase()}${level.name.substring(1)} AI',
                pool: pool.id,
                isAi: true,
                aiDifficulty: level.name));
      }
      final leaders = combined.values.toList()
        ..sort((a, b) {
          final rating = b.rating.compareTo(a.rating);
          return rating == 0 ? a.id.compareTo(b.id) : rating;
        });
      final personal = state.localPlayerRating;
      final rankRequest = ++_rankRequest;
      final rank = personal != null && !personal.provisional
          ? await repository
              .rank(pool.id, personal.rating)
              .timeout(requestTimeout)
          : null;
      if (!mounted || generation != _generation || request != _request) return;
      state = EloState(
          pool: pool,
          uid: state.uid,
          localPlayerRating: state.localPlayerRating,
          leaderboard: leaders,
          aiRatings: {for (final bot in values[1]) bot.id: bot},
          rank: identical(state.localPlayerRating, personal) &&
                  rankRequest == _rankRequest
              ? rank
              : state.rank);
    } catch (_) {
      if (mounted && generation == _generation && request == _request) {
        _error(
            'Leaderboard unavailable. Your game progress is safe. Retry when connected.');
      }
    }
  }

  Future<List<EloHistoryEntry>> fetchRatingHistory(String playerId,
          {String? pool}) =>
      repository
          .history(pool ?? state.selectedPool.id, playerId)
          .timeout(requestTimeout);
  @override
  void dispose() {
    _generation++;
    unawaited(_subscription?.cancel());
    unawaited(_leaderSubscription?.cancel());
    super.dispose();
  }
}

final ratingRepositoryProvider =
    Provider<RatingRepository>((ref) => FirebaseRatingRepository());
final StateNotifierProvider<EloController, EloState> eloProvider =
    StateNotifierProvider<EloController, EloState>((ref) {
  final controller = EloController(ref.read(ratingRepositoryProvider),
      bootstrap: () => ref.read(accountProvider.notifier).initialize());
  ref.listen(accountProvider, (previous, next) {
    controller.bind(next.identity?.uid, guest: next.identity?.guest ?? true);
  }, fireImmediately: true);
  return controller;
});

final seatRatingProvider =
    StreamProvider.autoDispose.family<EloRating?, (String, String)>((ref, key) {
  final account = ref.watch(accountProvider);
  if (!account.ready) return Stream.value(null);
  return ref.watch(ratingRepositoryProvider).watchPlayer(key.$1, key.$2);
});

final playerRankProvider = FutureProvider.autoDispose
    .family<int, (String, int)>(
        (ref, key) => ref.watch(ratingRepositoryProvider).rank(key.$1, key.$2));

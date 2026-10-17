import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/rating_pool.dart';
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
  RatingPool get selectedPool => pool ?? RatingPool.standard;
}

/// No client can submit scores or edit another player's totals. The backend
/// observes confirmed rooms; this controller only reads account-scoped results.
class EloController extends StateNotifier<EloState> {
  EloController(this.repository, {this.bootstrap}) : super(const EloState());
  final RatingRepository repository;
  final Future<void> Function()? bootstrap;
  StreamSubscription<EloRating?>? _subscription;
  int _generation = 0;
  int _request = 0;
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
        try {
          final rank = await repository.rank(pool.id, rating.rating);
          if (mounted &&
              generation == _generation &&
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
          if (mounted && generation == _generation) {
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
    await initialize();
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
          [repository.leaders(pool.id), repository.bots(pool.id)]);
      if (!mounted || generation != _generation || request != _request) return;
      final leaders = values[0]
        ..sort((a, b) {
          final score = b.rating.compareTo(a.rating);
          return score == 0 ? a.id.compareTo(b.id) : score;
        });
      state = EloState(
          pool: pool,
          uid: state.uid,
          localPlayerRating: state.localPlayerRating,
          leaderboard: leaders,
          aiRatings: {for (final bot in values[1]) bot.id: bot},
          rank: state.rank);
    } catch (_) {
      if (mounted && generation == _generation && request == _request) {
        _error(
            'Leaderboard unavailable. Your game progress is safe. Retry when connected.');
      }
    }
  }

  Future<List<EloHistoryEntry>> fetchRatingHistory(String playerId,
          {String? pool}) =>
      repository.history(pool ?? state.selectedPool.id, playerId);
  @override
  void dispose() {
    _generation++;
    unawaited(_subscription?.cancel());
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

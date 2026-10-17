import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/elo_rating.dart';
import '../game/match_config.dart';
import '../game/match_state.dart';

abstract class RatingRepository {
  Stream<EloRating?> watchPlayer(String pool, String uid);
  Future<List<EloRating>> leaders(String pool);
  Future<List<EloRating>> bots(String pool);
  Future<int> rank(String pool, int rating);
  Future<List<EloHistoryEntry>> history(String pool, String uid);
  Future<MatchMove?> botMove(String id, MatchConfig config, List<Map<String, dynamic>> moves);
  Future<String> completeCalibration(String id, MatchConfig config, List<Map<String, dynamic>> moves);
}

class FirebaseRatingRepository implements RatingRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _players(String pool) =>
      _db.collection('ratingPools').doc(pool).collection('players');
  @override
  Stream<EloRating?> watchPlayer(String pool, String uid) => _players(pool).doc(uid).snapshots().map(
      (doc) => doc.exists ? EloRating.fromMap(doc.id, doc.data()!) : null);
  @override
  Future<List<EloRating>> leaders(String pool) async {
    final result = await _db.collection('ratingPools').doc(pool).collection('standings')
        .orderBy('rating', descending: true).limit(50).get(const GetOptions(source: Source.server));
    return result.docs.map((doc) => EloRating.fromMap(doc.id, doc.data())).toList();
  }
  @override
  Future<List<EloRating>> bots(String pool) async {
    final result = await _players(pool).where('isAi', isEqualTo: true)
        .get(const GetOptions(source: Source.server));
    return result.docs.where((doc) => doc.data()['engineVersion'] == 'shared-search-v1')
        .map((doc) => EloRating.fromMap(doc.id, doc.data())).toList();
  }
  @override
  Future<int> rank(String pool, int rating) async {
    final result = await _db.collection('ratingPools').doc(pool).collection('standings')
        .where('rating', isGreaterThan: rating).count().get();
    return 1 + (result.count ?? 0);
  }
  @override
  Future<List<EloHistoryEntry>> history(String pool, String uid) async {
    final result = await _players(pool).doc(uid).collection('history')
        .orderBy('timestamp', descending: true).limit(100)
        .get(const GetOptions(source: Source.server));
    return result.docs.map((doc) => EloHistoryEntry.fromMap(doc.data())).toList().reversed.toList();
  }
  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> payload) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) { throw StateError('Sign in with Google to use ratings.'); }
    final token = await user.getIdToken();
    final response = await http.post(Uri.https('us-central1-stones-9a6a0.cloudfunctions.net', '/$name'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'data': payload})).timeout(const Duration(seconds: 5));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['error'] != null) {
      throw StateError('Rating service unavailable. This game remains playable as practice.');
    }
    return Map<String, dynamic>.from(data['result'] as Map);
  }
  @override
  Future<MatchMove?> botMove(String id, MatchConfig config, List<Map<String, dynamic>> moves) async {
    final response = await _call('ratingBotMove', {'id': id, 'config': config.toMap(), 'moves': moves});
    return response['move'] == null ? null : MatchMove.fromMap(Map<String, dynamic>.from(response['move']));
  }
  @override
  Future<String> completeCalibration(String id, MatchConfig config, List<Map<String, dynamic>> moves) async {
    final response = await _call('completeCalibration', {'id': id, 'config': config.toMap(), 'moves': moves});
    return response['status'] == 'recorded' ? 'AI calibration recorded' : response['reason'] as String? ?? 'Practice game';
  }
}

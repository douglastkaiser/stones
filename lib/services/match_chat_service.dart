import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

String filterChatText(String text) => text.replaceAllMapped(
    RegExp(
        r'fuck|shit|bitch|ass|damn|hell|crap|piss|dick|cock|pussy|cunt|bastard|slut|whore|sex|porn|nigg|fag|retard',
        caseSensitive: false),
    (match) => '*' * match.group(0)!.length);

class ChatMessage {
  const ChatMessage(
      this.id, this.sender, this.text, this.createdAt, this.expiresAt);
  final String id, sender, text;
  final DateTime createdAt, expiresAt;
}

/// REST delivery deliberately avoids Firestore's persistent native document cache.
/// The only persisted data is a list of document IDs and expiry times for cleanup.
class MatchChatService {
  MatchChatService(this.room, this.uid, {http.Client? client})
      : _client = client ?? http.Client();
  final String room, uid;
  final http.Client _client;
  final DateTime joinedAt = DateTime.now().toUtc();
  String get _cleanupKey => 'chat_cleanup_ids_v1:$uid';
  static Future<void> _cleanupWrites = Future.value();
  String get _base {
    final project = Firebase.app().options.projectId;
    // The repository's integration entry point uses this isolated demo project.
    final origin = project == 'demo-stones-hex'
        ? 'http://127.0.0.1:8088'
        : 'https://firestore.googleapis.com';
    return '$origin/v1/projects/$project/databases/(default)/documents';
  }

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.uid != uid) throw StateError('Sign in again to use chat.');
    return {
      'Authorization': 'Bearer ${await user!.getIdToken()}',
      'Content-Type': 'application/json'
    };
  }

  Future<void> _remember(String path, DateTime expiry) {
    final write = _cleanupWrites.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final entries = prefs.getStringList(_cleanupKey) ?? [];
      final value = '$path|${expiry.millisecondsSinceEpoch}';
      if (!entries.contains(value)) {
        await prefs.setStringList(_cleanupKey, [...entries, value]);
      }
    });
    _cleanupWrites = write.catchError((Object _) {});
    return write;
  }

  Future<void> cleanup({bool finished = false}) async {
    final write = _cleanupWrites.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_cleanupKey) ?? [];
      final retained = <String>[];
      for (final entry in pending) {
        final parts = entry.split('|');
        if (parts.length != 2) continue;
        final expiry = int.tryParse(parts[1]);
        if (expiry == null) continue;
        if (expiry > DateTime.now().millisecondsSinceEpoch &&
            !(finished && parts[0].startsWith('matches/$room/chat/'))) {
          retained.add(entry);
          continue;
        }
        try {
          final response = await _client
              .delete(Uri.parse('$_base/${parts[0]}'),
                  headers: await _headers())
              .timeout(const Duration(seconds: 8));
          if (response.statusCode != 200 && response.statusCode != 404) {
            retained.add(entry);
          }
        } catch (_) {
          retained.add(entry);
        }
      }
      if (retained.length != pending.length) {
        await prefs.setStringList(_cleanupKey, retained);
      }
    });
    _cleanupWrites = write.catchError((Object _) {});
    return write;
  }

  Future<void> send(String raw) async {
    final text = filterChatText(raw.trim());
    if (text.isEmpty || text.runes.length > 500) {
      throw StateError('Use 1–500 characters.');
    }
    final id =
        List.generate(32, (_) => Random.secure().nextInt(16).toRadixString(16))
            .join();
    final path = 'matches/$room/chat/$id';
    final expiry = DateTime.now().toUtc().add(const Duration(minutes: 5));
    await _remember(path, expiry);
    final response = await _client
        .post(Uri.parse('$_base:commit'),
            headers: await _headers(),
            body: jsonEncode({
              'writes': [
                {
                  'update': {
                    'name':
                        'projects/${Firebase.app().options.projectId}/databases/(default)/documents/$path',
                    'fields': {
                      'sender': {'stringValue': uid},
                      'text': {'stringValue': text},
                      'expiresAt': {'timestampValue': expiry.toIso8601String()},
                    }
                  },
                  'currentDocument': {'exists': false},
                  'updateTransforms': [
                    {
                      'fieldPath': 'createdAt',
                      'setToServerValue': 'REQUEST_TIME'
                    }
                  ],
                }
              ]
            }))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Chat could not send. Check your connection and retry.');
    }
  }

  Future<List<ChatMessage>> receive() async {
    final response = await _client
        .post(Uri.parse('$_base/matches/$room:runQuery'),
            headers: await _headers(),
            body: jsonEncode({
              'structuredQuery': {
                'from': [
                  {'collectionId': 'chat'}
                ],
                'where': {
                  'compositeFilter': {
                    'op': 'AND',
                    'filters': [
                      {
                        'fieldFilter': {
                          'field': {'fieldPath': 'createdAt'},
                          'op': 'GREATER_THAN',
                          'value': {
                            'timestampValue': joinedAt.toIso8601String()
                          }
                        }
                      },
                      {
                        'fieldFilter': {
                          'field': {'fieldPath': 'expiresAt'},
                          'op': 'GREATER_THAN',
                          'value': {
                            'timestampValue': DateTime.now()
                                .toUtc()
                                .add(const Duration(seconds: 30))
                                .toIso8601String()
                          }
                        }
                      },
                    ]
                  }
                },
                'orderBy': [
                  {
                    'field': {'fieldPath': 'createdAt'},
                    'direction': 'DESCENDING'
                  },
                  {
                    'field': {'fieldPath': 'expiresAt'},
                    'direction': 'DESCENDING'
                  }
                ],
                'limit': 50,
              }
            }))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Chat unavailable. Check your connection and retry.');
    }
    final result = <ChatMessage>[];
    for (final row in jsonDecode(response.body) as List) {
      final doc = row['document'];
      if (doc == null) continue;
      final fields = doc['fields'];
      final path = (doc['name'] as String).split('/documents/').last;
      final expiry = DateTime.parse(fields['expiresAt']['timestampValue']);
      await _remember(path, expiry);
      result.add(ChatMessage(
          path.split('/').last,
          fields['sender']['stringValue'],
          filterChatText(fields['text']['stringValue']),
          DateTime.parse(fields['createdAt']['timestampValue']),
          expiry));
    }
    return result.reversed.toList();
  }

  void dispose() => _client.close();
}

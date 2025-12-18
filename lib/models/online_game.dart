import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';

/// Sanitize and validate display names to prevent security issues
String _sanitizeDisplayName(String name) {
  // Trim whitespace
  String sanitized = name.trim();

  // Limit length (max 30 characters to prevent UI issues and match Firestore rules)
  if (sanitized.length > 30) {
    sanitized = sanitized.substring(0, 30);
  }

  // Remove control characters and other problematic characters
  // Keep only printable ASCII and common Unicode characters
  sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

  // If empty after sanitization, use default
  if (sanitized.isEmpty) {
    return 'Player';
  }

  return sanitized;
}

enum OnlineStatus { waiting, playing, finished }

enum OnlineWinner { white, black, draw }

class OnlineGamePlayer {
  final String id;
  final String displayName;

  const OnlineGamePlayer({required this.id, required this.displayName});

  /// Sanitize display name for security (public API)
  static String sanitize(String name) => _sanitizeDisplayName(name);

  Map<String, dynamic> toMap() => {
        'id': id,
        'displayName': displayName,
      };

  factory OnlineGamePlayer.fromMap(Map<String, dynamic> map) {
    return OnlineGamePlayer(
      id: map['id'] as String? ?? '',
      displayName: _sanitizeDisplayName(map['displayName'] as String? ?? 'Player'),
    );
  }
}

class OnlineGameMove {
  final String notation;
  final PlayerColor player;
  final DateTime? timestamp;

  const OnlineGameMove({
    required this.notation,
    required this.player,
    this.timestamp,
  });

  /// Validate move notation format for security
  static bool isValidNotation(String notation) {
    // Limit length to prevent excessive strings
    if (notation.isEmpty || notation.length > 20) {
      return false;
    }

    // Valid notation patterns:
    // Placement: [S|C]?[a-z][0-9]+ (e.g., "a1", "Sa3", "Cb5")
    // Stack move: [0-9]?[a-z][0-9]+[<>+-][0-9]? (e.g., "a1>", "3b2<21", "c3+")
    final placementPattern = RegExp(r'^[SC]?[a-z]\d+$');
    final stackPattern = RegExp(r'^\d?[a-z]\d+[<>+\-]\d*$');

    return placementPattern.hasMatch(notation) || stackPattern.hasMatch(notation);
  }

  Map<String, dynamic> toMap() => {
        'notation': notation,
        'player': player.name,
        'timestamp': Timestamp.now(),
      };

  factory OnlineGameMove.fromMap(Map<String, dynamic> map) {
    final timestamp = map['timestamp'];
    final notation = map['notation'] as String? ?? '';

    // Validate notation format for security
    if (!isValidNotation(notation)) {
      throw FormatException('Invalid move notation: $notation');
    }

    return OnlineGameMove(
      notation: notation,
      player: _colorFromString(map['player'] as String?),
      timestamp: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class OnlineGameSession {
  final String roomCode;
  final OnlineGamePlayer white;
  final OnlineGamePlayer? black;
  final int boardSize;
  final List<OnlineGameMove> moves;
  final PlayerColor currentTurn;
  final OnlineStatus status;
  final OnlineWinner? winner;
  final DateTime? createdAt;
  final DateTime? lastMoveAt;
  final bool chessClockEnabled;
  final int chessClockSeconds;

  const OnlineGameSession({
    required this.roomCode,
    required this.white,
    this.black,
    this.boardSize = 5,
    this.moves = const [],
    this.currentTurn = PlayerColor.white,
    this.status = OnlineStatus.waiting,
    this.winner,
    this.createdAt,
    this.lastMoveAt,
    this.chessClockEnabled = false,
    this.chessClockSeconds = 300,
  });

  bool get hasOpponent => black != null;

  Map<String, dynamic> toMap() {
    return {
      'white': white.toMap(),
      'black': black?.toMap(),
      'boardSize': boardSize,
      'moves': moves.map((m) => m.toMap()).toList(),
      'currentTurn': currentTurn.name,
      'status': status.name,
      'winner': winner?.name,
      'chessClockEnabled': chessClockEnabled,
      'chessClockSeconds': chessClockSeconds,
    };
  }

  factory OnlineGameSession.fromSnapshot(String code, Map<String, dynamic> data) {
    // Helper to safely convert Firestore maps (which can be Map<Object?, Object?> on web)
    // to Map<String, dynamic>
    Map<String, dynamic> toStringDynamicMap(dynamic map) {
      if (map is Map<String, dynamic>) return map;
      if (map is Map) return Map<String, dynamic>.from(map);
      return <String, dynamic>{};
    }

    int defaultClockFor(int size) {
      switch (size) {
        case 3:
          return 60;
        case 4:
          return 120;
        case 5:
          return 300;
        case 6:
          return 600;
        case 7:
          return 900;
        case 8:
          return 1200;
        default:
          return 300;
      }
    }

    final boardSize = (data['boardSize'] as num?)?.toInt() ?? 5;

    return OnlineGameSession(
      roomCode: code,
      white: OnlineGamePlayer.fromMap(toStringDynamicMap(data['white'])),
      black: data['black'] == null
          ? null
          : OnlineGamePlayer.fromMap(toStringDynamicMap(data['black'])),
      boardSize: boardSize,
      moves: ((data['moves'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => OnlineGameMove.fromMap(toStringDynamicMap(m)))
          .toList(),
      currentTurn: _colorFromString(data['currentTurn'] as String?),
      status: _statusFromString(data['status'] as String?),
      winner: _winnerFromString(data['winner'] as String?),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      lastMoveAt: (data['lastMoveAt'] is Timestamp)
          ? (data['lastMoveAt'] as Timestamp).toDate()
          : null,
      chessClockEnabled: data['chessClockEnabled'] as bool? ?? false,
      chessClockSeconds: (data['chessClockSeconds'] as num?)?.toInt() ??
          defaultClockFor(boardSize),
    );
  }

  OnlineGameSession copyWith({
    OnlineGamePlayer? white,
    OnlineGamePlayer? black,
    int? boardSize,
    List<OnlineGameMove>? moves,
    PlayerColor? currentTurn,
    OnlineStatus? status,
    OnlineWinner? winner,
    DateTime? createdAt,
    DateTime? lastMoveAt,
    bool? chessClockEnabled,
    int? chessClockSeconds,
  }) {
    return OnlineGameSession(
      roomCode: roomCode,
      white: white ?? this.white,
      black: black ?? this.black,
      boardSize: boardSize ?? this.boardSize,
      moves: moves ?? this.moves,
      currentTurn: currentTurn ?? this.currentTurn,
      status: status ?? this.status,
      winner: winner ?? this.winner,
      createdAt: createdAt ?? this.createdAt,
      lastMoveAt: lastMoveAt ?? this.lastMoveAt,
      chessClockEnabled: chessClockEnabled ?? this.chessClockEnabled,
      chessClockSeconds: chessClockSeconds ?? this.chessClockSeconds,
    );
  }
}

PlayerColor _colorFromString(String? value) {
  return value == 'black' ? PlayerColor.black : PlayerColor.white;
}

OnlineStatus _statusFromString(String? value) {
  return OnlineStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => OnlineStatus.waiting,
  );
}

OnlineWinner? _winnerFromString(String? value) {
  if (value == null) return null;
  return OnlineWinner.values.firstWhere(
    (w) => w.name == value,
    orElse: () => OnlineWinner.draw,
  );
}

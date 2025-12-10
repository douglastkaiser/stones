import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';

enum OnlineStatus { waiting, playing, finished }

enum OnlineWinner { white, black, draw }

class OnlineGamePlayer {
  final String id;
  final String displayName;

  const OnlineGamePlayer({required this.id, required this.displayName});

  Map<String, dynamic> toMap() => {
        'id': id,
        'displayName': displayName,
      };

  factory OnlineGamePlayer.fromMap(Map<String, dynamic> map) {
    return OnlineGamePlayer(
      id: map['id'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Player',
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

  Map<String, dynamic> toMap() => {
        'notation': notation,
        'player': player.name,
        'timestamp': FieldValue.serverTimestamp(),
      };

  factory OnlineGameMove.fromMap(Map<String, dynamic> map) {
    final timestamp = map['timestamp'];
    return OnlineGameMove(
      notation: map['notation'] as String? ?? '',
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
    };
  }

  factory OnlineGameSession.fromSnapshot(String code, Map<String, dynamic> data) {
    return OnlineGameSession(
      roomCode: code,
      white: OnlineGamePlayer.fromMap(data['white'] as Map<String, dynamic>),
      black: data['black'] == null
          ? null
          : OnlineGamePlayer.fromMap(data['black'] as Map<String, dynamic>),
      boardSize: (data['boardSize'] as num?)?.toInt() ?? 5,
      moves: ((data['moves'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(OnlineGameMove.fromMap)
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

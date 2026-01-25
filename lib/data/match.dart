import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchStatus {
  pending,
  completed;

  String get displayName {
    switch (this) {
      case MatchStatus.pending:
        return 'Pending';
      case MatchStatus.completed:
        return 'Completed';
    }
  }
}

class Match {
  final String matchId; // firebase generated match id, required
  final MatchStatus status; // pending or completed, required
  final List<int>? score; // ex. [2, 4], can be null
  final int? winners; // 1, 2: who won, can be null
  final Map<String, int> players; // <id: which team: 1, 2>, required
  final double? ratingChange; // after calculation, ex: -20 to team 1, +20 to team 2, can be null

  Match({
    required this.matchId,
    required this.status,
    this.score,
    this.winners,
    required this.players,
    this.ratingChange,
  });

  Map<String, dynamic> toMap() {
    return {
      'matchId': matchId,
      'status': status.name,
      'score': score,
      'winners': winners,
      'players': players,
      'ratingChange': ratingChange,
    };
  }

  factory Match.fromMap(Map<String, dynamic> map, {String? id}) {
    return Match(
      matchId: id ?? map['matchId'] ?? '',
      status: MatchStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MatchStatus.pending,
      ),
      score: map['score'] != null ? List<int>.from(map['score']) : null,
      winners: map['winners'],
      players: Map<String, int>.from(map['players'] ?? {}),
      ratingChange: map['ratingChange']?.toDouble(),
    );
  }

  factory Match.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Match.fromMap(data, id: doc.id);
  }

  Match copyWith({
    String? matchId,
    MatchStatus? status,
    List<int>? score,
    int? winners,
    Map<String, int>? players,
    double? ratingChange,
  }) {
    return Match(
      matchId: matchId ?? this.matchId,
      status: status ?? this.status,
      score: score ?? this.score,
      winners: winners ?? this.winners,
      players: players ?? this.players,
      ratingChange: ratingChange ?? this.ratingChange,
    );
  }
}

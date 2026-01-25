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

// only the class is the final version, need to complete other details too
class Match {
  final String matchId; // generated match id
  final MatchStatus status; // pending or completed
  final List<int> score; // ex. [2, 4]
  final int winners; // 1, 2: who won
  final Map<String:int>; // players; <id:which team:1,2>
  final float RatingChange; // after calculation, ex: -20 to the team 1, + 20 to 2


  TeamData({
    required this.player1,
    this.player2,
    required this.player1Rating,
    this.player2Rating,
    required this.teamRating,
    this.score,
  });

  Map<String, dynamic> toMap() {
    return {
      'player1': player1,
      'player2': player2,
      'player1Rating': player1Rating,
      'player2Rating': player2Rating,
      'teamRating': teamRating,
      'score': score,
    };
  }

  factory TeamData.fromMap(Map<String, dynamic> map) {
    return TeamData(
      player1: map['player1'],
      player2: map['player2'],
      player1Rating: map['player1Rating'] ?? 1000,
      player2Rating: map['player2Rating'],
      teamRating: (map['teamRating'] ?? 1000).toDouble(),
      score: map['score'],
    );
  }

  TeamData copyWith({
    String? player1,
    String? player2,
    int? player1Rating,
    int? player2Rating,
    double? teamRating,
    int? score,
  }) {
    return TeamData(
      player1: player1 ?? this.player1,
      player2: player2 ?? this.player2,
      player1Rating: player1Rating ?? this.player1Rating,
      player2Rating: player2Rating ?? this.player2Rating,
      teamRating: teamRating ?? this.teamRating,
      score: score ?? this.score,
    );
  }
}

class MatchModel {
  final String id;
  final String eventId;
  final int matchNumber;
  final TeamData teamA;
  final TeamData teamB;
  final String? winner; // 'teamA' or 'teamB'
  final MatchStatus status;
  final double expectedScoreA;
  final double expectedScoreB;
  final double? ratingChangeA;
  final double? ratingChangeB;
  final DateTime? completedAt;
  final DateTime createdAt;

  MatchModel({
    required this.id,
    required this.eventId,
    required this.matchNumber,
    required this.teamA,
    required this.teamB,
    this.winner,
    this.status = MatchStatus.pending,
    required this.expectedScoreA,
    required this.expectedScoreB,
    this.ratingChangeA,
    this.ratingChangeB,
    this.completedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'matchNumber': matchNumber,
      'teamA': teamA.toMap(),
      'teamB': teamB.toMap(),
      'winner': winner,
      'status': status.name,
      'expectedScoreA': expectedScoreA,
      'expectedScoreB': expectedScoreB,
      'ratingChangeA': ratingChangeA,
      'ratingChangeB': ratingChangeB,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MatchModel(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      matchNumber: data['matchNumber'] ?? 0,
      teamA: TeamData.fromMap(data['teamA'] ?? {}),
      teamB: TeamData.fromMap(data['teamB'] ?? {}),
      winner: data['winner'],
      status: MatchStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => MatchStatus.pending,
      ),
      expectedScoreA: (data['expectedScoreA'] ?? 0.5).toDouble(),
      expectedScoreB: (data['expectedScoreB'] ?? 0.5).toDouble(),
      ratingChangeA: data['ratingChangeA']?.toDouble(),
      ratingChangeB: data['ratingChangeB']?.toDouble(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  MatchModel copyWith({
    String? id,
    String? eventId,
    int? matchNumber,
    TeamData? teamA,
    TeamData? teamB,
    String? winner,
    MatchStatus? status,
    double? expectedScoreA,
    double? expectedScoreB,
    double? ratingChangeA,
    double? ratingChangeB,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return MatchModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      matchNumber: matchNumber ?? this.matchNumber,
      teamA: teamA ?? this.teamA,
      teamB: teamB ?? this.teamB,
      winner: winner ?? this.winner,
      status: status ?? this.status,
      expectedScoreA: expectedScoreA ?? this.expectedScoreA,
      expectedScoreB: expectedScoreB ?? this.expectedScoreB,
      ratingChangeA: ratingChangeA ?? this.ratingChangeA,
      ratingChangeB: ratingChangeB ?? this.ratingChangeB,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
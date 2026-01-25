import 'package:cloud_firestore/cloud_firestore.dart';

/// Match status in Firestore: 'pending' or 'completed'
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

  static MatchStatus fromName(String? name) {
    return MatchStatus.values.firstWhere(
          (e) => e.name == name,
      orElse: () => MatchStatus.pending,
    );
  }
}

/// Winner side identifier for match.
/// Stored as string in Firestore for simplicity.
enum MatchWinnerSide {
  teamA,
  teamB;

  static MatchWinnerSide? fromNullableString(String? value) {
    if (value == null) return null;
    return MatchWinnerSide.values.firstWhere(
          (e) => e.name == value,
      orElse: () => MatchWinnerSide.teamA,
    );
  }
}

/// Main match model persisted in Firestore.
class MatchModel {
  /// Firestore doc id
  final String mid;

  /// Which event this match belongs to
  final String eventId;

  /// A number within an event, useful for display
  final int matchNumber;

  final Map<String, int> playerTeam;

  /// Ex: [2,4] => teamA 2, teamB 4
  /// Null when pending / not recorded yet
  final List<int>? score;

  /// Which team won. Null if pending.
  final MatchWinnerSide? winner;

  final MatchStatus status;

  /// Elo / expected score snapshots (optional but you already use them)
  final double expectedScoreA;
  final double expectedScoreB;

  /// Rating change after match completed (positive means gain)
  final double? ratingChangeA;
  final double? ratingChangeB;

  final DateTime createdAt;
  final DateTime? completedAt;

  const MatchModel({
    required this.mid,
    required this.eventId,
    required this.matchNumber,
    required this.playerTeam,
    this.score,
    this.winner,
    this.status = MatchStatus.pending,
    this.expectedScoreA = 0.5,
    this.expectedScoreB = 0.5,
    this.ratingChangeA,
    this.ratingChangeB,
    required this.createdAt,
    this.completedAt,
  });

  bool get isCompleted => status == MatchStatus.completed;

  /// Convenience: validate score format if present
  bool get hasValidScore =>
      score != null && score!.length == 2 && score!.every((v) => v >= 0);

  Map<String, dynamic> toFirestore() {
    return {
      'mid': mid,
      'eventId': eventId,
      'matchNumber': matchNumber,
      'playerTeam': playerTeam,
      'score': score,
      'winner': winner?.name, // 'teamA' or 'teamB'
      'status': status.name, // 'pending' or 'completed'
      'expectedScoreA': expectedScoreA,
      'expectedScoreB': expectedScoreB,
      'ratingChangeA': ratingChangeA,
      'ratingChangeB': ratingChangeB,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt == null ? null : Timestamp.fromDate(completedAt!),
    };
  }

  factory MatchModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    final createdAtTs = data['createdAt'] as Timestamp?;
    final completedAtTs = data['completedAt'] as Timestamp?;

    final rawPlayerTeam = data['playerTeam'] as Map?;
    final playerTeam = rawPlayerTeam == null
        ? <String, int>{}
        : rawPlayerTeam.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));

    final scoreRaw = data['score'];
    List<int>? score;
    if (scoreRaw is List) {
      // Safely coerce to int list
      score = scoreRaw.map((e) => (e as num).toInt()).toList();
    }

    return MatchModel(
      mid: doc.id,
      eventId: (data['eventId'] ?? '') as String,
      matchNumber: (data['matchNumber'] ?? 0) as int,
      playerTeam: playerTeam,
      score: score,
      winner: MatchWinnerSide.fromNullableString(data['winner'] as String?),
      status: MatchStatus.fromName(data['status'] as String?),
      expectedScoreA: ((data['expectedScoreA'] ?? 0.5) as num).toDouble(),
      expectedScoreB: ((data['expectedScoreB'] ?? 0.5) as num).toDouble(),
      ratingChangeA: (data['ratingChangeA'] as num?)?.toDouble(),
      ratingChangeB: (data['ratingChangeB'] as num?)?.toDouble(),
      createdAt: createdAtTs?.toDate() ?? DateTime.now(),
      completedAt: completedAtTs?.toDate(),
    );
  }

  MatchModel copyWith({
    String? id,
    String? eventId,
    int? matchNumber,
    Map<String, int>? playerTeam,
    List<int>? score,
    MatchWinnerSide? winner,
    MatchStatus? status,
    double? expectedScoreA,
    double? expectedScoreB,
    double? ratingChangeA,
    double? ratingChangeB,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return MatchModel(
      mid: mid ?? this.mid,
      eventId: eventId ?? this.eventId,
      matchNumber: matchNumber ?? this.matchNumber,
      playerTeam: playerTeam ?? this.playerTeam,
      score: score ?? this.score,
      winner: winner ?? this.winner,
      status: status ?? this.status,
      expectedScoreA: expectedScoreA ?? this.expectedScoreA,
      expectedScoreB: expectedScoreB ?? this.expectedScoreB,
      ratingChangeA: ratingChangeA ?? this.ratingChangeA,
      ratingChangeB: ratingChangeB ?? this.ratingChangeB,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

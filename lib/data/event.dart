import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType {
  practice,
  match;

  String get displayName {
    switch (this) {
      case EventType.practice:
        return 'Practice';
      case EventType.match:
        return 'Match';
    }
  }
}

enum EventVariant {
  singles,
  doubles;

  String get displayName {
    switch (this) {
      case EventVariant.singles:
        return 'Singles';
      case EventVariant.doubles:
        return 'Doubles';
    }
  }
}

enum EventStatus {
  open,
  full,
  inProgress,

  String get displayName {
    switch (this) {
      case EventStatus.open:
        return 'Open';
      case EventStatus.full:
        return 'Full';
      case EventStatus.inProgress:
        return 'In Progress';
      case EventStatus.completed:
        return 'Completed';
    }
  }
}

class RatingRange {
  final int min;
  final int max;

  RatingRange({required this.min, required this.max});

  Map<String, dynamic> toMap() => {'min': min, 'max': max};

  factory RatingRange.fromMap(Map<String, dynamic> map) {
    return RatingRange(
      min: map['min'] ?? 0,
      max: map['max'] ?? 3000,
    );
  }

  // Check if a rating is within range
  bool contains(int rating) => rating >= min && rating <= max;
}


class EventModel {
  // TO DO: 100% base on the EventModel attributes (line 70-88), fix the event.dart file.
  final String id; // event id, generated
  final String title; // event tile
  final EventType eventType; // match or practice
  final String hostId; // ppl that create it
  final String location; // google map url
  final EventVariant variant; // headcount single/double
  final RatingRange ratingRange; // [host - 200, host + 200]
  final int maxParticipants; // host input
  final List<String> participants; // ppl in the game, user id include host


  final List<String>? matches; // match ids (match holds the scores, etc.

  final EventStatus status; // open or full
  final DateTime startAt;
  final DateTime endAt;
  final DateTime createdAt;
  final DateTime updatedAt; // the last update (ex. ppl join)


  EventModel({
    required this.id,
    required this.title,
    required this.eventType,
    required this.hostId,
    required this.location,
    required this.variant,
    required this.ratingRange,
    required this.maxParticipants,
    this.participants = const [],
    this.matches,
    this.status = EventStatus.open,
    required this.startAt,
    required this.endAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'eventType': eventType.name,
      'hostId': hostId,
      'location': location,
      'variant': variant.name,
      'ratingRange': ratingRange.toMap(),
      'maxParticipants': maxParticipants,
      'participants': participants,
      'matches': matches,
      'status': status.name,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      eventType: EventType.values.firstWhere(
            (e) => e.name == data['eventType'],
        orElse: () => EventType.practice,
      ),
      hostId: data['hostId'] ?? '',
      location: data['location'] ?? '',
      variant: EventVariant.values.firstWhere(
            (e) => e.name == data['variant'],
        orElse: () => EventVariant.singles,
      ),
      ratingRange: RatingRange.fromMap(data['ratingRange'] ?? {}),
      maxParticipants: data['maxParticipants'] ?? 8,
      participants: List<String>.from(data['participants'] ?? []),
      matches: data['matches'] != null ? List<String>.from(data['matches']) : null,
      status: EventStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => EventStatus.open,
      ),
      startAt: (data['startAt'] as Timestamp).toDate(),
      endAt: (data['endAt'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  EventModel copyWith({
    String? id,
    String? title,
    EventType? eventType,
    String? hostId,
    String? location,
    EventVariant? variant,
    RatingRange? ratingRange,
    int? maxParticipants,
    List<String>? participants,
    List<String>? matches,
    EventStatus? status,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      eventType: eventType ?? this.eventType,
      hostId: hostId ?? this.hostId,
      location: location ?? this.location,
      variant: variant ?? this.variant,
      ratingRange: ratingRange ?? this.ratingRange,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participants: participants ?? this.participants,
      matches: matches ?? this.matches,
      status: status ?? this.status,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  bool get isFull => participants.length >= maxParticipants;
  bool get canJoin => status == EventStatus.open && !isFull;
  int get spotsLeft => maxParticipants - participants.length;
}
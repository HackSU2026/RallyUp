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
  completed,
  cancelled;

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
      case EventStatus.cancelled:
        return 'Cancelled';
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
  final String id;
  final String title;
  final String description;
  final EventType eventType;
  final String hostId;
  final String hostName;
  final String location;
  final String sportType;
  final EventVariant variant;
  final int socialCreditThreshold;
  final RatingRange ratingRange;
  final int maxParticipants;
  final List<String> participants;
  final EventStatus status;
  final DateTime dateTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.eventType,
    required this.hostId,
    required this.hostName,
    required this.location,
    this.sportType = 'Badminton',
    required this.variant,
    this.socialCreditThreshold = 0,
    required this.ratingRange,
    required this.maxParticipants,
    this.participants = const [],
    this.status = EventStatus.open,
    required this.dateTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'eventType': eventType.name,
      'hostId': hostId,
      'hostName': hostName,
      'location': location,
      'sportType': sportType,
      'variant': variant.name,
      'socialCreditThreshold': socialCreditThreshold,
      'ratingRange': ratingRange.toMap(),
      'maxParticipants': maxParticipants,
      'participants': participants,
      'status': status.name,
      'dateTime': Timestamp.fromDate(dateTime),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      eventType: EventType.values.firstWhere(
            (e) => e.name == data['eventType'],
        orElse: () => EventType.practice,
      ),
      hostId: data['hostId'] ?? '',
      hostName: data['hostName'] ?? '',
      location: data['location'] ?? '',
      sportType: data['sportType'] ?? 'Badminton',
      variant: EventVariant.values.firstWhere(
            (e) => e.name == data['variant'],
        orElse: () => EventVariant.singles,
      ),
      socialCreditThreshold: data['socialCreditThreshold'] ?? 0,
      ratingRange: RatingRange.fromMap(data['ratingRange'] ?? {}),
      maxParticipants: data['maxParticipants'] ?? 8,
      participants: List<String>.from(data['participants'] ?? []),
      status: EventStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => EventStatus.open,
      ),
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    EventType? eventType,
    String? hostId,
    String? hostName,
    String? location,
    String? sportType,
    EventVariant? variant,
    int? socialCreditThreshold,
    RatingRange? ratingRange,
    int? maxParticipants,
    List<String>? participants,
    EventStatus? status,
    DateTime? dateTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      location: location ?? this.location,
      sportType: sportType ?? this.sportType,
      variant: variant ?? this.variant,
      socialCreditThreshold: socialCreditThreshold ?? this.socialCreditThreshold,
      ratingRange: ratingRange ?? this.ratingRange,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participants: participants ?? this.participants,
      status: status ?? this.status,
      dateTime: dateTime ?? this.dateTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  bool get isFull => participants.length >= maxParticipants;
  bool get canJoin => status == EventStatus.open && !isFull;
  int get spotsLeft => maxParticipants - participants.length;
}
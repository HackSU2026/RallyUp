import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rally_up/data/event.dart';

/// Utility class to seed mock events to Firebase for testing
class EventSeeder {
  static const String _host1 = '7ApB5KWnx7aF5U000gaZHvyQqUt1';
  static const String _host2 = 'DuC6vYtCi5SRIQxSQdj2nrefTgp1';

  static const String _locationDowntown =
      'https://maps.google.com/?q=downtown_tennis_center';
  static const String _locationWestside =
      'https://maps.google.com/?q=westside_sports_complex';
  static const String _locationUniversity =
      'https://maps.google.com/?q=university_courts';
  static const String _locationPark =
      'https://maps.google.com/?q=central_park_courts';

  /// Seeds 20 mock events to Firestore
  static Future<void> seedEvents() async {
    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();
    final events = _createMockEvents(now);

    final batch = firestore.batch();
    for (final event in events) {
      final docRef = firestore.collection('events').doc();
      batch.set(docRef, event.toFirestore());
    }

    await batch.commit();
    print('Successfully seeded ${events.length} mock events to Firebase');
  }

  /// Clears all events from Firestore (use with caution!)
  static Future<void> clearEvents() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('events').get();

    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    print('Cleared ${snapshot.docs.length} events from Firebase');
  }

  /// Creates 20 mock events with diverse properties for testing
  static List<EventModel> _createMockEvents(DateTime now) {
    return [
      // === EventType Coverage (1-4) ===

      // Event 1: Beginner Practice Session
      EventModel(
        id: '',
        title: 'Beginner Practice Session',
        eventType: EventType.practice,
        hostId: _host1,
        location: _locationDowntown,
        variant: EventVariant.singles,
        ratingRange: RatingRange(min: 800, max: 1200),
        maxParticipants: 8,
        participants: [_host1],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 2, hours: 10)),
        endAt: now.add(const Duration(days: 2, hours: 12)),
      ),

      // Event 2: Advanced Singles Match
      EventModel(
        id: '',
        title: 'Advanced Singles Match',
        eventType: EventType.match,
        hostId: _host2,
        location: _locationWestside,
        variant: EventVariant.singles,
        ratingRange: RatingRange(min: 1600, max: 2000),
        maxParticipants: 2,
        participants: [_host2],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 3, hours: 14)),
        endAt: now.add(const Duration(days: 3, hours: 17)),
      ),

      // Event 3: Intermediate Doubles Practice
      EventModel(
        id: '',
        title: 'Intermediate Doubles Practice',
        eventType: EventType.practice,
        hostId: _host1,
        location: _locationUniversity,
        variant: EventVariant.doubles,
        ratingRange: RatingRange(min: 1200, max: 1600),
        maxParticipants: 8,
        participants: [_host1],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 1, hours: 18)),
        endAt: now.add(const Duration(days: 1, hours: 20)),
      ),

      // Event 4: Mixed Doubles Match
      EventModel(
        id: '',
        title: 'Mixed Doubles Match',
        eventType: EventType.match,
        hostId: _host2,
        location: _locationPark,
        variant: EventVariant.doubles,
        ratingRange: RatingRange(min: 1000, max: 1500),
        maxParticipants: 4,
        participants: [_host2, _host1],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 4, hours: 9)),
        endAt: now.add(const Duration(days: 4, hours: 12)),
      ),

      // === Status Coverage (5-8) ===

      // Event 5: Open Beginner Singles
      EventModel(
        id: '',
        title: 'Open Beginner Singles',
        eventType: EventType.practice,
        hostId: _host1,
        location: _locationDowntown,
        variant: EventVariant.singles,
        ratingRange: RatingRange(min: 900, max: 1100),
        maxParticipants: 6,
        participants: [_host1],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 5, hours: 10)),
        endAt: now.add(const Duration(days: 5, hours: 12)),
      ),

      // Event 6: Full Doubles Match (status: full)
      EventModel(
        id: '',
        title: 'Full Doubles Match',
        eventType: EventType.match,
        hostId: _host2,
        location: _locationWestside,
        variant: EventVariant.doubles,
        ratingRange: RatingRange(min: 1700, max: 2100),
        maxParticipants: 4,
        participants: [_host2, _host1, 'mock_user_3', 'mock_user_4'],
        status: EventStatus.full,
        startAt: now.add(const Duration(days: 2, hours: 15)),
        endAt: now.add(const Duration(days: 2, hours: 18)),
      ),

      // Event 7: In Progress Tournament (status: inProgress)
      EventModel(
        id: '',
        title: 'In Progress Tournament',
        eventType: EventType.match,
        hostId: _host1,
        location: _locationUniversity,
        variant: EventVariant.singles,
        ratingRange: RatingRange(min: 1300, max: 1700),
        maxParticipants: 2,
        participants: [_host1, _host2],
        matches: ['match_001'],
        status: EventStatus.inProgress,
        startAt: now.subtract(const Duration(hours: 1)),
        endAt: now.add(const Duration(hours: 2)),
      ),

      // Event 8: Completed Weekly Practice (status: completed)
      EventModel(
        id: '',
        title: 'Completed Weekly Practice',
        eventType: EventType.practice,
        hostId: _host2,
        location: _locationPark,
        variant: EventVariant.doubles,
        ratingRange: RatingRange(min: 1000, max: 1400),
        maxParticipants: 8,
        participants: [_host2, _host1],
        status: EventStatus.completed,
        startAt: now.subtract(const Duration(days: 3, hours: -10)),
        endAt: now.subtract(const Duration(days: 3, hours: -12)),
      ),

      // === Location Variety (9-12) ===

      // Event 9: Downtown Singles Match
      EventModel(
        id: '',
        title: 'Downtown Singles Match',
        eventType: EventType.match,
        hostId: _host1,
        location: _locationDowntown,
        variant: EventVariant.singles,
        ratingRange: RatingRange(min: 1300, max: 1600),
        maxParticipants: 2,
        participants: [_host1],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 6, hours: 14)),
        endAt: now.add(const Duration(days: 6, hours: 16)),
      ),

      // Event 10: Westside Doubles Practice
      EventModel(
        id: '',
        title: 'Westside Doubles Practice',
        eventType: EventType.practice,
        hostId: _host2,
        location: _locationWestside,
        variant: EventVariant.doubles,
        ratingRange: RatingRange(min: 1500, max: 1900),
        maxParticipants: 8,
        participants: [_host2, _host1],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 7, hours: 17)),
        endAt: now.add(const Duration(days: 7, hours: 19)),
      ),

      // Event 11: University Doubles Match
      EventModel(
        id: '',
        title: 'University Doubles Match',
        eventType: EventType.match,
        hostId: _host1,
        location: _locationUniversity,
        variant: EventVariant.doubles,
        ratingRange: RatingRange(min: 1200, max: 1800),
        maxParticipants: 4,
        participants: [_host1],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 10, hours: 8)),
        endAt: now.add(const Duration(days: 10, hours: 16)),
      ),

      // Event 12: Park Recreation Practice
      EventModel(
        id: '',
        title: 'Park Recreation Practice',
        eventType: EventType.practice,
        hostId: _host2,
        location: _locationPark,
        variant: EventVariant.singles,
        ratingRange: RatingRange(min: 900, max: 1200),
        maxParticipants: 6,
        participants: [_host2, _host1],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 8, hours: 11)),
        endAt: now.add(const Duration(days: 8, hours: 13)),
      ),

      // === Rating Range Edge Cases (13-16) ===

      // Event 13: Absolute Beginner Practice (floor boundary)
      EventModel(
        id: '',
        title: 'Absolute Beginner Practice',
        eventType: EventType.practice,
        hostId: _host1,
        location: _locationDowntown,
        variant: EventVariant.singles,
        ratingRange: RatingRange(min: 0, max: 800),
        maxParticipants: 8,
        participants: [_host1],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 9, hours: 10)),
        endAt: now.add(const Duration(days: 9, hours: 12)),
      ),

      // Event 14: Elite Pro Singles Match (ceiling boundary)
      EventModel(
        id: '',
        title: 'Elite Pro Singles Match',
        eventType: EventType.match,
        hostId: _host2,
        location: _locationWestside,
        variant: EventVariant.singles,
        ratingRange: RatingRange(min: 2200, max: 3000),
        maxParticipants: 2,
        participants: [_host2],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 11, hours: 13)),
        endAt: now.add(const Duration(days: 11, hours: 16)),
      ),

      // Event 15: All-Levels Practice (wide range)
      EventModel(
        id: '',
        title: 'All-Levels Practice',
        eventType: EventType.practice,
        hostId: _host1,
        location: _locationUniversity,
        variant: EventVariant.doubles,
        ratingRange: RatingRange(min: 500, max: 2500),
        maxParticipants: 8,
        participants: [_host1, _host2],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 12, hours: 9)),
        endAt: now.add(const Duration(days: 12, hours: 12)),
      ),

      // Event 16: Intermediate-Only Match (narrow range)
      EventModel(
        id: '',
        title: 'Intermediate-Only Match',
        eventType: EventType.match,
        hostId: _host2,
        location: _locationPark,
        variant: EventVariant.doubles,
        ratingRange: RatingRange(min: 1350, max: 1450),
        maxParticipants: 4,
        participants: [_host2],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 13, hours: 15)),
        endAt: now.add(const Duration(days: 13, hours: 17)),
      ),

      // === Participant Variations (17-18) ===

      // Event 17: One-on-One Singles Match (small, 2 max)
      EventModel(
        id: '',
        title: 'One-on-One Singles Match',
        eventType: EventType.match,
        hostId: _host1,
        location: _locationDowntown,
        variant: EventVariant.singles,
        ratingRange: RatingRange(min: 900, max: 1100),
        maxParticipants: 2,
        participants: [_host1],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 14, hours: 7)),
        endAt: now.add(const Duration(days: 14, hours: 8)),
      ),

      // Event 18: Group Doubles Practice (larger group)
      EventModel(
        id: '',
        title: 'Group Doubles Practice',
        eventType: EventType.practice,
        hostId: _host2,
        location: _locationWestside,
        variant: EventVariant.doubles,
        ratingRange: RatingRange(min: 1200, max: 1800),
        maxParticipants: 8,
        participants: [_host2, _host1, 'mock_user_5', 'mock_user_6'],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 15, hours: 10)),
        endAt: now.add(const Duration(days: 15, hours: 14)),
      ),

      // === Time Edge Cases (19-20) ===

      // Event 19: Starting Very Soon
      EventModel(
        id: '',
        title: 'Starting Very Soon',
        eventType: EventType.match,
        hostId: _host1,
        location: _locationUniversity,
        variant: EventVariant.doubles,
        ratingRange: RatingRange(min: 1300, max: 1500),
        maxParticipants: 4,
        participants: [_host1, _host2],
        status: EventStatus.open,
        startAt: now.add(const Duration(hours: 1)),
        endAt: now.add(const Duration(hours: 3)),
      ),

      // Event 20: Yesterday's Completed Match
      EventModel(
        id: '',
        title: "Yesterday's Completed Match",
        eventType: EventType.match,
        hostId: _host2,
        location: _locationPark,
        variant: EventVariant.singles,
        ratingRange: RatingRange(min: 1600, max: 2000),
        maxParticipants: 2,
        participants: [_host2, _host1],
        matches: ['match_002'],
        status: EventStatus.completed,
        startAt: now.subtract(const Duration(days: 1, hours: -9)),
        endAt: now.subtract(const Duration(days: 1, hours: -12)),
      ),
    ];
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rally_up/data/event.dart';

/// Utility class to seed mock events to Firebase for testing
class EventSeeder {
  static const String _host = 'bTASourVYWfTwcLdcDUu4S6KGqB3';

  static const String _locationDowntown =
      'https://maps.google.com/?q=downtown_tennis_center';
  static const String _locationPark =
      'https://maps.google.com/?q=central_park_courts';

  /// Seeds 2 beginner events to Firestore
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

  /// Creates 2 beginner mock events for testing
  static List<EventModel> _createMockEvents(DateTime now) {
    return [
      // Event 1: Beginner Practice Session
      EventModel(
        id: '',
        title: 'Beginner Practice Session',
        eventType: EventType.practice,
        hostId: _host,
        location: _locationDowntown,
        variant: EventVariant.singles,
        ratingRange: RatingRange(min: 800, max: 1200),
        maxParticipants: 8,
        participants: [_host],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 2, hours: 10)),
        endAt: now.add(const Duration(days: 2, hours: 12)),
      ),

      // Event 2: Beginner Singles Match
      EventModel(
        id: '',
        title: 'Beginner Singles Match',
        eventType: EventType.match,
        hostId: _host,
        location: _locationPark,
        variant: EventVariant.singles,
        ratingRange: RatingRange(min: 800, max: 1200),
        maxParticipants: 2,
        participants: [_host],
        status: EventStatus.open,
        startAt: now.add(const Duration(days: 3, hours: 14)),
        endAt: now.add(const Duration(days: 3, hours: 15)),
      ),
    ];
  }
}

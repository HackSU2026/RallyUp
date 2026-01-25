import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../data/event.dart';

enum EventProviderStatus {
  initial,
  loading,
  loaded,
  creating,
  updating,
  error,
}

class EventProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'events';

  EventProviderStatus _status = EventProviderStatus.initial;
  List<EventModel> _events = [];
  EventModel? _selectedEvent;
  String? _errorMessage;

  EventProviderStatus get status => _status;
  List<EventModel> get events => _events;
  EventModel? get selectedEvent => _selectedEvent;
  String? get errorMessage => _errorMessage;

  // Get all events
  Future<void> loadEvents() async {
    try {
      _status = EventProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final snapshot = await _firestore.collection(_collection).get();
      _events = snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList();
      _status = EventProviderStatus.loaded;
    } catch (e) {
      _status = EventProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> appendMatchToEvent({
    required String eventId,
    required String matchId,
  }) async {
    try {
      _status = EventProviderStatus.updating;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection(_collection).doc(eventId).update({
        'matches': FieldValue.arrayUnion([matchId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      if (_selectedEvent != null && _selectedEvent!.id == eventId) {
        final current = _selectedEvent!;
        final List<String> updatedMatches = [
          ...(current.matches ?? <String>[]),
          if (!(current.matches ?? <String>[]).contains(matchId)) matchId,
        ];

        _selectedEvent = current.copyWith(
          matches: updatedMatches,
          updatedAt: DateTime.now(),
        );
      }

      final idx = _events.indexWhere((e) => e.id == eventId);
      if (idx != -1) {
        final current = _events[idx];
        final List<String> updatedMatches = [
          ...(current.matches ?? <String>[]),
          if (!(current.matches ?? <String>[]).contains(matchId)) matchId,
        ];

        _events[idx] = current.copyWith(
          matches: updatedMatches,
          updatedAt: DateTime.now(),
        );
      }

      _status = EventProviderStatus.loaded;
    } catch (e) {
      _status = EventProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Get event by ID
  Future<void> loadEvent(String eventId) async {
    try {
      _status = EventProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final doc = await _firestore.collection(_collection).doc(eventId).get();
      if (doc.exists) {
        _selectedEvent = EventModel.fromFirestore(doc);
      } else {
        _selectedEvent = null;
      }
      _status = EventProviderStatus.loaded;
    } catch (e) {
      _status = EventProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Create event
  Future<String?> createEvent(EventModel event) async {
    try {
      _status = EventProviderStatus.creating;
      _errorMessage = null;
      notifyListeners();

      final docRef = await _firestore.collection(_collection).add(event.toFirestore());
      await loadEvents(); // Reload events list
      _status = EventProviderStatus.loaded;
      return docRef.id;
    } catch (e) {
      _status = EventProviderStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Update event
  Future<void> updateEvent(EventModel event) async {
    try {
      _status = EventProviderStatus.updating;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection(_collection).doc(event.id).update(event.toFirestore());

      // Update selected event if it's the same one
      if (_selectedEvent?.id == event.id) {
        _selectedEvent = event;
      }

      // Update in events list
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        _events[index] = event;
      }

      _status = EventProviderStatus.loaded;
    } catch (e) {
      _status = EventProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Join event
  Future<void> joinEvent(String eventId, String userId) async {
    try {
      _status = EventProviderStatus.updating;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection(_collection).doc(eventId).update({
        'participants': FieldValue.arrayUnion([userId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Reload the specific event to get updated participants
      await loadEvent(eventId);

      // Reload all events to update the list
      await loadEvents();

      _status = EventProviderStatus.loaded;
    } catch (e) {
      _status = EventProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // TODO: delete leaveEvent function, leave event not allowed
  Future<void> leaveEvent(String eventId, String userId) async {
    try {
      _status = EventProviderStatus.updating;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection(_collection).doc(eventId).update({
        'participants': FieldValue.arrayRemove([userId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Reload the specific event
      await loadEvent(eventId);

      // Reload all events
      await loadEvents();

      _status = EventProviderStatus.loaded;
    } catch (e) {
      _status = EventProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Get user's events (events they've joined or are hosting)
  Future<void> loadUserEvents(String userId) async {
    try {
      _status = EventProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final snapshot = await _firestore
          .collection(_collection)
          .where('participants', arrayContains: userId)
          .get();
      _events = snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList();
      _status = EventProviderStatus.loaded;
    } catch (e) {
      _status = EventProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Get events hosted by user
  Future<void> loadHostedEvents(String userId) async {
    try {
      _status = EventProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final snapshot = await _firestore
          .collection(_collection)
          .where('hostId', isEqualTo: userId)
          .get();
      _events = snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList();
      _status = EventProviderStatus.loaded;
    } catch (e) {
      _status = EventProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Search events with filters
  Future<void> searchEvents({
    String? location,
    EventType? eventType,
    EventVariant? variant,
    int? minRating,
    int? maxRating,
  }) async {
    try {
      _status = EventProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      Query<Map<String, dynamic>> query = _firestore.collection(_collection);

      if (location != null && location.isNotEmpty) {
        query = query.where('location', isEqualTo: location);
      }
      if (eventType != null) {
        query = query.where('eventType', isEqualTo: eventType.name);
      }
      if (variant != null) {
        query = query.where('variant', isEqualTo: variant.name);
      }

      final snapshot = await query.get();
      _events = snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList();

      // Filter by rating range client-side (Firestore doesn't support nested field queries easily)
      if (minRating != null || maxRating != null) {
        _events = _events.where((event) {
          if (minRating != null && event.ratingRange.max < minRating) return false;
          if (maxRating != null && event.ratingRange.min > maxRating) return false;
          return true;
        }).toList();
      }

      _status = EventProviderStatus.loaded;
    } catch (e) {
      _status = EventProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Get events by status
  List<EventModel> getEventsByStatus(EventStatus status) {
    return _events.where((event) => event.status == status).toList();
  }

  // Get open events
  List<EventModel> get openEvents {
    return _events.where((event) => event.status == EventStatus.open).toList();
  }

  // Get events user can join (based on rating)
  List<EventModel> getJoinableEvents({
    required int userRating,
  }) {
    return _events.where((event) {
      // Must be open
      if (event.status != EventStatus.open) return false;

      // Must not be full
      if (event.isFull) return false;

      // Check rating range
      if (!event.ratingRange.contains(userRating)) return false;

      return true;
    }).toList();
  }

  // Update event status (for hosts)
  Future<void> updateEventStatus(String eventId, EventStatus newStatus) async {
    final event = _events.firstWhere((e) => e.id == eventId);
    final updatedEvent = event.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
    await updateEvent(updatedEvent);
  }

  // Check if user is host of event
  bool isUserHost(String eventId, String userId) {
    final event = _events.firstWhere(
      (e) => e.id == eventId,
      orElse: () => _selectedEvent!,
    );
    return event.hostId == userId;
  }

  // Check if user is participant
  bool isUserParticipant(String eventId, String userId) {
    final event = _events.firstWhere(
      (e) => e.id == eventId,
      orElse: () => _selectedEvent!,
    );
    return event.participants.contains(userId);
  }

  // Get upcoming events
  List<EventModel> get upcomingEvents {
    final now = DateTime.now();
    return _events
        .where((event) =>
            event.startAt.isAfter(now) &&
            event.status != EventStatus.completed)
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  // Get past events
  List<EventModel> get pastEvents {
    final now = DateTime.now();
    return _events
        .where((event) =>
            event.startAt.isBefore(now) ||
            event.status == EventStatus.completed)
        .toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Clear selected event
  void clearSelectedEvent() {
    _selectedEvent = null;
    notifyListeners();
  }

  // Reset provider state
  void reset() {
    _status = EventProviderStatus.initial;
    _events = [];
    _selectedEvent = null;
    _errorMessage = null;
    notifyListeners();
  }
}

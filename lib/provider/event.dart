// lib/presentation/providers/event_provider.dart

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
  // TODO: delete this code since we have no Repository
  final EventRepository _eventRepository = EventRepository();
  // TODO: add repository logic to provider/event.dart

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

      _events = await _eventRepository.getAllEvents();
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

      _selectedEvent = await _eventRepository.getEventById(eventId);
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

      final eventId = await _eventRepository.createEvent(event);
      await loadEvents(); // Reload events list
      _status = EventProviderStatus.loaded;
      return eventId;
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

      await _eventRepository.updateEvent(event);

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

      await _eventRepository.joinEvent(eventId, userId);

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

      await _eventRepository.leaveEvent(eventId, userId);

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

      _events = await _eventRepository.getUserEvents(userId);
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

      _events = await _eventRepository.getHostedEvents(userId);
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

      _events = await _eventRepository.searchEvents(
        location: location,
        eventType: eventType,
        variant: variant,
        minRating: minRating,
        maxRating: maxRating,
      );

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

  // Get events user can join (based on rating and social credit)
  List<EventModel> getJoinableEvents({
    required int userRating,
    required int userSocialCredit,
  }) {
    return _events.where((event) {
      // Must be open
      if (event.status != EventStatus.open) return false;

      // Must not be full
      if (event.isFull) return false;

      // Check rating range
      if (!event.ratingRange.contains(userRating)) return false;

      // Check social credit requirement
      if (event.socialCreditThreshold > userSocialCredit) return false;

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

  // TODO: remove deleteEvent function, not needed
  Future<void> deleteEvent(String eventId) async {
    try {
      _status = EventProviderStatus.updating;
      _errorMessage = null;
      notifyListeners();

      await _eventRepository.deleteEvent(eventId);

      // Remove from local list
      _events.removeWhere((event) => event.id == eventId);

      // Clear selected event if it was deleted
      if (_selectedEvent?.id == eventId) {
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
    event.dateTime.isAfter(now) &&
        event.status != EventStatus.cancelled &&
        event.status != EventStatus.completed)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // Get past events
  List<EventModel> get pastEvents {
    final now = DateTime.now();
    return _events
        .where((event) =>
    event.dateTime.isBefore(now) ||
        event.status == EventStatus.completed)
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
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

  // TODO: create a function for creating match model instance
  // call createMatch from provider/match.dart
}
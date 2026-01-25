import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:rally_up/data/event.dart';
import 'package:rally_up/data/match.dart';

enum HistoryProviderStatus {
  initial,
  loading,
  loaded,
  error,
}

class HistoryEventItem {
  final EventModel event;
  final List<MatchModel> matches;

  HistoryEventItem({
    required this.event,
    required this.matches,
  });

  bool get isCompetition => event.eventType == EventType.match;
}

class HistoryEventProvider extends ChangeNotifier {
  HistoryEventProvider() : _firestore = FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  final String _eventCollection = 'events';
  final String _matchCollection = 'matches';

  HistoryProviderStatus _status = HistoryProviderStatus.initial;
  String? _errorMessage;
  List<HistoryEventItem> _items = [];

  HistoryProviderStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<HistoryEventItem> get items => _items;

  Future<void> loadHistory(String uid) async {
    try {
      _status = HistoryProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final nowTs = Timestamp.fromDate(DateTime.now());

      final snap = await _firestore
          .collection(_eventCollection)
          .where('endAt', isLessThan: nowTs)
          .get();

      final events = snap.docs.map((d) => EventModel.fromFirestore(d)).toList()
        ..sort((a, b) => b.endAt.compareTo(a.endAt));

      final List<HistoryEventItem> built = [];

      for (final e in events) {
        if (e.eventType != EventType.match) {
          built.add(HistoryEventItem(event: e, matches: const []));
          continue;
        }

        final mSnap = await _firestore
            .collection(_matchCollection)
            .where('eventId', isEqualTo: e.id)
            .where('participants', arrayContains: uid)
            .get();

        final matches = mSnap.docs
            .map((d) => MatchModel.fromFirestore(d))
            .toList()
          ..sort((a, b) => a.matchNumber.compareTo(b.matchNumber));

        built.add(HistoryEventItem(event: e, matches: matches));
      }

      _items = built;
      _status = HistoryProviderStatus.loaded;
    } on FirebaseException catch (e) {
      _status = HistoryProviderStatus.error;
      _errorMessage = e.message ?? e.code;
    } catch (e) {
      _status = HistoryProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> refresh(String uid) => loadHistory(uid);
}

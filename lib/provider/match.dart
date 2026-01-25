import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../data/event.dart';
import '../data/match.dart';

import 'package:rally_up/data/match.dart';

class MatchProvider extends ChangeNotifier {
  MatchProvider() : _db = FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('matches');

  List<MatchModel> _matches = [];
  List<MatchModel> get matches => _matches;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// --------------------
  /// Create Match
  /// --------------------
  Future<MatchModel> createMatch(MatchModel match) async {
    _isLoading = true;
    notifyListeners();

    try {
      final docRef = await _col.add(match.toFirestore());
      final snap = await docRef.get();

      final created = MatchModel.fromFirestore(
        snap as DocumentSnapshot<Map<String, dynamic>>,
      );

      _matches.insert(0, created);

      return created;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// --------------------
  /// Get all matches by uid
  /// --------------------
  Future<void> fetchMatchesByUid(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      final fieldPath = 'playerTeam.$uid';

      final qSnap = await _col
          .where(fieldPath, isGreaterThan: 0)
          .orderBy('createdAt', descending: true)
          .get();

      _matches = qSnap.docs
          .map((d) => MatchModel.fromFirestore(d))
          .toList();
    } finally {
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Optional: clear cache
  void clear() {
    _matches = [];
    notifyListeners();
  }

  /// --------------------
  /// Update Match
  /// --------------------
  Future<void> updateMatch(MatchModel match) async {
    if (match.mid.isEmpty) {
      throw ArgumentError('Match id is empty. Cannot update without doc id.');
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _col.doc(match.mid).update(match.toFirestore());

      final idx = _matches.indexWhere((m) => m.mid == match.mid);
      if (idx != -1) {
        _matches[idx] = match;
      }
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        throw StateError('Match doc not found: ${match.mid}');
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// --------------------
  /// Get matches by eventId
  /// --------------------
  Future<List<MatchModel>> fetchMatchesByEventId(String eventId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final qSnap = await _col
          .where('eventId', isEqualTo: eventId)
          .orderBy('matchNumber')
          .get();

      final result = qSnap.docs
          .map((d) => MatchModel.fromFirestore(d))
          .toList();

      _matches = result;

      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// --------------------
  /// Get single match by matchId
  /// --------------------
  Future<MatchModel?> fetchMatchById(String matchId) async {
    if (matchId.isEmpty) return null;

    _isLoading = true;
    notifyListeners();

    try {
      final docSnap = await _col.doc(matchId).get();
      if (!docSnap.exists) return null;

      final match = MatchModel.fromFirestore(
        docSnap as DocumentSnapshot<Map<String, dynamic>>,
      );

      final idx = _matches.indexWhere((m) => m.mid == match.mid);
      if (idx == -1) {
        _matches.add(match);
      } else {
        _matches[idx] = match;
      }

      return match;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rally_up/data/event.dart';
import 'package:rally_up/data/match.dart';
import 'package:rally_up/data/user.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// --------------------
  /// Create Match
  /// --------------------
  Future<MatchModel?> createMatchFromEvent(String eventId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) throw Exception('Event not found');

      final eventData = eventDoc.data()!;
      final String variantString = eventData['variant'] ?? 'singles';
      final List<String> participantIds = List<String>.from(eventData['participants'] ?? []);

      if (participantIds.isEmpty) throw Exception('No participants found');

      final userSnaps = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: participantIds)
          .get();

      final List<UserProfile> profiles = userSnaps.docs
          .map((d) => UserProfile.fromMap(d.id, d.data()))
          .toList();

      Map<String, int> playerTeam = {};

      if (variantString == 'singles') {
        if (profiles.length >= 2) {
          playerTeam[participantIds[0]] = 1;
          playerTeam[participantIds[1]] = 2;
        }
      } else {
        if (profiles.length >= 4) {
          List<UserProfile> sorted = List.from(profiles);
          sorted.sort((a, b) => b.rating.compareTo(a.rating));

          playerTeam[sorted[0].uid] = 1;
          playerTeam[sorted[3].uid] = 1;
          playerTeam[sorted[1].uid] = 2;
          playerTeam[sorted[2].uid] = 2;
        }
      }

      if (playerTeam.isEmpty) throw Exception('Insufficient players for match creation');

      final existingMatches = await _firestore
          .collection('matches')
          .where('eventId', isEqualTo: eventId)
          .get();
      final int nextMatchNumber = existingMatches.docs.length + 1;

      final newMatch = MatchModel(
        mid: '',
        eventId: eventId,
        matchNumber: nextMatchNumber,
        playerTeam: playerTeam,
        status: MatchStatus.pending,
        createdAt: DateTime.now(),
        expectedScoreA: 0.5,
        expectedScoreB: 0.5,
      );

      final docRef = await _firestore.collection('matches').add(newMatch.toFirestore());
      final snap = await docRef.get();

      final created = MatchModel.fromFirestore(snap as DocumentSnapshot<Map<String, dynamic>>);

      _matches.insert(0, created);
      return created;
    } catch (e) {
      debugPrint('Create match error: $e');
      return null;
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

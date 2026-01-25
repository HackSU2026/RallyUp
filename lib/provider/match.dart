import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../data/event.dart';
import '../data/match.dart';

enum MatchProviderStatus {
  initial,
  loading,
  loaded,
  creating,
  updating,
  error,
}

class MatchProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _matchesCollection = 'matches';
  final String _eventsCollection = 'events';

  MatchProviderStatus _status = MatchProviderStatus.initial;
  List<Match> _matches = [];
  Match? _selectedMatch;
  String? _errorMessage;

  MatchProviderStatus get status => _status;
  List<Match> get matches => _matches;
  Match? get selectedMatch => _selectedMatch;
  String? get errorMessage => _errorMessage;

  // Load matches for an event using EventModel.matches list
  Future<void> loadEventMatches(String eventId) async {
    try {
      _status = MatchProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      // Get the event to retrieve its matches list
      final eventDoc = await _firestore.collection(_eventsCollection).doc(eventId).get();
      if (!eventDoc.exists) {
        _matches = [];
        _status = MatchProviderStatus.loaded;
        notifyListeners();
        return;
      }

      final eventData = eventDoc.data() as Map<String, dynamic>;
      final matchIds = List<String>.from(eventData['matches'] ?? []);

      if (matchIds.isEmpty) {
        _matches = [];
        _status = MatchProviderStatus.loaded;
        notifyListeners();
        return;
      }

      // Fetch all matches by their IDs
      final matchDocs = await Future.wait(
        matchIds.map((id) => _firestore.collection(_matchesCollection).doc(id).get()),
      );

      _matches = matchDocs
          .where((doc) => doc.exists)
          .map((doc) => Match.fromFirestore(doc))
          .toList();

      _status = MatchProviderStatus.loaded;
    } catch (e) {
      _status = MatchProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Load single match
  Future<void> loadMatch(String matchId) async {
    try {
      _status = MatchProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final doc = await _firestore.collection(_matchesCollection).doc(matchId).get();
      if (doc.exists) {
        _selectedMatch = Match.fromFirestore(doc);
      } else {
        _selectedMatch = null;
      }
      _status = MatchProviderStatus.loaded;
    } catch (e) {
      _status = MatchProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Create a match and add it to the event's matches list
  Future<String?> createMatch({
    required String eventId,
    required Map<String, int> players,
  }) async {
    try {
      _status = MatchProviderStatus.creating;
      _errorMessage = null;
      notifyListeners();

      // Validate players
      if (players.isEmpty) {
        throw Exception('Players map cannot be empty');
      }

      // Create the match
      final match = Match(
        matchId: '', // Will be set by Firestore
        status: MatchStatus.pending,
        players: players,
      );

      final docRef = await _firestore.collection(_matchesCollection).add(match.toMap());

      // Add match ID to the event's matches list
      await _firestore.collection(_eventsCollection).doc(eventId).update({
        'matches': FieldValue.arrayUnion([docRef.id]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      _status = MatchProviderStatus.loaded;
      return docRef.id;
    } catch (e) {
      _status = MatchProviderStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Create multiple matches for an event
  Future<void> createMatches({
    required String eventId,
    required List<Map<String, int>> playerMappings,
  }) async {
    try {
      _status = MatchProviderStatus.creating;
      _errorMessage = null;
      notifyListeners();

      for (final players in playerMappings) {
        await createMatch(eventId: eventId, players: players);
      }

      // Update event status to inProgress
      await _firestore.collection(_eventsCollection).doc(eventId).update({
        'status': EventStatus.inProgress.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      await loadEventMatches(eventId);
      _status = MatchProviderStatus.loaded;
    } catch (e) {
      _status = MatchProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Submit match result
  Future<void> submitMatchResult({
    required String matchId,
    required List<int> score,
    required int winners,
    double? ratingChange,
  }) async {
    try {
      _status = MatchProviderStatus.updating;
      _errorMessage = null;
      notifyListeners();

      // Validate score
      if (score.length != 2) {
        throw Exception('Score must have exactly 2 values');
      }
      if (score[0] < 0 || score[1] < 0) {
        throw Exception('Scores cannot be negative');
      }
      if (score[0] == score[1]) {
        throw Exception('Scores cannot be tied');
      }

      // Validate winners
      if (winners != 1 && winners != 2) {
        throw Exception('Winners must be 1 or 2');
      }

      // Update match in Firestore
      await _firestore.collection(_matchesCollection).doc(matchId).update({
        'status': MatchStatus.completed.name,
        'score': score,
        'winners': winners,
        'ratingChange': ratingChange,
      });

      // Reload the match
      await loadMatch(matchId);
      _status = MatchProviderStatus.loaded;
    } catch (e) {
      _status = MatchProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Check if all matches in event are completed and update event status
  Future<void> checkEventCompletion(String eventId) async {
    try {
      await loadEventMatches(eventId);

      final allCompleted = _matches.isNotEmpty &&
          _matches.every((match) => match.status == MatchStatus.completed);

      if (allCompleted) {
        await _firestore.collection(_eventsCollection).doc(eventId).update({
          'status': EventStatus.completed.name,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      debugPrint('Failed to check event completion: $e');
    }
  }

  // Get pending matches
  List<Match> get pendingMatches {
    return _matches
        .where((match) => match.status == MatchStatus.pending)
        .toList();
  }

  // Get completed matches
  List<Match> get completedMatches {
    return _matches
        .where((match) => match.status == MatchStatus.completed)
        .toList();
  }

  // Get matches for a specific player
  List<Match> getPlayerMatches(String playerId) {
    return _matches.where((match) => match.players.containsKey(playerId)).toList();
  }

  // Get match statistics for a player
  Map<String, dynamic> getPlayerMatchStats(String playerId) {
    final playerMatches = getPlayerMatches(playerId);
    final completedPlayerMatches = playerMatches
        .where((match) => match.status == MatchStatus.completed)
        .toList();

    int wins = 0;
    int losses = 0;
    double totalRatingChange = 0;

    for (final match in completedPlayerMatches) {
      final playerTeam = match.players[playerId];
      if (playerTeam == null) continue;

      if (match.winners == playerTeam) {
        wins++;
        if (match.ratingChange != null) {
          totalRatingChange += match.ratingChange!.abs();
        }
      } else {
        losses++;
        if (match.ratingChange != null) {
          totalRatingChange -= match.ratingChange!.abs();
        }
      }
    }

    return {
      'totalMatches': completedPlayerMatches.length,
      'wins': wins,
      'losses': losses,
      'winRate': completedPlayerMatches.isEmpty
          ? 0.0
          : (wins / completedPlayerMatches.length) * 100,
      'totalRatingChange': totalRatingChange,
      'averageRatingChange': completedPlayerMatches.isEmpty
          ? 0.0
          : totalRatingChange / completedPlayerMatches.length,
    };
  }

  // Check if user is involved in a match
  bool isUserInMatch(String matchId, String userId) {
    final match = _matches.firstWhere(
      (m) => m.matchId == matchId,
      orElse: () => _selectedMatch!,
    );
    return match.players.containsKey(userId);
  }

  // Get match result for a specific player
  String? getPlayerResult(String matchId, String playerId) {
    Match? match;
    try {
      match = _matches.firstWhere((m) => m.matchId == matchId);
    } catch (_) {
      match = _selectedMatch;
    }

    if (match == null || match.status != MatchStatus.completed) {
      return null;
    }

    final playerTeam = match.players[playerId];
    if (playerTeam == null) return null;

    return match.winners == playerTeam ? 'Win' : 'Loss';
  }

  // Delete a match
  Future<void> deleteMatch(String matchId, String eventId) async {
    try {
      _status = MatchProviderStatus.updating;
      _errorMessage = null;
      notifyListeners();

      // Remove match from Firestore
      await _firestore.collection(_matchesCollection).doc(matchId).delete();

      // Remove match ID from event's matches list
      await _firestore.collection(_eventsCollection).doc(eventId).update({
        'matches': FieldValue.arrayRemove([matchId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Remove from local list
      _matches.removeWhere((match) => match.matchId == matchId);

      if (_selectedMatch?.matchId == matchId) {
        _selectedMatch = null;
      }

      _status = MatchProviderStatus.loaded;
    } catch (e) {
      _status = MatchProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Clear selected match
  void clearSelectedMatch() {
    _selectedMatch = null;
    notifyListeners();
  }

  // Reset provider state
  void reset() {
    _status = MatchProviderStatus.initial;
    _matches = [];
    _selectedMatch = null;
    _errorMessage = null;
    notifyListeners();
  }
}

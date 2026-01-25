// lib/presentation/providers/match_provider.dart

import 'package:flutter/foundation.dart';
import '../data/event.dart';
// import '../../data/models/user_model.dart';
import '../../data/match.dart';
// import '../../data/repositories/match_repository.dart';
// import '../../data/repositories/user_repository.dart';
// import '../../data/repositories/event_repository.dart';
// import '../../data/services/rating_calculation_service.dart';

enum MatchProviderStatus {
  initial,
  loading,
  loaded,
  creating,
  updating,
  error,
}

class MatchProvider with ChangeNotifier {
  final MatchRepository _matchRepository = MatchRepository();
  final UserRepository _userRepository = UserRepository();
  final EventRepository _eventRepository = EventRepository();

  MatchProviderStatus _status = MatchProviderStatus.initial;
  List<MatchModel> _matches = [];
  MatchModel? _selectedMatch;
  String? _errorMessage;

  MatchProviderStatus get status => _status;
  List<MatchModel> get matches => _matches;
  MatchModel? get selectedMatch => _selectedMatch;
  String? get errorMessage => _errorMessage;

  // Load matches for an event
  Future<void> loadEventMatches(String eventId) async {
    try {
      _status = MatchProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      _matches = await _matchRepository.getEventMatches(eventId);
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

      _selectedMatch = await _matchRepository.getMatchById(matchId);
      _status = MatchProviderStatus.loaded;
    } catch (e) {
      _status = MatchProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Create matches for an event
  Future<void> createMatches({
    required String eventId,
    required List<String> participantIds,
    required Map<String, int> participantRatings,
    required bool isDoubles,
  }) async {
    try {
      _status = MatchProviderStatus.creating;
      _errorMessage = null;
      notifyListeners();

      // Validate participant count
      if (isDoubles && participantIds.length < 4) {
        throw Exception('Need at least 4 players for doubles matches');
      }
      if (!isDoubles && participantIds.length < 2) {
        throw Exception('Need at least 2 players for singles matches');
      }

      // Create pairings using the rating calculation service
      final pairings = RatingCalculationService.createMatchPairings(
        playerIds: participantIds,
        playerRatings: participantRatings,
        isDoubles: isDoubles,
      );

      // Create matches from pairings
      for (int i = 0; i < pairings.length; i++) {
        final pairing = pairings[i];

        if (isDoubles && pairing.length == 4) {
          // Doubles match: r1+r4 vs r2+r3
          await _createDoublesMatch(
            eventId: eventId,
            matchNumber: i + 1,
            player1Id: pairing[0],
            player2Id: pairing[3],
            player3Id: pairing[1],
            player4Id: pairing[2],
            participantRatings: participantRatings,
          );
        } else if (!isDoubles && pairing.length == 2) {
          // Singles match
          await _createSinglesMatch(
            eventId: eventId,
            matchNumber: i + 1,
            player1Id: pairing[0],
            player2Id: pairing[1],
            participantRatings: participantRatings,
          );
        }
      }

      // Update event status to inProgress
      final event = await _eventRepository.getEventById(eventId);
      if (event != null) {
        await _eventRepository.updateEvent(
          event.copyWith(status: EventStatus.inProgress),
        );
      }

      await loadEventMatches(eventId);
      _status = MatchProviderStatus.loaded;
    } catch (e) {
      _status = MatchProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Helper: Create doubles match
  Future<void> _createDoublesMatch({
    required String eventId,
    required int matchNumber,
    required String player1Id,
    required String player2Id,
    required String player3Id,
    required String player4Id,
    required Map<String, int> participantRatings,
  }) async {
    final player1Rating = participantRatings[player1Id]!;
    final player2Rating = participantRatings[player2Id]!;
    final player3Rating = participantRatings[player3Id]!;
    final player4Rating = participantRatings[player4Id]!;

    final teamARating = RatingCalculationService.calculateTeamRating(
      player1Rating,
      player2Rating,
    );
    final teamBRating = RatingCalculationService.calculateTeamRating(
      player3Rating,
      player4Rating,
    );

    final expectedScoreA = RatingCalculationService.calculateExpectedScore(
      playerRating: teamARating,
      opponentRating: teamBRating,
    );

    final match = MatchModel(
      id: '',
      eventId: eventId,
      matchNumber: matchNumber,
      teamA: TeamData(
        player1: player1Id,
        player2: player2Id,
        player1Rating: player1Rating,
        player2Rating: player2Rating,
        teamRating: teamARating,
      ),
      teamB: TeamData(
        player1: player3Id,
        player2: player4Id,
        player1Rating: player3Rating,
        player2Rating: player4Rating,
        teamRating: teamBRating,
      ),
      expectedScoreA: expectedScoreA,
      expectedScoreB: 1 - expectedScoreA,
    );

    await _matchRepository.createMatch(match);
  }

  // Helper: Create singles match
  Future<void> _createSinglesMatch({
    required String eventId,
    required int matchNumber,
    required String player1Id,
    required String player2Id,
    required Map<String, int> participantRatings,
  }) async {
    final player1Rating = participantRatings[player1Id]!;
    final player2Rating = participantRatings[player2Id]!;

    final expectedScoreA = RatingCalculationService.calculateExpectedScore(
      playerRating: player1Rating.toDouble(),
      opponentRating: player2Rating.toDouble(),
    );

    final match = MatchModel(
      id: '',
      eventId: eventId,
      matchNumber: matchNumber,
      teamA: TeamData(
        player1: player1Id,
        player1Rating: player1Rating,
        teamRating: player1Rating.toDouble(),
      ),
      teamB: TeamData(
        player1: player2Id,
        player1Rating: player2Rating,
        teamRating: player2Rating.toDouble(),
      ),
      expectedScoreA: expectedScoreA,
      expectedScoreB: 1 - expectedScoreA,
    );

    await _matchRepository.createMatch(match);
  }

  // Submit match result
  Future<void> submitMatchResult({
    required String matchId,
    required int teamAScore,
    required int teamBScore,
  }) async {
    try {
      _status = MatchProviderStatus.updating;
      _errorMessage = null;
      notifyListeners();

      // Validate scores
      if (teamAScore < 0 || teamBScore < 0) {
        throw Exception('Scores cannot be negative');
      }
      if (teamAScore == teamBScore) {
        throw Exception('Scores cannot be tied. Please enter a winner.');
      }

      final match = await _matchRepository.getMatchById(matchId);
      final winner = teamAScore > teamBScore ? 'teamA' : 'teamB';

      // Calculate rating changes
      final ratingChangeA = RatingCalculationService.calculateRatingChange(
        currentRating: match.teamA.teamRating,
        opponentRating: match.teamB.teamRating,
        won: winner == 'teamA',
      );

      final ratingChangeB = RatingCalculationService.calculateRatingChange(
        currentRating: match.teamB.teamRating,
        opponentRating: match.teamA.teamRating,
        won: winner == 'teamB',
      );

      // Update match
      final updatedMatch = match.copyWith(
        teamA: match.teamA.copyWith(score: teamAScore),
        teamB: match.teamB.copyWith(score: teamBScore),
        winner: winner,
        status: MatchStatus.completed,
        ratingChangeA: ratingChangeA,
        ratingChangeB: ratingChangeB,
        completedAt: DateTime.now(),
      );

      await _matchRepository.updateMatch(updatedMatch);

      // Update player ratings
      await _updatePlayerRatings(updatedMatch);

      // Check if all matches in event are completed
      await _checkEventCompletion(match.eventId);

      _selectedMatch = updatedMatch;
      _status = MatchProviderStatus.loaded;
    } catch (e) {
      _status = MatchProviderStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Helper: Update player ratings after match completion
  Future<void> _updatePlayerRatings(MatchModel match) async {
    final playersToUpdate = <String, double>{};

    // Collect all players and their rating changes
    if (match.teamA.player1 != null) {
      playersToUpdate[match.teamA.player1!] = match.ratingChangeA ?? 0;
    }
    if (match.teamA.player2 != null) {
      playersToUpdate[match.teamA.player2!] = match.ratingChangeA ?? 0;
    }
    if (match.teamB.player1 != null) {
      playersToUpdate[match.teamB.player1!] = match.ratingChangeB ?? 0;
    }
    if (match.teamB.player2 != null) {
      playersToUpdate[match.teamB.player2!] = match.ratingChangeB ?? 0;
    }

    // Update each player's rating
    for (final entry in playersToUpdate.entries) {
      final userId = entry.key;
      final ratingChange = entry.value;

      try {
        final user = await _userRepository.getUserById(userId);
        if (user != null) {
          final newRating = RatingCalculationService.calculateNewRating(
            currentRating: user.eloRating,
            ratingChange: ratingChange,
          );

          final updatedUser = user.copyWith(
            eloRating: newRating,
            ratingTier: RatingTier.fromRating(newRating),
            updatedAt: DateTime.now(),
          );

          await _userRepository.updateUser(updatedUser);
        }
      } catch (e) {
        // Log error but don't fail the entire operation
        debugPrint('Failed to update rating for user $userId: $e');
      }
    }
  }

  // Helper: Check if all matches are completed and update event status
  Future<void> _checkEventCompletion(String eventId) async {
    try {
      final eventMatches = await _matchRepository.getEventMatches(eventId);
      final allCompleted = eventMatches.every(
            (match) => match.status == MatchStatus.completed,
      );

      if (allCompleted && eventMatches.isNotEmpty) {
        final event = await _eventRepository.getEventById(eventId);
        if (event != null && event.status != EventStatus.completed) {
          await _eventRepository.updateEvent(
            event.copyWith(status: EventStatus.completed),
          );
        }
      }
    } catch (e) {
      // Log error but don't fail
      debugPrint('Failed to check event completion: $e');
    }
  }

  // Get pending matches
  List<MatchModel> get pendingMatches {
    return _matches
        .where((match) => match.status == MatchStatus.pending)
        .toList();
  }

  // Get completed matches
  List<MatchModel> get completedMatches {
    return _matches
        .where((match) => match.status == MatchStatus.completed)
        .toList();
  }

  // Get matches for a specific player
  List<MatchModel> getPlayerMatches(String playerId) {
    return _matches.where((match) {
      return match.teamA.player1 == playerId ||
          match.teamA.player2 == playerId ||
          match.teamB.player1 == playerId ||
          match.teamB.player2 == playerId;
    }).toList();
  }

  // Get match statistics for a player in an event
  Map<String, dynamic> getPlayerMatchStats(String playerId) {
    final playerMatches = getPlayerMatches(playerId);
    final completedPlayerMatches = playerMatches
        .where((match) => match.status == MatchStatus.completed)
        .toList();

    int wins = 0;
    int losses = 0;
    double totalRatingChange = 0;

    for (final match in completedPlayerMatches) {
      final isTeamA = match.teamA.player1 == playerId ||
          match.teamA.player2 == playerId;

      if (isTeamA) {
        if (match.winner == 'teamA') {
          wins++;
        } else {
          losses++;
        }
        totalRatingChange += match.ratingChangeA ?? 0;
      } else {
        if (match.winner == 'teamB') {
          wins++;
        } else {
          losses++;
        }
        totalRatingChange += match.ratingChangeB ?? 0;
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
          (m) => m.id == matchId,
      orElse: () => _selectedMatch!,
    );

    return match.teamA.player1 == userId ||
        match.teamA.player2 == userId ||
        match.teamB.player1 == userId ||
        match.teamB.player2 == userId;
  }

  // Get match result for a specific player
  String? getPlayerResult(String matchId, String playerId) {
    final match = _matches.firstWhere(
          (m) => m.id == matchId,
      orElse: () => _selectedMatch!,
    );

    if (match.status != MatchStatus.completed) {
      return null;
    }

    final isTeamA = match.teamA.player1 == playerId ||
        match.teamA.player2 == playerId;

    if (isTeamA) {
      return match.winner == 'teamA' ? 'Win' : 'Loss';
    } else {
      return match.winner == 'teamB' ? 'Win' : 'Loss';
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
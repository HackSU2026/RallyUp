import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:rally_up/provider/match.dart';
import 'package:rally_up/data/match.dart';

class MatchTestScreen extends StatefulWidget {
  const MatchTestScreen({super.key});

  @override
  State<MatchTestScreen> createState() => _MatchTestScreenState();
}

class _MatchTestScreenState extends State<MatchTestScreen> {
 final String testUid = 'TEST_UID_1';

  final TextEditingController _eventIdCtrl =
  TextEditingController(text: 'event_demo');
  final TextEditingController _matchIdCtrl = TextEditingController();

  String _log = '';

  void _setLog(String msg) {
    setState(() => _log = msg);
  }

  Future<void> _createMatch() async {
    final mp = context.read<MatchProvider>();

    final match = MatchModel(
      mid: '', // Firestore auto id
      eventId: _eventIdCtrl.text.trim().isEmpty ? 'event_demo' : _eventIdCtrl.text.trim(),
      matchNumber: DateTime.now().millisecondsSinceEpoch,
      playerTeam: {
        testUid: 1,
        'TEST_UID_2': 2,
      },
      createdAt: DateTime.now(),
    );

    // final created = await mp.createMatch(match);
    //
    // _matchIdCtrl.text = created.mid;
    // _setLog('Created match: ${created.mid}');
  }

  Future<void> _fetchByUid() async {
    final mp = context.read<MatchProvider>();
    await mp.fetchMatchesByUid(testUid);
    _setLog('Fetched by uid=$testUid: ${mp.matches.length} matches');
  }

  Future<void> _updateFirstMatch() async {
    final mp = context.read<MatchProvider>();

    if (mp.matches.isEmpty) {
      _setLog('No matches in cache. Fetch first.');
      return;
    }

    final first = mp.matches.first;

    final updated = first.copyWith(
      score: const [2, 4],
      winner: MatchWinnerSide.teamB,
      status: MatchStatus.completed,
      completedAt: DateTime.now(),
      ratingChangeA: -20,
      ratingChangeB: 20,
    );

    await mp.updateMatch(updated);
    _setLog('Updated match: ${updated.mid} -> completed');
  }

  Future<void> _fetchByEventId() async {
    final mp = context.read<MatchProvider>();
    final eventId = _eventIdCtrl.text.trim();
    if (eventId.isEmpty) {
      _setLog('eventId is empty');
      return;
    }

    final result = await mp.fetchMatchesByEventId(eventId);
    _setLog('Fetched by eventId=$eventId: ${result.length} matches');
  }

  Future<void> _fetchByMatchId() async {
    final mp = context.read<MatchProvider>();
    final matchId = _matchIdCtrl.text.trim();
    if (matchId.isEmpty) {
      _setLog('matchId is empty');
      return;
    }

    final match = await mp.fetchMatchById(matchId);
    if (match == null) {
      _setLog('Match not found: $matchId');
      return;
    }

    _setLog('Fetched match: ${match.mid} (eventId=${match.eventId}, status=${match.status.name})');
  }

  @override
  void dispose() {
    _eventIdCtrl.dispose();
    _matchIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MatchProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Match Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Inputs
            TextField(
              controller: _eventIdCtrl,
              decoration: const InputDecoration(
                labelText: 'eventId',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _matchIdCtrl,
              decoration: const InputDecoration(
                labelText: 'matchId (doc id)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Buttons
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton(
                  onPressed: mp.isLoading ? null : _createMatch,
                  child: const Text('Create Match'),
                ),
                ElevatedButton(
                  onPressed: mp.isLoading ? null : _fetchByUid,
                  child: const Text('Fetch by UID'),
                ),
                ElevatedButton(
                  onPressed: mp.isLoading ? null : _updateFirstMatch,
                  child: const Text('Update First Match'),
                ),
                ElevatedButton(
                  onPressed: mp.isLoading ? null : _fetchByEventId,
                  child: const Text('Fetch by EventId'),
                ),
                ElevatedButton(
                  onPressed: mp.isLoading ? null : _fetchByMatchId,
                  child: const Text('Fetch by MatchId'),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Text('Loading: ${mp.isLoading}'),
                const SizedBox(width: 12),
                Text('Cache: ${mp.matches.length}'),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _log,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const Divider(),

            // List
            Expanded(
              child: ListView.builder(
                itemCount: mp.matches.length,
                itemBuilder: (context, index) {
                  final m = mp.matches[index];
                  final scoreText = (m.score == null || m.score!.length != 2)
                      ? '-'
                      : '${m.score![0]}:${m.score![1]}';

                  return ListTile(
                    title: Text('Match #${m.matchNumber} (${m.status.name})'),
                    subtitle: Text(
                      'id=${m.mid}\n'
                          'eventId=${m.eventId}  score=$scoreText  winner=${m.winner?.name ?? "-"}\n'
                          'players=${m.playerTeam}',
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

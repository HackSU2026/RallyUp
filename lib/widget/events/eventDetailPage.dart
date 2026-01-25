import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:rally_up/data/event.dart';
import 'package:rally_up/provider/event.dart';

// Adjust these imports to your actual paths/names
import 'package:rally_up/provider/match.dart'; // MatchProvider
import 'package:rally_up/data/match.dart'; // MatchModel / MatchStatus / MatchWinnerSide

/// Toggle dummy mode for UI testing.
/// - true: no Firestore/provider calls for matches/events, uses dummy data
/// - false: uses EventProvider + MatchProvider to load real data
const bool kUseDummyData = true;

class EventDetailPage extends StatefulWidget {
  final String eventId;

  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  String? _matchesLoadedForEventId;

  @override
  void initState() {
    super.initState();

    // Only load from Firestore when not in dummy mode
    if (!kUseDummyData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<EventProvider>().loadEvent(widget.eventId);
      });
    }
  }

  Future<void> _ensureMatchesLoadedIfCompetition(EventModel event) async {
    if (event.eventType != EventType.match) return;

    // Prevent re-fetching on every build
    if (_matchesLoadedForEventId == event.id) return;
    _matchesLoadedForEventId = event.id;

    await context.read<MatchProvider>().fetchMatchesByEventId(event.id);
  }

  Future<void> _showSubmitScoreDialog(MatchModel match) async {
    final team1Ctrl = TextEditingController();
    final team2Ctrl = TextEditingController();

    final result = await showDialog<List<int>?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Submit Score'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: team1Ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Team 1 score',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: team2Ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Team 2 score',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final s1 = int.tryParse(team1Ctrl.text.trim());
                final s2 = int.tryParse(team2Ctrl.text.trim());

                if (s1 == null || s2 == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid numbers')),
                  );
                  return;
                }
                Navigator.pop(ctx, [s1, s2]);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    final s1 = result[0];
    final s2 = result[1];

    // Decide winner (tie -> null)
    MatchWinnerSide? winner;
    if (s1 > s2) winner = MatchWinnerSide.teamA; // Team 1
    if (s2 > s1) winner = MatchWinnerSide.teamB; // Team 2

    final updated = match.copyWith(
      score: [s1, s2],
      winner: winner,
      status: MatchStatus.completed,
      completedAt: DateTime.now(),
    );

    // Only update Firestore when not in dummy mode
    if (!kUseDummyData) {
      await context.read<MatchProvider>().updateMatch(updated);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Score submitted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ----------------------------
    // Resolve event (dummy vs real)
    // ----------------------------
    final EventModel event;
    if (kUseDummyData) {
      event = buildDummyEvent();
    } else {
      final ep = context.watch<EventProvider>();

      if (ep.status == EventProviderStatus.loading ||
          ep.status == EventProviderStatus.initial) {
        return Scaffold(
          appBar: AppBar(title: const Text('Event Detail')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      if (ep.status == EventProviderStatus.error) {
        return Scaffold(
          appBar: AppBar(title: const Text('Event Detail')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(ep.errorMessage ?? 'Unknown error'),
            ),
          ),
        );
      }

      final selected = ep.selectedEvent;
      if (selected == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Event Detail')),
          body: const Center(child: Text('Event not found')),
        );
      }

      event = selected;

      // Load matches only in real mode
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureMatchesLoadedIfCompetition(event);
      });
    }

    // -----------------------------------
    // Resolve matches (dummy vs real mode)
    // -----------------------------------
    final bool isMatchLoading;
    final List<MatchModel> eventMatches;

    if (kUseDummyData) {
      isMatchLoading = false;
      eventMatches = buildDummyMatches();
    } else {
      final mp = context.watch<MatchProvider>();
      isMatchLoading = mp.isLoading;
      eventMatches = mp.matches.where((m) => m.eventId == event.id).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(event.title.isEmpty ? 'Event Detail' : event.title),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (kUseDummyData) return;

          await context.read<EventProvider>().loadEvent(widget.eventId);
          if (event.eventType == EventType.match) {
            await context.read<MatchProvider>().fetchMatchesByEventId(event.id);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderCard(event: event),
            const SizedBox(height: 12),

            _SectionCard(
              title: 'Time',
              children: [
                _kv('Start', _fmtDateTime(event.startAt)),
                _kv('End', _fmtDateTime(event.endAt)),
              ],
            ),
            const SizedBox(height: 12),

            _SectionCard(
              title: 'Location',
              children: [
                _kv('Location', event.location.isEmpty ? '-' : event.location),
              ],
            ),
            const SizedBox(height: 12),

            _SectionCard(
              title: 'Rules',
              children: [
                _kv('Variant', event.variant.displayName),
                _kv('Max Participants', event.maxParticipants.toString()),
                _kv('Rating Range',
                    '${event.ratingRange.min} ~ ${event.ratingRange.max}'),
                _kv('Spots Left', event.spotsLeft.toString()),
                _kv('Can Join', event.canJoin ? 'Yes' : 'No'),
              ],
            ),
            const SizedBox(height: 12),

            _SectionCard(
              title: 'Participants',
              children: [
                _kv('Host ID', event.hostId),
                _kv('Count',
                    '${event.participants.length}/${event.maxParticipants}'),
                const SizedBox(height: 8),
                ..._buildChips(
                  event.participants.isEmpty
                      ? const ['(none)']
                      : event.participants,
                ),
              ],
            ),
            const SizedBox(height: 12),

            _SectionCard(
              title: event.eventType == EventType.match
                  ? 'Matches (Competition)'
                  : 'Matches',
              children: [
                if (event.eventType != EventType.match) ...[
                  _kv(
                    'Match IDs',
                    (event.matches == null || event.matches!.isEmpty)
                        ? '(none)'
                        : '',
                  ),
                  const SizedBox(height: 8),
                  ..._buildChips(event.matches ?? const []),
                ] else ...[
                  if (isMatchLoading && eventMatches.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                  if (!isMatchLoading && eventMatches.isEmpty)
                    const Text('(no matches found for this event)'),
                  ...eventMatches.map((m) {
                    final team1 = m.playerTeam.entries
                        .where((e) => e.value == 1)
                        .map((e) => e.key)
                        .toList();

                    final team2 = m.playerTeam.entries
                        .where((e) => e.value == 2)
                        .map((e) => e.key)
                        .toList();

                    final scoreText =
                    (m.score == null || m.score!.length != 2)
                        ? '-'
                        : '${m.score![0]} : ${m.score![1]}';

                    final bool assigned = team1.isNotEmpty && team2.isNotEmpty;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Match #${m.matchNumber}  (${m.status.name})',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text('Score: $scoreText'),
                                ],
                              ),
                              const SizedBox(height: 10),

                              const Text(
                                'Team 1',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (team1.isEmpty
                                    ? const ['(not assigned)']
                                    : team1)
                                    .map((s) => Chip(label: Text(s)))
                                    .toList(),
                              ),

                              const SizedBox(height: 10),
                              const Text(
                                'Team 2',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (team2.isEmpty
                                    ? const ['(not assigned)']
                                    : team2)
                                    .map((s) => Chip(label: Text(s)))
                                    .toList(),
                              ),

                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: (isMatchLoading || !assigned)
                                      ? null
                                      : () => _showSubmitScoreDialog(m),
                                  child: const Text('Submit Score'),
                                ),
                              ),
                              if (!assigned)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Teams not assigned yet.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
            const SizedBox(height: 12),

            _SectionCard(
              title: 'Meta',
              children: [
                _kv('Event ID', event.id),
                _kv('Created', _fmtDateTime(event.createdAt)),
                _kv('Updated', _fmtDateTime(event.updatedAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  static List<Widget> _buildChips(List<String> items) {
    if (items.isEmpty) return [const Text('(none)')];
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((s) => Chip(label: Text(s))).toList(),
      ),
    ];
  }

  static String _fmtDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _HeaderCard extends StatelessWidget {
  final EventModel event;

  const _HeaderCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title.isEmpty ? '(Untitled Event)' : event.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill('Type', event.eventType.displayName),
                _pill('Status', event.status.displayName),
                _pill('Variant', event.variant.displayName),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

// =====================
// Dummy data for UI test
// =====================

EventModel buildDummyEvent() {
  return EventModel(
    id: 'dummy_event_001',
    title: 'Weekend Pickleball Competition',
    eventType: EventType.match,
    hostId: 'HOST_UID_001',
    location: 'Seattle Community Court',
    variant: EventVariant.doubles,
    ratingRange: RatingRange(min: 1200, max: 1600),
    maxParticipants: 8,
    participants: const [
      'HOST_UID_001',
      'USER_A',
      'USER_B',
      'USER_C',
      'USER_D',
      'USER_E',
      'USER_F',
    ],
    matches: const [
      'dummy_match_001',
      'dummy_match_002',
    ],
    status: EventStatus.inProgress,
    startAt: DateTime.now().add(const Duration(hours: 2)),
    endAt: DateTime.now().add(const Duration(hours: 5)),
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
  );
}

List<MatchModel> buildDummyMatches() {
  return [
    MatchModel(
      mid: 'dummy_match_001',
      eventId: 'dummy_event_001',
      matchNumber: 1,
      playerTeam: const {
        'USER_A': 1,
        'USER_B': 1,
        'USER_C': 2,
        'USER_D': 2,
      },
      score: null,
      winner: null,
      status: MatchStatus.pending,
      expectedScoreA: 0.5,
      expectedScoreB: 0.5,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    MatchModel(
      mid: 'dummy_match_002',
      eventId: 'dummy_event_001',
      matchNumber: 2,
      playerTeam: const {
        'USER_E': 1,
        'USER_F': 1,
        'HOST_UID_001': 2,
        'USER_A': 2,
      },
      score: const [11, 8],
      winner: MatchWinnerSide.teamA,
      status: MatchStatus.completed,
      expectedScoreA: 0.55,
      expectedScoreB: 0.45,
      ratingChangeA: 20,
      ratingChangeB: -20,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      completedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];
}

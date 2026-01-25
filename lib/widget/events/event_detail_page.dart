import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:rally_up/data/event.dart';
import 'package:rally_up/provider/event.dart';
import 'package:rally_up/provider/match.dart';
import 'package:rally_up/data/match.dart';
import 'package:rally_up/provider/user.dart';
import 'package:url_launcher/url_launcher.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvent(widget.eventId);
    });
  }

  Future<void> _ensureMatchesLoadedIfCompetition(EventModel event) async {
    if (event.eventType != EventType.match) return;
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
          title: const Text('Submit Match Score'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: team1Ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Team 1 Score', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: team2Ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Team 2 Score', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final s1 = int.tryParse(team1Ctrl.text.trim());
                final s2 = int.tryParse(team2Ctrl.text.trim());
                if (s1 != null && s2 != null) Navigator.pop(ctx, [s1, s2]);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    final s1 = result[0], s2 = result[1];
    MatchWinnerSide? winner = s1 > s2 ? MatchWinnerSide.teamA : (s2 > s1 ? MatchWinnerSide.teamB : null);

    final updated = match.copyWith(
      score: [s1, s2],
      winner: winner,
      status: MatchStatus.completed,
      completedAt: DateTime.now(),
    );

    await context.read<MatchProvider>().updateMatch(updated);
  }

  @override
  Widget build(BuildContext context) {
    final ep = context.watch<EventProvider>();
    final mp = context.watch<MatchProvider>();

    if (ep.status == EventProviderStatus.loading || ep.status == EventProviderStatus.initial) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final event = ep.selectedEvent;
    if (event == null) return const Scaffold(body: Center(child: Text('Event not found')));

    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureMatchesLoadedIfCompetition(event));
    final eventMatches = mp.matches.where((m) => m.eventId == event.id).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Event Details', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ep.loadEvent(widget.eventId);
          if (event.eventType == EventType.match) await mp.fetchMatchesByEventId(event.id);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildHeader(event),
            const SizedBox(height: 24),
            _buildInfoSection(event),
            const SizedBox(height: 24),
            _buildParticipantsSection(event),
            const SizedBox(height: 24),
            _buildMatchesSection(event, eventMatches, mp.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(EventModel event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(event.title.isEmpty ? 'Untitled Event' : event.title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            _badge(event.eventType.displayName, Colors.deepPurple),
            const SizedBox(width: 8),
            _badge(event.variant.displayName, Colors.blue),
            const SizedBox(width: 8),
            _badge(event.status.displayName, Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoSection(EventModel event) {
    return _sectionCard(
      title: 'Information',
      icon: Icons.info_outline,
      content: Column(
        children: [
          _rowInfo(Icons.calendar_today, 'Time', '${_fmt(event.startAt)} - ${_fmt(event.endAt)}'),
          _rowLink(Icons.location_on, 'Location', event.location),
          _rowInfo(Icons.rule, 'Format', '${event.variant.displayName} · Rating ${event.ratingRange.min}-${event.ratingRange.max}'),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection(EventModel event) {
    return _sectionCard(
      title: 'Participants (${event.participants.length}/${event.maxParticipants})',
      icon: Icons.people_outline,
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: event.participants.isEmpty
            ? [const Text('No participants yet', style: TextStyle(color: Colors.grey))]
            : event.participants.map((uid) => _UserNameChip(uid: uid)).toList(),
      ),
    );
  }

  Widget _buildMatchesSection(EventModel event, List<MatchModel> matches, bool isLoading) {
    if (event.eventType != EventType.match) return const SizedBox.shrink();

    return _sectionCard(
      title: 'Tournament Matches',
      icon: Icons.emoji_events_outlined,
      content: isLoading && matches.isEmpty
          ? const Center(child: LinearProgressIndicator())
          : Column(
        children: matches.isEmpty
            ? [const Text('Matches will be generated once full.', style: TextStyle(color: Colors.grey))]
            : matches.map((m) => _MatchTile(match: m, onAction: () => _showSubmitScoreDialog(m))).toList(),
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          content,
        ],
      ),
    );
  }

  Widget _rowInfo(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _rowLink(IconData icon, String label, String url) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: _rowInfo(icon, label, url.isEmpty ? '-' : url),
    );
  }

  String _fmt(DateTime dt) => '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
}

class _MatchTile extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onAction;
  const _MatchTile({required this.match, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final t1 = match.playerTeam.entries.where((e) => e.value == 1).map((e) => e.key).toList();
    final t2 = match.playerTeam.entries.where((e) => e.value == 2).map((e) => e.key).toList();
    final isDone = match.status == MatchStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Match #${match.matchNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              if (isDone) const Icon(Icons.check_circle, color: Colors.green, size: 16)
              else TextButton(onPressed: onAction, child: const Text('Submit Score', style: TextStyle(fontSize: 12))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Wrap(spacing: 4, children: t1.map((id) => _UserNameChip(uid: id, small: true)).toList())),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(isDone ? '${match.score![0]} : ${match.score![1]}' : 'VS',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Expanded(child: Wrap(alignment: WrapAlignment.end, spacing: 4, children: t2.map((id) => _UserNameChip(uid: id, small: true)).toList())),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserNameChip extends StatelessWidget {
  final String uid;
  final bool small;
  const _UserNameChip({required this.uid, this.small = false});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: context.read<ProfileProvider>().fetchUserProfile(uid),
      builder: (ctx, snap) {
        final name = snap.data?.displayName ?? '...';
        return Container(
          padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 2 : 6),
          decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
          child: Text(name, style: TextStyle(fontSize: small ? 11 : 13, color: Colors.deepPurple, fontWeight: FontWeight.w500)),
        );
      },
    );
  }
}
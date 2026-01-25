import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:rally_up/provider/history_event.dart';
import 'package:rally_up/data/event.dart';
import 'package:rally_up/data/match.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryEventsPage extends StatefulWidget {
  final String uid;

  const HistoryEventsPage({super.key, required this.uid});

  @override
  State<HistoryEventsPage> createState() => _HistoryEventsPageState();
}

class _HistoryEventsPageState extends State<HistoryEventsPage> {
  String? _loadedForUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // uid 是從 widget 傳進來的
    final uid = widget.uid;

    if (_loadedForUid != uid) {
      _loadedForUid = uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<HistoryEventProvider>().loadHistory(uid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;
    final hp = context.watch<HistoryEventProvider>();

    if (hp.status == HistoryProviderStatus.loading ||
        hp.status == HistoryProviderStatus.initial) {
      return Scaffold(
        appBar: AppBar(title: const Text('My History')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (hp.status == HistoryProviderStatus.error) {
      return Scaffold(
        appBar: AppBar(title: const Text('My History')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(hp.errorMessage ?? 'Unknown error'),
          ),
        ),
      );
    }

    final items = hp.items;

    return Scaffold(
      appBar: AppBar(title: const Text('My History')),
      body: RefreshIndicator(
        onRefresh: () => context.read<HistoryEventProvider>().refresh(uid),
        child: items.isEmpty
            ? ListView(
          children: [
            SizedBox(height: 120),
            Center(child: Text('No history events')),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final e = item.event;

            return Card(
              child: ExpansionTile(
                title: Text(e.title.isEmpty ? '(Untitled Event)' : e.title),
                subtitle: Text(
                  '${e.eventType.displayName} · ${e.variant.displayName} · ${e.status.displayName}\n'
                      'End: ${_fmtDateTime(e.startAt)}\n'
                      'End: ${_fmtDateTime(e.endAt)}',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  _kvLink('Location', e.location),
                  _kv('Rating Range',
                      '${e.ratingRange.min} ~ ${e.ratingRange.max}'),
                  _kv('Participants',
                      '${e.participants.length}/${e.maxParticipants}'),
                  const SizedBox(height: 12),
                  if (e.eventType != EventType.match)
                    const Text('This event is not a competition.')
                  else
                    _CompetitionMatchesView(matches: item.matches),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
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

class _CompetitionMatchesView extends StatelessWidget {
  final List<MatchModel> matches;

  const _CompetitionMatchesView({required this.matches});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const Text('(No matches found)');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Matches', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...matches.map((m) {
          final team1 = m.playerTeam.entries
              .where((e) => e.value == 1)
              .map((e) => e.key)
              .toList();
          final team2 = m.playerTeam.entries
              .where((e) => e.value == 2)
              .map((e) => e.key)
              .toList();

          final scoreText = (m.score == null || m.score!.length != 2)
              ? '-'
              : '${m.score![0]} : ${m.score![1]}';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
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
                            'Match #${m.matchNumber} (${m.status.name})',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('Final: $scoreText'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Team 1',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (team1.isEmpty ? const ['(not assigned)'] : team1)
                          .map((s) => Chip(label: Text(s)))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    const Text('Team 2',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (team2.isEmpty ? const ['(not assigned)'] : team2)
                          .map((s) => Chip(label: Text(s)))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

Widget _kvLink(String k, String? url) {
  final hasUrl = url != null && url.trim().isNotEmpty;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: hasUrl
              ? InkWell(
            onTap: () async {
              final uri = Uri.tryParse(url);
              if (uri == null) return;

              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(
              url,
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          )
              : const Text('-'),
        ),
      ],
    ),
  );
}
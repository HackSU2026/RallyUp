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
    final scheme = Theme.of(context).colorScheme;

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
          children: const [
            SizedBox(height: 140),
            Icon(Icons.history, size: 44, color: Colors.grey),
            SizedBox(height: 10),
            Center(child: Text('No history events')),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final e = item.event;

            final title = e.title.isEmpty ? '(Untitled Event)' : e.title;

            final bool hasMatch = e.eventType == EventType.match;
            final bool hasAnyScore = item.matches.any(
                  (m) => m.score != null && m.score!.length == 2,
            );

            final String statusLabel =
            (hasMatch && hasAnyScore) ? 'Submitted' : 'Completed';

            final Color statusColor =
            (statusLabel == 'Submitted') ? Colors.blue : Colors.green;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EventCard(
                title: title,
                subtitle: '${e.eventType.displayName} · ${e.variant.displayName}',
                statusText: statusLabel,
                statusColor: statusColor,
                startText: _fmtDateTime(e.startAt),
                endText: _fmtDateTime(e.endAt),
                locationUrl: e.location,
                ratingText: '${e.ratingRange.min} ~ ${e.ratingRange.max}',
                participantsText: '${e.participants.length}/${e.maxParticipants}',
                isCompetition: hasMatch,
                matches: item.matches,
              ),
            );
          },
        ),
      ),
    );
  }

  static Color _statusColor(ColorScheme scheme, String status) {
    final s = status.toLowerCase();
    if (s.contains('cancel')) return scheme.error;
    if (s.contains('finish') || s.contains('complete')) return Colors.green;
    if (s.contains('progress') || s.contains('ongoing')) return Colors.orange;
    if (s.contains('upcoming') || s.contains('scheduled')) return Colors.blue;
    return scheme.primary;
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

class _EventCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String statusText;
  final Color statusColor;

  final String startText;
  final String endText;

  final String? locationUrl;
  final String ratingText;
  final String participantsText;

  final bool isCompetition;
  final List<MatchModel> matches;

  const _EventCard({
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.statusColor,
    required this.startText,
    required this.endText,
    required this.locationUrl,
    required this.ratingText,
    required this.participantsText,
    required this.isCompetition,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // 保留擴充點：未來可點擊進入 event detail
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusChip(text: statusText, color: statusColor),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Info grid
              _InfoRow(
                icon: Icons.play_circle_outline,
                label: 'Start',
                value: startText,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.stop_circle_outlined,
                label: 'End',
                value: endText,
              ),
              const SizedBox(height: 8),
              _InfoRowLink(
                icon: Icons.location_on_outlined,
                label: 'Location',
                url: locationUrl,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.bar_chart_outlined,
                label: 'Rating',
                value: ratingText,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.group_outlined,
                label: 'Participants',
                value: participantsText,
              ),

              const SizedBox(height: 14),
              Divider(height: 1, color: scheme.outlineVariant),
              const SizedBox(height: 12),

              if (!isCompetition)
                Text(
                  'This event is not a competition.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                _CompetitionMatchesView(matches: matches),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRowLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? url;

  const _InfoRowLink({
    required this.icon,
    required this.label,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasUrl = url != null && url!.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: hasUrl
              ? InkWell(
            onTap: () async {
              final uri = Uri.tryParse(url!.trim());
              if (uri == null) return;
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              }
            },
            child: Text(
              url!.trim(),
              style: TextStyle(
                color: scheme.primary,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
              : Text(
            '-',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompetitionMatchesView extends StatelessWidget {
  final List<MatchModel> matches;

  const _CompetitionMatchesView({required this.matches});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (matches.isEmpty) {
      return Text(
        '(No matches found)',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Matches',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: match # / status / score
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Match #${m.matchNumber}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Text(
                          m.status.name,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(Icons.scoreboard_outlined,
                          size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        'Final: $scoreText',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _TeamBlock(
                    title: 'Team 1',
                    players:
                    team1.isEmpty ? const ['(not assigned)'] : team1,
                  ),
                  const SizedBox(height: 10),
                  _TeamBlock(
                    title: 'Team 2',
                    players:
                    team2.isEmpty ? const ['(not assigned)'] : team2,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _TeamBlock extends StatelessWidget {
  final String title;
  final List<String> players;

  const _TeamBlock({required this.title, required this.players});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: players
              .map((s) => Chip(
            label: Text(s),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ))
              .toList(),
        ),
      ],
    );
  }
}

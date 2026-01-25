import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:rally_up/provider/history_event.dart';
import 'package:rally_up/provider/user.dart';
import 'package:rally_up/provider/match.dart';
import 'package:rally_up/data/user.dart';
import 'package:rally_up/data/event.dart';
import 'package:rally_up/data/match.dart';
import 'package:rally_up/utils/elo.dart';


enum _HistoryFilter { all, completed, submitted }

class HistoryEventsPage extends StatefulWidget {
  final String uid;

  const HistoryEventsPage({super.key, required this.uid});

  @override
  State<HistoryEventsPage> createState() => _HistoryEventsPageState();
}

class _HistoryEventsPageState extends State<HistoryEventsPage> {
  String? _loadedForUid;
  _HistoryFilter _filter = _HistoryFilter.all;

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

  String _statusLabelOf(HistoryEventItem item) {
    final e = item.event;
    final hasMatch = e.eventType == EventType.match;
    final hasAnyScore = item.matches.any((m) => m.score != null && m.score!.length == 2);
    return (hasMatch && hasAnyScore) ? 'Submitted' : 'Completed';
  }

  Color _statusColorOf(String statusLabel) {
    return statusLabel == 'Submitted' ? Colors.blue : Colors.green;
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

    final filtered = items.where((it) {
      final s = _statusLabelOf(it);
      switch (_filter) {
        case _HistoryFilter.all:
          return true;
        case _HistoryFilter.completed:
          return s == 'Completed';
        case _HistoryFilter.submitted:
          return s == 'Submitted';
      }
    }).toList();

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
          itemCount: filtered.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FilterBar(
                  value: _filter,
                  onChanged: (v) => setState(() => _filter = v),
                  total: items.length,
                  shown: filtered.length,
                ),
              );
            }

            final item = filtered[index - 1];
            final e = item.event;

            final title = e.title.isEmpty ? '(Untitled Event)' : e.title;

            final statusLabel = _statusLabelOf(item);
            final statusColor = _statusColorOf(statusLabel);

            final hasMatch = e.eventType == EventType.match;

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
                currentUid: uid,
              ),
            );
          },
        ),
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

class _FilterBar extends StatelessWidget {
  final _HistoryFilter value;
  final ValueChanged<_HistoryFilter> onChanged;
  final int total;
  final int shown;

  const _FilterBar({
    required this.value,
    required this.onChanged,
    required this.total,
    required this.shown,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<_HistoryFilter>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _HistoryFilter.all, label: Text('All')),
                ButtonSegment(value: _HistoryFilter.completed, label: Text('Completed')),
                ButtonSegment(value: _HistoryFilter.submitted, label: Text('Submitted')),
              ],
              selected: {value},
              onSelectionChanged: (set) => onChanged(set.first),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$shown/$total',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
  final String currentUid;

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
    required this.currentUid,
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
        onTap: () {},
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
                _CompetitionMatchesView(
                  matches: matches,
                  currentUid: currentUid,
                ),
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
                await launchUrl(uri, mode: LaunchMode.externalApplication);
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

class _CompetitionMatchesView extends StatefulWidget {
  final List<MatchModel> matches;
  final String currentUid;

  const _CompetitionMatchesView({
    required this.matches,
    required this.currentUid,
  });

  @override
  State<_CompetitionMatchesView> createState() => _CompetitionMatchesViewState();
}

class _CompetitionMatchesViewState extends State<_CompetitionMatchesView> {
  final Map<String, Future<UserProfile?>> _futureCache = {};

  Future<UserProfile?> _profileFuture(String uid) {
    return _futureCache.putIfAbsent(
      uid,
          () => context.read<ProfileProvider>().fetchUserProfile(uid),
    );
  }

  Future<void> _submitScore(MatchModel m) async {
    final aCtrl = TextEditingController();
    final bCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Submit score'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: aCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Team 1 score'),
              ),
              TextField(
                controller: bCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Team 2 score'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final a = int.tryParse(aCtrl.text.trim());
    final b = int.tryParse(bCtrl.text.trim());

    if (a == null || b == null || a < 0 || b < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid score')),
      );
      return;
    }

    await context.read<MatchProvider>().updateMatch(
      m.copyWith(
        score: [a, b],
        status: MatchStatus.completed,
        winner: (a >= b)
            ? MatchWinnerSide.teamA
            : MatchWinnerSide.teamB,
        completedAt: DateTime.now(),
      ),
    );

    final profileProvider = context.read<ProfileProvider>();
    final myProfile = profileProvider.profile;

    if (myProfile != null) {
      final myUid = myProfile.uid;
      final myTeam = m.playerTeam[myUid];

      if (myTeam != null) {
        final winnerTeam = (a >= b) ? 1 : 2;
        final isWin = myTeam == winnerTeam;

        final opponentUids = m.playerTeam.entries
            .where((e) => e.value != myTeam)
            .map((e) => e.key)
            .toList();

        int opponentRating = myProfile.rating;

        if (opponentUids.isNotEmpty) {
          final futures = opponentUids
              .map((uid) => profileProvider.fetchUserProfile(uid))
              .toList();

          final profiles = await Future.wait(futures);
          final ratings = profiles
              .where((p) => p != null)
              .map((p) => p!.rating)
              .toList();

          if (ratings.isNotEmpty) {
            opponentRating =
                (ratings.reduce((x, y) => x + y) / ratings.length).round();
          }
        }

        final delta = calculateEloDelta(
          myRating: myProfile.rating,
          opponentRating: opponentRating,
          isWin: isWin,
          kFactor: 32,
        );

        await profileProvider.applyRatingDelta(delta);
      }
    }


    if (!mounted) return;
    await context
        .read<HistoryEventProvider>()
        .refresh(widget.currentUid);
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final matches = widget.matches;

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
            Icon(Icons.emoji_events_outlined, size: 18, color: scheme.onSurfaceVariant),
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

          final needsSubmit = (m.score == null || m.score!.length != 2);

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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      Icon(Icons.scoreboard_outlined, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        'Final: $scoreText',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (needsSubmit) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        label: const Text('Submit score'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _submitScore(m),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _TeamBlock(
                    title: 'Team 1',
                    uids: team1.isEmpty ? const ['(not assigned)'] : team1,
                    profileFutureOf: _profileFuture,
                  ),
                  const SizedBox(height: 10),
                  _TeamBlock(
                    title: 'Team 2',
                    uids: team2.isEmpty ? const ['(not assigned)'] : team2,
                    profileFutureOf: _profileFuture,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}

class _TeamBlock extends StatelessWidget {
  final String title;
  final List<String> uids;
  final Future<UserProfile?> Function(String uid) profileFutureOf;

  const _TeamBlock({
    required this.title,
    required this.uids,
    required this.profileFutureOf,
  });

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
          children: uids.map((uid) {
            if (uid == '(not assigned)') {
              return Chip(
                label: const Text('(not assigned)'),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }

            return FutureBuilder<UserProfile?>(
              future: profileFutureOf(uid),
              builder: (context, snap) {
                final name = snap.data?.displayName;
                final label = (name != null && name.trim().isNotEmpty) ? name.trim() : 'Player';

                return Chip(
                  label: Text(label),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
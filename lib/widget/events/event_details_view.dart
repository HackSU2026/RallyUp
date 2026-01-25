import 'package:flutter/material.dart';

import '../../data/event.dart';

/// Placeholder screen for viewing/managing event details
/// This screen is shown when a host taps on their event
class EventDetailsView extends StatelessWidget {
  final EventModel event;

  const EventDetailsView({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(event.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Event Details',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Event management features coming soon',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Event info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _InfoRow(
                        icon: Icons.event,
                        label: 'Event',
                        value: event.title,
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.category,
                        label: 'Type',
                        value: '${event.eventType.displayName} - ${event.variant.displayName}',
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.people,
                        label: 'Participants',
                        value: '${event.participants.length}/${event.maxParticipants}',
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.info_outline,
                        label: 'Status',
                        value: event.status.displayName,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

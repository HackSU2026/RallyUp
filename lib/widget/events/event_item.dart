import 'package:flutter/material.dart';

import '../../data/event.dart';
import '../../data/user.dart';

/// Widget displaying a single event in the list
class EventItem extends StatelessWidget {
  final EventModel event;
  final UserProfile? hostProfile;
  final VoidCallback? onTap;
  final String? currentUserId;
  final Future<void> Function(String eventId)? onJoin;
  final bool isJoining;
  /// Indicates if current user is hosting this event (for visual badge)
  /// If null, badge is not shown
  final bool? isHost;

  const EventItem({
    super.key,
    required this.event,
    this.hostProfile,
    this.onTap,
    this.currentUserId,
    this.onJoin,
    this.isJoining = false,
    this.isHost,
  });

  /// Extract location name from Google Maps URL or return as-is
  String _extractLocationName(String location) {
    // Handle Google Maps URLs
    // Format 1: https://maps.google.com/?q=Place+Name
    // Format 2: https://www.google.com/maps/place/Place+Name/...
    // Format 3: https://goo.gl/maps/...

    try {
      final uri = Uri.tryParse(location);
      if (uri == null) return location;

      // Check for place name in path for /maps/place/ URLs
      if (uri.path.contains('/place/')) {
        final pathSegments = uri.pathSegments;
        final placeIndex = pathSegments.indexOf('place');
        if (placeIndex != -1 && placeIndex + 1 < pathSegments.length) {
          // Decode URL-encoded place name
          return Uri.decodeComponent(
            pathSegments[placeIndex + 1].replaceAll('+', ' '),
          );
        }
      }

      // Check for q parameter
      final queryParam = uri.queryParameters['q'];
      if (queryParam != null && queryParam.isNotEmpty) {
        return Uri.decodeComponent(queryParam.replaceAll('+', ' '));
      }

      // Check for query parameter (alternative format)
      final query = uri.queryParameters['query'];
      if (query != null && query.isNotEmpty) {
        return Uri.decodeComponent(query.replaceAll('+', ' '));
      }
    } catch (_) {
      // If parsing fails, return original
    }

    // If it's a short URL or unrecognized format, truncate if too long
    if (location.length > 40) {
      return '${location.substring(0, 37)}...';
    }
    return location;
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  String _formatDate(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}';
  }

  String _formatDateTimeRange(DateTime start, DateTime end) {
    final startDate = _formatDate(start);
    final startTime = _formatTime(start);
    final endTime = _formatTime(end);

    // Check if same day
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return '$startDate, $startTime - $endTime';
    }

    // Different days
    final endDate = _formatDate(end);
    return '$startDate $startTime - $endDate $endTime';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final locationName = _extractLocationName(event.location);
    final dateTimeRange = _formatDateTimeRange(event.startAt, event.endAt);
    final participantCount = event.participants.length;
    final maxParticipants = event.maxParticipants;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Host avatar
              _HostAvatar(hostProfile: hostProfile),
              const SizedBox(width: 12),
              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and variant badge row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Role badge (Hosting/Joined) if applicable
                        if (isHost != null) ...[
                          _RoleBadge(isHost: isHost!),
                          const SizedBox(width: 4),
                        ],
                        _VariantBadge(
                          variant: event.variant,
                          eventType: event.eventType,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Location row
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Date/time row
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateTimeRange,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Participants row
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$participantCount/$maxParticipants going',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: event.isFull
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                            fontWeight:
                                event.isFull ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                        if (event.isFull) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'FULL',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Join button
                    if (onJoin != null && !event.isFull) ...[
                      const SizedBox(height: 12),
                      _JoinButton(
                        onJoin: () => onJoin?.call(event.id),
                        isJoining: isJoining,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Host avatar widget with fallback
class _HostAvatar extends StatelessWidget {
  final UserProfile? hostProfile;

  const _HostAvatar({this.hostProfile});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (hostProfile?.photoURL != null && hostProfile!.photoURL!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(hostProfile!.photoURL!),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    // Fallback: show initials or icon
    final initials = hostProfile?.displayName.isNotEmpty == true
        ? hostProfile!.displayName[0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: 24,
      backgroundColor: colorScheme.primaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}

/// Badge showing event variant and type
class _VariantBadge extends StatelessWidget {
  final EventVariant variant;
  final EventType eventType;

  const _VariantBadge({
    required this.variant,
    required this.eventType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Different colors for match vs practice
    final isMatch = eventType == EventType.match;
    final backgroundColor =
        isMatch ? colorScheme.tertiaryContainer : colorScheme.secondaryContainer;
    final textColor =
        isMatch ? colorScheme.onTertiaryContainer : colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        variant.displayName.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Join button widget for signing up to an event
class _JoinButton extends StatelessWidget {
  final VoidCallback? onJoin;
  final bool isJoining;

  const _JoinButton({
    required this.onJoin,
    required this.isJoining,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.tonal(
        onPressed: isJoining ? null : onJoin,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: const Size(0, 36),
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          disabledBackgroundColor: colorScheme.primaryContainer.withOpacity(0.5),
        ),
        child: isJoining
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onPrimaryContainer,
                ),
              )
            : Text(
                "I'm going",
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

/// Badge showing user's role in the event (Hosting/Joined)
class _RoleBadge extends StatelessWidget {
  final bool isHost;

  const _RoleBadge({required this.isHost});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Different colors for host vs participant
    final backgroundColor = isHost
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final textColor = isHost
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    final icon = isHost ? Icons.star : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: textColor,
          ),
          const SizedBox(width: 3),
          Text(
            isHost ? 'HOST' : 'JOINED',
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../data/event.dart';

/// Role filter options for user's relationship to events
enum RoleFilter {
  all,      // Show both hosted and joined events
  hosting,  // Show only events where user is the host
  joined;   // Show only events where user is a participant (not host)

  String get displayName {
    switch (this) {
      case RoleFilter.all:
        return 'All';
      case RoleFilter.hosting:
        return 'Hosting';
      case RoleFilter.joined:
        return 'Joined';
    }
  }
}

/// Filter criteria for event list
class EventFilter {
  final DateTime? startDateTime;
  final bool matchOnly;
  final bool practiceOnly;
  final RoleFilter roleFilter;

  const EventFilter({
    this.startDateTime,
    this.matchOnly = false,
    this.practiceOnly = false,
    this.roleFilter = RoleFilter.all,
  });

  EventFilter copyWith({
    DateTime? startDateTime,
    bool? matchOnly,
    bool? practiceOnly,
    RoleFilter? roleFilter,
    bool clearDateTime = false,
  }) {
    return EventFilter(
      startDateTime: clearDateTime ? null : (startDateTime ?? this.startDateTime),
      matchOnly: matchOnly ?? this.matchOnly,
      practiceOnly: practiceOnly ?? this.practiceOnly,
      roleFilter: roleFilter ?? this.roleFilter,
    );
  }

  /// Check if any filter is active
  bool get hasActiveFilters =>
      startDateTime != null || matchOnly || practiceOnly || roleFilter != RoleFilter.all;

  /// Apply filter to an event
  /// [currentUserId] is required when role filter is active
  bool matches(EventModel event, {String? currentUserId}) {
    // Filter by event type
    if (matchOnly && event.eventType != EventType.match) {
      return false;
    }
    if (practiceOnly && event.eventType != EventType.practice) {
      return false;
    }

    // Filter by start date/time (show events on or after selected datetime)
    if (startDateTime != null && event.startAt.isBefore(startDateTime!)) {
      return false;
    }

    // Filter by role (only applies when currentUserId is provided)
    if (currentUserId != null && roleFilter != RoleFilter.all) {
      final isHost = event.hostId == currentUserId;
      final isParticipant = event.participants.contains(currentUserId);

      switch (roleFilter) {
        case RoleFilter.hosting:
          if (!isHost) return false;
          break;
        case RoleFilter.joined:
          // Joined means participant but not host
          if (!isParticipant || isHost) return false;
          break;
        case RoleFilter.all:
          break;
      }
    }

    return true;
  }
}

/// FilterBar widget for filtering events
class FilterBar extends StatefulWidget {
  final EventFilter initialFilter;
  final ValueChanged<EventFilter> onFilterChanged;
  /// When true, shows role filter chips (All/Hosting/Joined)
  final bool showRoleFilter;

  const FilterBar({
    super.key,
    this.initialFilter = const EventFilter(),
    required this.onFilterChanged,
    this.showRoleFilter = false,
  });

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  late EventFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  void _updateFilter(EventFilter newFilter) {
    setState(() {
      _filter = newFilter;
    });
    widget.onFilterChanged(newFilter);
  }

  Future<void> _selectDateTime() async {
    // First, pick the date
    final date = await showDatePicker(
      context: context,
      initialDate: _filter.startDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select start date',
    );

    if (date == null || !mounted) return;

    // Then, pick the time
    final time = await showTimePicker(
      context: context,
      initialTime: _filter.startDateTime != null
          ? TimeOfDay.fromDateTime(_filter.startDateTime!)
          : TimeOfDay.now(),
      helpText: 'Select start time',
    );

    if (time == null || !mounted) return;

    // Combine date and time
    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    _updateFilter(_filter.copyWith(startDateTime: dateTime));
  }

  void _clearDateTime() {
    _updateFilter(_filter.copyWith(clearDateTime: true));
  }

  void _toggleMatchOnly(bool selected) {
    _updateFilter(_filter.copyWith(
      matchOnly: selected,
      // Mutually exclusive: if match is selected, deselect practice
      practiceOnly: selected ? false : _filter.practiceOnly,
    ));
  }

  void _togglePracticeOnly(bool selected) {
    _updateFilter(_filter.copyWith(
      practiceOnly: selected,
      // Mutually exclusive: if practice is selected, deselect match
      matchOnly: selected ? false : _filter.matchOnly,
    ));
  }

  void _setRoleFilter(RoleFilter role) {
    _updateFilter(_filter.copyWith(roleFilter: role));
  }

  void _clearAllFilters() {
    _updateFilter(const EventFilter());
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    return '${months[dateTime.month - 1]} ${dateTime.day}, $displayHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date/Time picker row
          Row(
            children: [
              Expanded(
                child: _DateTimeButton(
                  dateTime: _filter.startDateTime,
                  onTap: _selectDateTime,
                  onClear: _filter.startDateTime != null ? _clearDateTime : null,
                  formatDateTime: _formatDateTime,
                ),
              ),
              if (_filter.hasActiveFilters) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _clearAllFilters,
                  child: const Text('Clear all'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Filter chips row
          Row(
            children: [
              FilterChip(
                label: const Text('Match'),
                selected: _filter.matchOnly,
                onSelected: _toggleMatchOnly,
                avatar: _filter.matchOnly
                    ? null
                    : Icon(
                        Icons.sports_tennis,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Practice'),
                selected: _filter.practiceOnly,
                onSelected: _togglePracticeOnly,
                avatar: _filter.practiceOnly
                    ? null
                    : Icon(
                        Icons.fitness_center,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.onPrimaryContainer,
              ),
            ],
          ),
          // Role filter chips (only shown when showRoleFilter is true)
          if (widget.showRoleFilter) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Role:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                ...RoleFilter.values.map((role) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(role.displayName),
                    selected: _filter.roleFilter == role,
                    onSelected: (selected) {
                      if (selected) {
                        _setRoleFilter(role);
                      }
                    },
                    selectedColor: colorScheme.primaryContainer,
                    checkmarkColor: colorScheme.onPrimaryContainer,
                  ),
                )),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Button widget for date/time selection
class _DateTimeButton extends StatelessWidget {
  final DateTime? dateTime;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String Function(DateTime) formatDateTime;

  const _DateTimeButton({
    required this.dateTime,
    required this.onTap,
    this.onClear,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasValue = dateTime != null;

    return Material(
      color: hasValue ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today,
                size: 20,
                color: hasValue
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasValue ? 'From: ${formatDateTime(dateTime!)}' : 'Select date & time',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: hasValue
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClear,
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

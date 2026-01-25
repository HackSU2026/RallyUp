import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../data/event.dart';
import '../../data/user.dart';
import '../../provider/event.dart';
import '../../provider/user.dart';
import '../../provider/match.dart';
import 'filter_bar.dart';
import 'event_item.dart';

/// Main EventList view with FilterBar and paginated list
class EventListView extends StatefulWidget {
  const EventListView({super.key});

  @override
  State<EventListView> createState() => _EventListViewState();
}

class _EventListViewState extends State<EventListView> {
  static const int _pageSize = 10;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  // Filter state
  EventFilter _currentFilter = const EventFilter();

  // Pagination state
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  List<EventModel> _events = [];

  // Host profile cache to avoid redundant fetches
  final Map<String, UserProfile?> _hostProfileCache = {};

  // Track which events are currently being joined
  final Map<String, bool> _joiningEvents = {};

  // Stream subscription key to force refresh
  int _streamKey = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Handle scroll to trigger pagination
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreEvents();
    }
  }

  /// Build the Firestore query for events
  Query<Map<String, dynamic>> _buildQuery({DocumentSnapshot? startAfter}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('events')
        .where('startAt', isGreaterThan: Timestamp.now())
        .orderBy('startAt')
        .limit(_pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query;
  }

  /// Load more events for pagination
  Future<void> _loadMoreEvents() async {
    if (_isLoadingMore || !_hasMoreData || _lastDocument == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final snapshot = await _buildQuery(startAfter: _lastDocument).get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
        });
        return;
      }

      final newEvents = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .where(_shouldShowEvent)
          .toList();

      setState(() {
        _events.addAll(newEvents);
        _lastDocument = snapshot.docs.last;
        _hasMoreData = snapshot.docs.length >= _pageSize;
        _isLoadingMore = false;
      });

      // Fetch host profiles for new events
      _fetchHostProfiles(newEvents);
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  /// Check if event should be shown (not full, not joined, applies filter)
  bool _shouldShowEvent(EventModel event) {
    // Exclude full events
    if (event.isFull) return false;

    // Exclude events user has already joined
    final userId = _currentUserId;
    if (userId != null && event.participants.contains(userId)) {
      return false;
    }

    // Apply current filter
    return _currentFilter.matches(event);
  }

  /// Handle filter changes from FilterBar
  void _onFilterChanged(EventFilter filter) {
    setState(() {
      _currentFilter = filter;
      // Reset pagination when filter changes
      _lastDocument = null;
      _hasMoreData = true;
      _events = [];
      _streamKey++; // Force stream rebuild
    });
  }

  /// Handle pull-to-refresh
  Future<void> _onRefresh() async {
    setState(() {
      _lastDocument = null;
      _hasMoreData = true;
      _events = [];
      _streamKey++; // Force stream rebuild
    });
  }

  /// Fetch host profiles for a list of events
  Future<void> _fetchHostProfiles(List<EventModel> events) async {
    final profileProvider = context.read<ProfileProvider>();
    final hostIds = events.map((e) => e.hostId).toSet();

    for (final hostId in hostIds) {
      if (!_hostProfileCache.containsKey(hostId)) {
        final profile = await profileProvider.fetchUserProfile(hostId);
        if (mounted) {
          setState(() {
            _hostProfileCache[hostId] = profile;
          });
        }
      }
    }
  }

  /// Handle join event action
  Future<void> _handleJoinEvent(String eventId) async {
    final profile = context.read<ProfileProvider>().profile;
    final userId = profile?.uid;
    if (userId == null) return;

    setState(() {
      _joiningEvents[eventId] = true;
    });

    try {
      await context.read<EventProvider>().joinEvent(eventId, userId);

      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();

      if (eventDoc.exists && eventDoc.data() != null) {
        final e = EventModel.fromFirestore(eventDoc);

        final isMatch = e.eventType == EventType.match;
        final isFull = e.participants.length >= e.maxParticipants;

        if (isMatch && isFull) {
          final match = await context
              .read<MatchProvider>()
              .createMatchFromEvent(eventId);

          if (match != null) {
            await context.read<EventProvider>().appendMatchToEvent(
              eventId: eventId,
              matchId: match.mid,
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the event!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _joiningEvents.remove(eventId);
        });
      }
    }
  }


  /// Get current user ID
  String? get _currentUserId => context.read<ProfileProvider>().profile?.uid;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // FilterBar at top
        FilterBar(
          initialFilter: _currentFilter,
          onFilterChanged: _onFilterChanged,
        ),
        // EventList below
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            key: ValueKey(_streamKey),
            stream: _buildQuery().snapshots(),
            builder: (context, snapshot) {
              // Handle loading state
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _events.isEmpty) {
                return const _LoadingState();
              }

              // Handle error state
              if (snapshot.hasError) {
                return _ErrorState(
                  error: snapshot.error.toString(),
                  onRetry: _onRefresh,
                );
              }

              // Process stream data
              if (snapshot.hasData) {
                final docs = snapshot.data!.docs;

                // Update events from stream (first page)
                final streamEvents = docs
                    .map((doc) => EventModel.fromFirestore(doc))
                    .where(_shouldShowEvent)
                    .toList();

                // Store last document for pagination
                if (docs.isNotEmpty && _lastDocument == null) {
                  _lastDocument = docs.last;
                }

                // Merge with paginated events (avoid duplicates)
                final allEvents = <String, EventModel>{};
                for (final event in streamEvents) {
                  allEvents[event.id] = event;
                }
                for (final event in _events) {
                  if (!allEvents.containsKey(event.id)) {
                    // Only add paginated events that pass filter
                    if (_shouldShowEvent(event)) {
                      allEvents[event.id] = event;
                    }
                  }
                }

                final displayEvents = allEvents.values.toList()
                  ..sort((a, b) => a.startAt.compareTo(b.startAt));

                // Fetch host profiles
                _fetchHostProfiles(displayEvents);

                // Handle empty state
                if (displayEvents.isEmpty) {
                  return _EmptyState(
                    hasFilters: _currentFilter.hasActiveFilters,
                    onRefresh: _onRefresh,
                  );
                }

                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: displayEvents.length + (_hasMoreData ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Loading indicator at bottom
                      if (index >= displayEvents.length) {
                        return _isLoadingMore
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : const SizedBox.shrink();
                      }

                      final event = displayEvents[index];
                      final hostProfile = _hostProfileCache[event.hostId];

                      return EventItem(
                        event: event,
                        hostProfile: hostProfile,
                        currentUserId: _currentUserId,
                        onJoin: _handleJoinEvent,
                        isJoining: _joiningEvents[event.id] ?? false,
                        onTap: () {
                          // TODO: Navigate to event details
                        },
                      );
                    },
                  ),
                );
              }

              return const _LoadingState();
            },
          ),
        ),
      ],
    );
  }
}

/// Loading state widget
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading events...'),
        ],
      ),
    );
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onRefresh;

  const _EmptyState({
    required this.hasFilters,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasFilters ? Icons.filter_alt_off : Icons.event_busy,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasFilters ? 'No events match your filters' : 'No upcoming events',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasFilters
                        ? 'Try adjusting your filters'
                        : 'Pull to refresh or check back later',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error state widget
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

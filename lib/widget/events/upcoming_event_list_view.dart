import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../data/event.dart';
import '../../data/user.dart';
import '../../provider/user.dart';
import 'filter_bar.dart';
import 'event_item.dart';
import 'event_details_view.dart';

/// View showing upcoming events that the current user is involved with
/// (as host or participant)
class UpcomingEventListView extends StatefulWidget {
  const UpcomingEventListView({super.key});

  @override
  State<UpcomingEventListView> createState() => _UpcomingEventListViewState();
}

class _UpcomingEventListViewState extends State<UpcomingEventListView> {
  static const int _pageSize = 10;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  // Filter state
  EventFilter _currentFilter = const EventFilter();

  // Loading state
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _error;

  // Events data (merged from both queries)
  List<EventModel> _events = [];
  DocumentSnapshot? _lastHostedDoc;
  DocumentSnapshot? _lastJoinedDoc;

  // Host profile cache
  final Map<String, UserProfile?> _hostProfileCache = {};

  // Stream key for refresh
  int _streamKey = 0;

  // Bottom nav index (0 = Events, 1 = Profile)
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadEvents();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String? get _currentUserId => context.read<ProfileProvider>().profile?.uid;

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreEvents();
    }
  }

  /// Load initial events from both queries
  Future<void> _loadEvents() async {
    final userId = _currentUserId;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Firestore limitation: can't do OR on different fields
      // So we run two queries and merge results:
      // 1. Events where user is host
      // 2. Events where user is participant (includes host)

      final now = Timestamp.now();

      // Query 1: Events user is hosting
      final hostedQuery = _firestore
          .collection('events')
          .where('hostId', isEqualTo: userId)
          .where('startAt', isGreaterThan: now)
          .orderBy('startAt')
          .limit(_pageSize);

      // Query 2: Events user has joined (as participant)
      final joinedQuery = _firestore
          .collection('events')
          .where('participants', arrayContains: userId)
          .where('startAt', isGreaterThan: now)
          .orderBy('startAt')
          .limit(_pageSize);

      final results = await Future.wait([
        hostedQuery.get(),
        joinedQuery.get(),
      ]);

      final hostedSnapshot = results[0];
      final joinedSnapshot = results[1];

      // Merge results (deduplicate by event id)
      final eventsMap = <String, EventModel>{};

      for (final doc in hostedSnapshot.docs) {
        final event = EventModel.fromFirestore(doc);
        eventsMap[event.id] = event;
      }

      for (final doc in joinedSnapshot.docs) {
        final event = EventModel.fromFirestore(doc);
        if (!eventsMap.containsKey(event.id)) {
          eventsMap[event.id] = event;
        }
      }

      // Sort by startAt
      final allEvents = eventsMap.values.toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));

      // Store pagination cursors
      if (hostedSnapshot.docs.isNotEmpty) {
        _lastHostedDoc = hostedSnapshot.docs.last;
      }
      if (joinedSnapshot.docs.isNotEmpty) {
        _lastJoinedDoc = joinedSnapshot.docs.last;
      }

      setState(() {
        _events = allEvents;
        _isLoading = false;
        _hasMoreData = hostedSnapshot.docs.length >= _pageSize ||
            joinedSnapshot.docs.length >= _pageSize;
      });

      // Fetch host profiles
      _fetchHostProfiles(allEvents);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Load more events for pagination
  Future<void> _loadMoreEvents() async {
    if (_isLoadingMore || !_hasMoreData) return;

    final userId = _currentUserId;
    if (userId == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final now = Timestamp.now();
      final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

      // Continue hosted query if we have more
      if (_lastHostedDoc != null) {
        futures.add(_firestore
            .collection('events')
            .where('hostId', isEqualTo: userId)
            .where('startAt', isGreaterThan: now)
            .orderBy('startAt')
            .startAfterDocument(_lastHostedDoc!)
            .limit(_pageSize)
            .get());
      }

      // Continue joined query if we have more
      if (_lastJoinedDoc != null) {
        futures.add(_firestore
            .collection('events')
            .where('participants', arrayContains: userId)
            .where('startAt', isGreaterThan: now)
            .orderBy('startAt')
            .startAfterDocument(_lastJoinedDoc!)
            .limit(_pageSize)
            .get());
      }

      if (futures.isEmpty) {
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
        });
        return;
      }

      final results = await Future.wait(futures);

      // Merge new results
      final eventsMap = <String, EventModel>{};
      for (final event in _events) {
        eventsMap[event.id] = event;
      }

      var gotMore = false;
      var resultIndex = 0;

      if (_lastHostedDoc != null && resultIndex < results.length) {
        final snapshot = results[resultIndex++];
        for (final doc in snapshot.docs) {
          final event = EventModel.fromFirestore(doc);
          eventsMap[event.id] = event;
        }
        if (snapshot.docs.isNotEmpty) {
          _lastHostedDoc = snapshot.docs.last;
          gotMore = true;
        }
      }

      if (_lastJoinedDoc != null && resultIndex < results.length) {
        final snapshot = results[resultIndex++];
        for (final doc in snapshot.docs) {
          final event = EventModel.fromFirestore(doc);
          if (!eventsMap.containsKey(event.id)) {
            eventsMap[event.id] = event;
          }
        }
        if (snapshot.docs.isNotEmpty) {
          _lastJoinedDoc = snapshot.docs.last;
          gotMore = true;
        }
      }

      final allEvents = eventsMap.values.toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));

      setState(() {
        _events = allEvents;
        _hasMoreData = gotMore;
        _isLoadingMore = false;
      });

      _fetchHostProfiles(allEvents);
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  /// Fetch host profiles for events
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

  /// Handle filter changes
  void _onFilterChanged(EventFilter filter) {
    setState(() {
      _currentFilter = filter;
    });
  }

  /// Handle pull-to-refresh
  Future<void> _onRefresh() async {
    _lastHostedDoc = null;
    _lastJoinedDoc = null;
    _events = [];
    _streamKey++;
    await _loadEvents();
  }

  /// Handle event item tap
  void _onEventTap(EventModel event) {
    final userId = _currentUserId;
    if (userId == null) return;

    final isHost = event.hostId == userId;

    if (isHost) {
      // Navigate to event details for hosts
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventDetailsView(event: event),
        ),
      );
    } else {
      // Show snackbar for participants (view only)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are a participant in this event'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Filter events based on current filter
  List<EventModel> get _filteredEvents {
    final userId = _currentUserId;
    return _events.where((event) {
      return _currentFilter.matches(event, currentUserId: userId);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Upcoming Events'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // FilterBar with role filter enabled
          FilterBar(
            key: ValueKey(_streamKey),
            initialFilter: _currentFilter,
            onFilterChanged: _onFilterChanged,
            showRoleFilter: true,
          ),
          // Event list
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (index) {
          if (index == 0) {
            // Go to main Events screen
            Navigator.of(context).pop();
          } else if (index == 1) {
            // Stay on this screen (it's a sub-view of profile)
            Navigator.of(context).pop();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final userId = _currentUserId;

    // Loading state
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your events...'),
          ],
        ),
      );
    }

    // Error state
    if (_error != null) {
      return _buildErrorState();
    }

    final displayEvents = _filteredEvents;

    // Empty state
    if (displayEvents.isEmpty) {
      return _buildEmptyState();
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
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }

          final event = displayEvents[index];
          final hostProfile = _hostProfileCache[event.hostId];
          final isHost = event.hostId == userId;

          return EventItem(
            event: event,
            hostProfile: hostProfile,
            currentUserId: userId,
            isHost: isHost,
            onTap: () => _onEventTap(event),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasFilters = _currentFilter.hasActiveFilters;

    return RefreshIndicator(
      onRefresh: _onRefresh,
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
                    hasFilters
                        ? 'No events match your filters'
                        : 'No upcoming events',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasFilters
                        ? 'Try adjusting your filters'
                        : 'Join or create an event to get started',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
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
              _error ?? 'Unknown error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:rally_up/data/event.dart';
import 'package:rally_up/provider/event.dart';
import 'package:rally_up/provider/user.dart';
import 'package:rally_up/widget/events/event_detail_page.dart';

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  EventType _eventType = EventType.practice;
  EventVariant _variant = EventVariant.doubles;

  int _minRating = 0;
  int _maxRating = 3000;
  bool _ratingInitialized = false;

  int? _competitionHeadcount = 4;

  DateTime? _startAt;
  DateTime? _endAt;

  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  bool get _isCompetition => _eventType == EventType.match;

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _startAt : _endAt) ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    setState(() {
      if (isStart) {
        _startAt = dt;
        if (_endAt != null && _endAt!.isBefore(dt)) _endAt = null;
      } else {
        _endAt = dt;
      }
    });
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit(String uid) async {
    if (_submitting) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_startAt == null || _endAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select startAt and endAt')),
      );
      return;
    }

    if (!_endAt!.isAfter(_startAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('endAt must be after startAt')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final maxParticipants = _isCompetition ? _competitionHeadcount! : 9999;

      final newEvent = EventModel(
        id: '',
        title: _titleCtrl.text.trim().isEmpty
            ? (_isCompetition ? 'Competition' : 'Practice')
            : _titleCtrl.text.trim(),
        eventType: _eventType,
        hostId: uid,
        location: _locationCtrl.text.trim(),
        variant: _variant,
        ratingRange: RatingRange(min: _minRating, max: _maxRating),
        maxParticipants: maxParticipants,
        participants: [uid],
        matches: null,
        status: EventStatus.open,
        startAt: _startAt!,
        endAt: _endAt!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final eventProvider = context.read<EventProvider>();
      final createdId = await eventProvider.createEvent(newEvent);

      if (!mounted) return;

      if (createdId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(eventProvider.errorMessage ?? 'Create failed')),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EventDetailPage(eventId: createdId),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_ratingInitialized) {
      _minRating = profile.rating - 200;
      _maxRating = profile.rating + 200;
      _ratingInitialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Event Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EventType>(
              value: _eventType,
              decoration: const InputDecoration(labelText: 'Event Type', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: EventType.practice, child: Text('Practice')),
                DropdownMenuItem(value: EventType.match, child: Text('Competition')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _eventType = v;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EventVariant>(
              value: _variant,
              decoration: const InputDecoration(labelText: 'Variant', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: EventVariant.singles, child: Text('Singles')),
                DropdownMenuItem(value: EventVariant.doubles, child: Text('Doubles')),
              ],
              onChanged: (v) => setState(() => _variant = v!),
            ),
            const SizedBox(height: 12),
            if (_isCompetition) ...[
              DropdownButtonFormField<int>(
                value: _competitionHeadcount,
                decoration: const InputDecoration(labelText: 'Competition Headcount', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 2, child: Text('2 Players')),
                  DropdownMenuItem(value: 4, child: Text('4 Players')),
                ],
                onChanged: (v) => setState(() => _competitionHeadcount = v),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Location is required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Min Rating',
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    child: Text(_minRating.toString()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Max Rating',
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    child: Text(_maxRating.toString()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Schedule', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: Text('Start: ${_fmt(_startAt)}')),
                        TextButton(
                          onPressed: _submitting ? null : () => _pickDateTime(isStart: true),
                          child: const Text('Pick'),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: Text('End:   ${_fmt(_endAt)}')),
                        TextButton(
                          onPressed: _submitting ? null : () => _pickDateTime(isStart: false),
                          child: const Text('Pick'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: _submitting ? null : () => _submit(profile.uid),
                child: _submitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Create Event', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:rally_up/data/event.dart';
import 'package:rally_up/provider/event.dart';

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();

  final _hostIdCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  EventType _eventType = EventType.practice; // practice / competition(match)
  int? _competitionHeadcount = 4; // competition only: 2 or 4

  DateTime? _startAt;
  DateTime? _endAt;

  bool _submitting = false;

  @override
  void dispose() {
    _hostIdCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  bool get _isCompetition => _eventType == EventType.match;

  Future<void> _pickDateTime({
    required bool isStart,
  }) async {
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
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _submit() async {
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

    if (_isCompetition && (_competitionHeadcount != 2 && _competitionHeadcount != 4)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Competition headcount must be 2 or 4')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final hostId = _hostIdCtrl.text.trim();
      final location = _locationCtrl.text.trim();

      final maxParticipants = _isCompetition ? _competitionHeadcount! : 9999;

      final newEvent = EventModel(
        id: '', // Firestore add() will create id
        title: _isCompetition ? 'Competition' : 'Practice',
        eventType: _eventType,
        hostId: hostId,
        location: location,
        variant: _isCompetition ? EventVariant.doubles : EventVariant.singles,
        ratingRange: RatingRange(min: 0, max: 3000),
        maxParticipants: maxParticipants,
        participants: [hostId],
        matches: null,
        status: EventStatus.open,
        startAt: _startAt!,
        endAt: _endAt!,
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created')),
      );

      Navigator.pop(context, createdId);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _hostIdCtrl,
              decoration: const InputDecoration(
                labelText: 'hostId',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'hostId is required';
                return null;
              },
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<EventType>(
              value: _eventType,
              decoration: const InputDecoration(
                labelText: 'Event type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: EventType.practice,
                  child: Text('Practice'),
                ),
                DropdownMenuItem(
                  value: EventType.match,
                  child: Text('Competition'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _eventType = v;
                  if (!_isCompetition) {
                    _competitionHeadcount = 4;
                  }
                });
              },
            ),
            const SizedBox(height: 12),

            // Headcount: competition -> 2 or 4, practice -> Unlimited (disabled)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Headcount',
                border: OutlineInputBorder(),
              ),
              child: _isCompetition
                  ? DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _competitionHeadcount,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 2, child: Text('2')),
                    DropdownMenuItem(value: 4, child: Text('4')),
                  ],
                  onChanged: (v) => setState(() => _competitionHeadcount = v),
                ),
              )
                  : const Text('Unlimited'),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location (Google Maps URL)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Location is required';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // startAt / endAt pickers
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
                        Expanded(child: Text('startAt: ${_fmt(_startAt)}')),
                        TextButton(
                          onPressed: _submitting ? null : () => _pickDateTime(isStart: true),
                          child: const Text('Pick'),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: Text('endAt:   ${_fmt(_endAt)}')),
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
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? 'Creating...' : 'Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

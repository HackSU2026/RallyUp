import 'package:flutter/material.dart';

import '../../data/event.dart';
import 'package:rally_up/widget/events/eventDetailPage.dart';

class EventDetailButton extends StatelessWidget {
  final String eventId;
  final String? label;
  final ButtonStyle? style;

  const EventDetailButton({
    super.key,
    required this.eventId,
    this.label,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: style,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailPage(eventId: eventId),
          ),
        );
      },
      child: Text(label ?? 'View Event'),
    );
  }
}

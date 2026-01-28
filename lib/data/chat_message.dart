enum ChatRole { user, bot }

class ChatMessage {
  final String text;
  final ChatRole role;
  final DateTime timestamp;
  final String? createdEventId;

  ChatMessage({
    required this.text,
    required this.role,
    DateTime? timestamp,
    this.createdEventId,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Converts to the Gemini history format expected by the Cloud Function.
  Map<String, dynamic> toHistoryEntry() {
    return {
      'role': role == ChatRole.user ? 'user' : 'model',
      'parts': [
        {'text': text}
      ],
    };
  }
}

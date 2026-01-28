import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../data/chat_message.dart';

class ChatProvider with ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;

  /// Cloud Function URL — update after deploying to Firebase.
  /// For local emulator testing, use something like:
  ///   http://127.0.0.1:5001/rallyup-7c3b6/us-central1/chat
  static const String _chatEndpoint =
      'https://us-central1-rallyup-7c3b6.cloudfunctions.net/chat';

  /// Sends a user message to the RallyBot Cloud Function and
  /// appends both the user message and bot response to the list.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Add user message immediately
    _messages.add(ChatMessage(text: trimmed, role: ChatRole.user));
    _isLoading = true;
    notifyListeners();

    try {
      // Get Firebase Auth ID token
      final idToken =
          await FirebaseAuth.instance.currentUser?.getIdToken();

      if (idToken == null) {
        _addBotError('You must be signed in to use the chatbot.');
        return;
      }

      // Build conversation history (exclude the message we just added)
      final history = _messages
          .where((m) => m != _messages.last)
          .map((m) => m.toHistoryEntry())
          .toList();

      // Call Cloud Function
      final response = await http
          .post(
            Uri.parse(_chatEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'message': trimmed,
              'history': history,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _messages.add(ChatMessage(
          text: data['reply'] as String? ?? 'No response.',
          role: ChatRole.bot,
          createdEventId: data['created_event_id'] as String?,
        ));
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMsg = body['error'] as String? ?? 'Unknown error';
        _addBotError('Error: $errorMsg');
      }
    } catch (e) {
      _addBotError('Connection error. Please check your network and try again.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _addBotError(String message) {
    _messages.add(ChatMessage(text: message, role: ChatRole.bot));
    _isLoading = false;
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    notifyListeners();
  }
}

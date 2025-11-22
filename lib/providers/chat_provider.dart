import 'package:flutter/foundation.dart';
import 'package:campus_app/models/chat_model.dart';

// NOTE: In a real app, you would connect this to Firebase Firestore
// using StreamBuilder to fetch real-time messages.

class ChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [
    ChatMessage(
      senderId: 'user1',
      senderName: 'Jane Doe (CR)',
      text: 'Reminder: Assignments for CS201 are due Friday.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isMe: false,
    ),
    ChatMessage(
      senderId: 'current_user',
      senderName: 'You',
      text: 'Got it, thanks for the reminder!',
      timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      isMe: true,
    ),
    ChatMessage(
      senderId: 'user2',
      senderName: 'Physics Group',
      text: 'Is anyone struggling with Newton\'s Laws?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      isMe: false,
    ),
  ];

  List<ChatMessage> get messages => _messages;

  void sendMessage(String text, String senderName, String senderId) {
    final newMessage = ChatMessage(
      senderId: senderId,
      senderName: senderName,
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
    );

    _messages.add(newMessage);
    // In a real app, you would save to Firestore here:
    // FirebaseFirestore.instance.collection('chats').add(newMessage.toMap());

    notifyListeners();
  }
}
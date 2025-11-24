import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ChatMessage> messages = [];

  Stream<List<ChatMessage>> groupChatStream() {
    return _firestore
        .collection('group_chat')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ChatMessage.fromMap(doc.data()))
        .toList());
  }

  Stream<List<ChatMessage>> privateChatStream(String currentUserId, String otherUserId) {
    return _firestore
        .collection('private_chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data()))
          .where((msg) =>
      (msg.senderId == currentUserId && msg.receiverId == otherUserId) ||
          (msg.senderId == otherUserId && msg.receiverId == currentUserId))
          .toList();
    });
  }

  Future<void> sendGroupMessage(String text, String senderName, String senderId) async {
    final message = ChatMessage(
      text: text,
      senderId: senderId,
      senderName: senderName,
      timestamp: DateTime.now(),
      receiverId: null,
    );

    await _firestore.collection('group_chat').add(message.toMap());
  }

  Future<void> sendPrivateMessage(
      String text, String senderName, String senderId, String receiverId) async {
    final message = ChatMessage(
      text: text,
      senderId: senderId,
      senderName: senderName,
      timestamp: DateTime.now(),
      receiverId: receiverId,
    );

    await _firestore.collection('private_chats').add({
      ...message.toMap(),
      'participants': [senderId, receiverId],
    });
  }
}

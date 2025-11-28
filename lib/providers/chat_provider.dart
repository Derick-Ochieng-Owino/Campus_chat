// lib/providers/chat_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart'; // Ensure ChatMessage model is imported

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. Combined Stream for ANY Chat (Group or DM) ---
  Stream<List<ChatMessage>> chatStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId) // Target the specific chat document
        .collection('messages') // Access the messages subcollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ChatMessage.fromMap(doc.data()))
        .toList());
  }

  // --- 2. Simplified Send Message Function ---
  // This function sends a message to the specified chat (group or DM).
  Future<void> sendMessage(
      {required String chatId,
        required String text,
        required String senderName,
        required String senderId,
        String? receiverId // Only needed for DM metadata, not mandatory for firestore write
      }) async {

    final message = ChatMessage(
      text: text,
      senderId: senderId,
      senderName: senderName,
      timestamp: DateTime.now(),
      receiverId: receiverId,
    );

    // Write message to the 'messages' subcollection of the specific chat
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message.toMap());

    // OPTIONAL: Update the main chat document for sorting in ChatHomeScreen
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }
}
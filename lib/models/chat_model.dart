import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String text;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final String? receiverId; // null for group chat

  ChatMessage({
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.receiverId,
  });

  Map<String, dynamic> toMap() => {
    'text': text,
    'senderId': senderId,
    'senderName': senderName,
    'timestamp': Timestamp.fromDate(timestamp),
    'receiverId': receiverId,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      receiverId: map['receiverId'],
    );
  }
}

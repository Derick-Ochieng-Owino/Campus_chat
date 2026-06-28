import 'package:cloud_firestore/cloud_firestore.dart';

class StatusModel {
  final String id;
  final String userId;
  final String userName;
  final String mediaUrl;
  final DateTime expiresAt;

  StatusModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.mediaUrl,
    required this.expiresAt,
  });

  factory StatusModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StatusModel(
      id: doc.id,
      userId: data['userId'],
      userName: data['userName'],
      mediaUrl: data['mediaUrl'],
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
    );
  }
}

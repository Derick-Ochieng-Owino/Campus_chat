import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatListProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> chatsForUser({
    required String uid,
    required bool isAdmin,
  }) {
    final query = isAdmin
        ? _firestore
        .collection('chats')
        .orderBy('lastMessageAt', descending: true)
        : _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true);

    return query.snapshots();
  }
}

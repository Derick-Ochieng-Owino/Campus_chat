// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../models/chat_model.dart';
//
// class ChatService {
//   final _db = FirebaseFirestore.instance;
//
//   Stream<List<ChatMessage>> messageStream(String chatId) {
//     return _db
//         .collection('chats')
//         .doc(chatId)
//         .collection('messages')
//         .orderBy('timestamp', descending: true)
//         .snapshots()
//         .map((s) => s.docs.map(ChatMessage.fromDoc).toList());
//   }
//
//   Future<void> sendMessage({
//     required String chatId,
//     required String text,
//     required String senderId,
//     required String senderName,
//   }) async {
//     await _db
//         .collection('chats')
//         .doc(chatId)
//         .collection('messages')
//         .add({
//       'text': text,
//       'senderId': senderId,
//       'senderName': senderName,
//       'timestamp': FieldValue.serverTimestamp(),
//     });
//   }
// }

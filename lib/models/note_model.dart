import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String title;
  final String url;
  final String uploaderId;
  final String uploaderName;
  final String format;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    required this.url,
    required this.uploaderId,
    required this.uploaderName,
    required this.format,
    required this.createdAt,
  });

  factory Note.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Note(
      id: doc.id,
      title: d['title'] ?? 'Untitled',
      url: d['url'] ?? '',
      uploaderId: d['uploaderId'] ?? '',
      uploaderName: d['uploaderName'] ?? '',
      format: d['format'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
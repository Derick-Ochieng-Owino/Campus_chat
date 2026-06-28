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

  // --- 1. Constructor to read data from Firestore (DocumentSnapshot) ---
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

  // --- 2. Method to convert object to a Map (for JSON serialization/caching) ---
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'uploaderId': uploaderId,
      'uploaderName': uploaderName,
      'format': format,
      // Convert DateTime to ISO 8601 string for reliable JSON serialization
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // --- 3. Factory to create object from a Map (for reading from cache) ---
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled',
      url: json['url'] ?? '',
      uploaderId: json['uploaderId'] ?? '',
      uploaderName: json['uploaderName'] ?? '',
      format: json['format'] ?? '',
      // Parse the ISO 8601 string back into a DateTime object
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
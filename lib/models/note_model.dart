import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String id;
  final String unitCode;
  final String title;
  final String fileUrl; // URL where the file is stored (e.g., Firebase Storage)
  final String fileFormat; // PDF, DOCX, PPT, etc.
  final String uploaderId;
  final String uploaderName;
  final DateTime uploadDate;

  NoteModel({
    required this.id,
    required this.unitCode,
    required this.title,
    required this.fileUrl,
    required this.fileFormat,
    required this.uploaderId,
    required this.uploaderName,
    required this.uploadDate,
  });

  factory NoteModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NoteModel(
      id: doc.id,
      unitCode: data['unitCode'] ?? 'UNKNOWN',
      title: data['title'] ?? 'Untitled Note',
      fileUrl: data['fileUrl'] ?? '',
      fileFormat: data['fileFormat'] ?? 'File',
      uploaderId: data['uploaderId'] ?? 'system',
      uploaderName: data['uploaderName'] ?? 'Uploader',
      uploadDate: (data['uploadDate'] as Timestamp).toDate(),
    );
  }
}
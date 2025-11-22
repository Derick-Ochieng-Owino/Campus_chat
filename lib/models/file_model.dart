import 'package:cloud_firestore/cloud_firestore.dart';

class FileModel {
  final String id;
  final String fileUrl;        // Firebase Storage link
  final String fileName;       // originalName.pdf
  final String unitId;         // refer to units collection
  final String unitName;       // Calculus I
  final String uploaderId;     // UID
  final DateTime uploadedAt;

  FileModel({
    required this.id,
    required this.fileUrl,
    required this.fileName,
    required this.unitId,
    required this.unitName,
    required this.uploaderId,
    required this.uploadedAt,
  });

  factory FileModel.fromMap(String id, Map<String, dynamic> data) {
    return FileModel(
      id: id,
      fileUrl: data["fileUrl"] ?? "",
      fileName: data["fileName"] ?? "",
      unitId: data["unitId"] ?? "",
      unitName: data["unitName"] ?? "",
      uploaderId: data["uploadedBy"] ?? "",
      uploadedAt: (data["uploadedAt"] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "fileUrl": fileUrl,
      "fileName": fileName,
      "unitId": unitId,
      "unitName": unitName,
      "uploadedBy": uploaderId,
      "uploadedAt": uploadedAt,
    };
  }
}

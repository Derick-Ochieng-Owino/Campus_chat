import 'dart:io';
import 'firestore_service.dart';
import 'storage_service.dart';

class FileService {
  final _fs = FirestoreService();
  final _storage = StorageService();

  Future<void> uploadUnitFile({
    required File file,
    required String unitId,
    required String unitName,
    required String uploadedBy,
  }) async {
    final filename = DateTime.now().millisecondsSinceEpoch.toString();
    final ext = file.path.split('.').last;

    final storagePath =
        "uploads/units/$unitName/$filename.$ext";

    final url = await _storage.uploadFile(
      file: file,
      path: storagePath,
    );

    await _fs.files.add({
      "unitId": unitId,
      "unitName": unitName,
      "fileUrl": url,
      "fileType": ext,
      "uploadedBy": uploadedBy,
      "timestamp": DateTime.now(),
    });
  }
}

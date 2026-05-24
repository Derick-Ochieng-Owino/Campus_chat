import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/student_id_model.dart';

class StudentIdService {
  StudentIdService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  Future<StudentIdModel?> getStudentId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists || doc.data() == null) {
        return await getCachedStudentId();
      }

      StudentIdModel model = StudentIdModel.fromMap(user.uid, doc.data()!);

      String? localPath;
      if (model.profilePhotoUrl != null && model.profilePhotoUrl!.isNotEmpty) {
        localPath = await _downloadAndCachePhoto(
          model.profilePhotoUrl!,
          '${user.uid}_student_photo.jpg',
        );
      }

      model = model.copyWith(localPhotoPath: localPath);
      await cacheStudentId(model);

      return model;
    } catch (_) {
      return await getCachedStudentId();
    }
  }

  Future<void> cacheStudentId(StudentIdModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_student_id', jsonEncode(model.toMap()));
  }

  Future<StudentIdModel?> getCachedStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cached_student_id');
    if (raw == null) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return StudentIdModel.fromMap(
        (map['uid'] ?? '').toString(),
        map,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _downloadAndCachePhoto(String url, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');

      if (await file.exists()) {
        return file.path;
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
    } catch (_) {}
    return null;
  }
}
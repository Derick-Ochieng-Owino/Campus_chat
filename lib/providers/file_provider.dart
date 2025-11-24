// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
//
// class FilesProvider with ChangeNotifier {
//   final _db = FirebaseFirestore.instance;
//
//   List<Map<String, dynamic>> _files = [];
//   bool _loading = false;
//
//   List<Map<String, dynamic>> get files => _files;
//   bool get loading => _loading;
//
//   // ────────────────────────────────────────────────
//   // LOAD FILES FOR SPECIFIC UNIT
//   // ────────────────────────────────────────────────
//   Future<void> loadFilesForUnit(String unitId) async {
//     _loading = true;
//     notifyListeners();
//
//     final snap = await _db
//         .collection("files")
//         .where("unitId", isEqualTo: unitId)
//         .orderBy("uploadedAt", descending: true)
//         .get();
//
//     _files = snap.docs.map((d) => ({
//       "id": d.id,
//       ...d.data(),
//     })).toList();
//
//     _loading = false;
//     notifyListeners();
//   }
//
//   // ────────────────────────────────────────────────
//   // STREAM FOR LIVE UPDATES
//   // ────────────────────────────────────────────────
//   Stream<QuerySnapshot> streamFiles(String unitId) {
//     return _db.collection("files")
//         .where("unitId", isEqualTo: unitId)
//         .orderBy("uploadedAt", descending: true)
//         .snapshots();
//   }
// }

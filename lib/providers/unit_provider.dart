import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UnitsProvider with ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _units = [];
  bool _loading = false;

  List<Map<String, dynamic>> get units => _units;
  bool get loading => _loading;

  // ────────────────────────────────────────────────
  // LOAD SEMESTER UNITS
  // ────────────────────────────────────────────────
  Future<void> loadUnits() async {
    _loading = true;
    notifyListeners();

    final snap = await _db.collection("units")
        .where("year", isEqualTo: 2)
        .where("course", isEqualTo: "CS")
        .get();

    _units = snap.docs.map((d) => {
      "id": d.id,
      ...d.data(),
    }).toList();

    _loading = false;
    notifyListeners();
  }

  // ────────────────────────────────────────────────
  // STREAM FOR UI
  // ────────────────────────────────────────────────
  Stream<QuerySnapshot> streamUnits() {
    return _db.collection("units")
        .where("year", isEqualTo: 2)
        .where("course", isEqualTo: "CS")
        .orderBy("code")
        .snapshots();
  }
}

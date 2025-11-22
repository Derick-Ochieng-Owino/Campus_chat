import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupsProvider with ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _groups = [];
  bool _loading = false;

  List<Map<String, dynamic>> get groups => _groups;
  bool get loading => _loading;

  // ────────────────────────────────────────────────
  // LOAD GROUPS FOR YEAR 2 CS
  // ────────────────────────────────────────────────
  Future<void> loadGroups() async {
    _loading = true;
    notifyListeners();

    final snap = await _db.collection("groups")
        .where("course", isEqualTo: "CS")
        .where("year", isEqualTo: 2)
        .get();

    _groups = snap.docs.map((d) => ({
      "id": d.id,
      ...d.data(),
    })).toList();

    _loading = false;
    notifyListeners();
  }

  // ────────────────────────────────────────────────
  // FIND USER'S GROUP
  // ────────────────────────────────────────────────
  Map<String, dynamic>? groupOf(String uid) {
    try {
      return _groups.firstWhere((g) {
        final members = List<String>.from(g["members"] ?? []);
        return members.contains(uid);
      });
    } catch (e) {
      return null;
    }
  }

  // ────────────────────────────────────────────────
  // STREAM FOR GROUPS SCREEN
  // ────────────────────────────────────────────────
  Stream<QuerySnapshot> streamGroups() {
    return _db.collection("groups")
        .where("course", isEqualTo: "CS")
        .where("year", isEqualTo: 2)
        .snapshots();
  }
}

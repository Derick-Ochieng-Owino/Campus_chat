import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider with ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String? _uid;
  String? _name;
  String? _email;
  String? _role;
  String? _course;
  int? _year;

  // ────────────────────────────────────────────────
  // GETTERS
  // ────────────────────────────────────────────────
  String? get uid => _uid;
  String? get name => _name;
  String? get email => _email;
  String? get role => _role;
  String? get course => _course;
  int? get year => _year;

  bool get isLoggedIn => _uid != null;
  bool get isClassRep => _role == "class_rep";
  bool get isAssistantRep => _role == "assistant_rep";
  bool get isLecturer => _role == "lecturer";

  // ────────────────────────────────────────────────
  // INIT
  // ────────────────────────────────────────────────
  Future<void> init() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _uid = user.uid;
    await _loadUserProfile();
  }

  // ────────────────────────────────────────────────
  // LOAD USER FROM FIRESTORE
  // ────────────────────────────────────────────────
  Future<void> _loadUserProfile() async {
    if (_uid == null) return;

    final doc = await _db.collection("users").doc(_uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;

    _name = data["name"];
    _email = data["email"];
    _role = data["role"] ?? "student";
    _course = data["course"];
    _year = data["year"];

    notifyListeners();
  }

  // ────────────────────────────────────────────────
  // REFRESH USER
  // ────────────────────────────────────────────────
  Future<void> refresh() async {
    await _loadUserProfile();
  }

  // ────────────────────────────────────────────────
  // LOGIN
  // ────────────────────────────────────────────────
  Future<String?> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _uid = cred.user?.uid;
      await _loadUserProfile();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ────────────────────────────────────────────────
  // LOGOUT
  // ────────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
    _uid = null;
    _name = null;
    _email = null;
    _role = null;
    _course = null;
    _year = null;
    notifyListeners();
  }
}

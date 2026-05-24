import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  ProfileService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static Map<String, dynamic>? _cachedUserData;

  User? get currentUser => _auth.currentUser;

  Future<Map<String, dynamic>?> fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    if (_cachedUserData != null) {
      return _cachedUserData;
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();

    if (!doc.exists) return null;

    _cachedUserData = doc.data();
    return _cachedUserData;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  void clearCache() {
    _cachedUserData = null;
  }
}
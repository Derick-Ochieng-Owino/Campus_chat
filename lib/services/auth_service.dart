import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/auth/complete_profile.dart';

class AuthService {
  // Singleton pattern instantiation
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- State Observers ---
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // --- Onboarding Core Ops ---
  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_completed_onboarding') ?? false;
  }

  Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
  }

  // --- Authentication Operations ---
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (credential.user != null) {
      await syncUserToFirestore(credential.user!);
    }
    return credential;
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // --- Database Synchronization ---
  Future<void> syncUserToFirestore(User user) async {
    final userDocRef = _db.collection('users').doc(user.uid);
    await userDocRef.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName ?? '',
      'photoURL': user.photoURL ?? '',
      'emailVerified': user.emailVerified,
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // --- Local Asset Processing ---
  Future<UniversityData> loadCampusData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/campus_data.json');
      return UniversityData.fromJsonString(jsonString);
    } catch (e) {
      return UniversityData(universities: {});
    }
  }

  // --- Central Routing Engine ---
  Future<String> determineNextScreenRoute() async {
    final onboardingDone = await isOnboardingComplete();
    if (!onboardingDone) return 'onboarding';

    final user = _auth.currentUser;
    if (user == null) return 'login';

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final bool isProfileComplete = data?['profile_completed'] ?? false;
        return isProfileComplete ? 'home' : 'complete_profile';
      }
      return 'complete_profile';
    } catch (e) {
      return 'login';
    }
  }
}
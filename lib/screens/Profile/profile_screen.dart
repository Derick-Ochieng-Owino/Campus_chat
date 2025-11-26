import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../Profile/edit_profile_screen.dart'; // Create this page for editing
import '../Profile/settings_screen.dart';     // Create this page for settings

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacementNamed('/'); // SplashScreen handles routing
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppColors.primary,
        actions: [
          PopupMenuButton<int>(
            onSelected: (value) {
              if (value == 0) {
                // Edit profile
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(userData: _userData ?? {}),
                  ),
                );
              } else if (value == 1) {
                // Settings
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0, child: Text('Edit Profile')),
              const PopupMenuItem(value: 1, child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.lightGrey,
              child: Icon(Icons.person, size: 80, color: AppColors.darkGrey),
            ),
            const SizedBox(height: 15),
            Text(
              _userData?['name'] ?? user?.displayName ?? 'Student Name',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              _userData?['email'] ?? user?.email ?? 'N/A',
              style: const TextStyle(fontSize: 16, color: AppColors.darkGrey),
            ),
            const Divider(height: 40),
            _buildProfileTile(Icons.phone, 'Phone', _userData?['phone'] ?? 'N/A'),
            _buildProfileTile(Icons.badge, 'Student ID', _userData?['reg_number'] ?? 'N/A'),
            _buildProfileTile(Icons.school, 'Institution', _userData?['institution'] ?? 'JKUAT'),
            _buildProfileTile(Icons.email, 'Primary Email', _userData?['email'] ?? 'N/A'),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Sign Out', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
    );
  }
}

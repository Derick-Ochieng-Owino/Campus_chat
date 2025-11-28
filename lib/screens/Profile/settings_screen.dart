import 'package:campus_app/screens/Profile/edit_profile_screen.dart';
import 'package:campus_app/screens/Profile/themes_setting_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userData = doc.data()!;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryIconColor = colorScheme.primary;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    return Scaffold(
      // Use dynamic background and app bar colors
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colorScheme.surface, // Use theme surface color for consistency
        foregroundColor: colorScheme.onSurface, // Icon/Text color
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- Notifications ---
          ListTile(
            leading: Icon(Icons.notifications, color: primaryIconColor),
            title: Text('Notifications', style: theme.textTheme.bodyMedium),
            trailing: Switch(
              value: true,
              onChanged: (val) {
                // Handle switch toggle
              },
              // Themed switch colors
              activeColor: colorScheme.secondary,
              inactiveThumbColor: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),

          // --- Privacy ---
          ListTile(
            leading: Icon(Icons.lock, color: primaryIconColor),
            title: Text('Privacy', style: theme.textTheme.bodyMedium),
            trailing: Icon(Icons.arrow_forward_ios, color: colorScheme.onSurface.withOpacity(0.5)),
            onTap: () {
              // Navigate to Privacy settings
            },
          ),

          // --- Theme Setting ---
          ListTile(
            leading: Icon(Icons.palette, color: primaryIconColor),
            title: Text('Theme', style: theme.textTheme.bodyMedium),
            trailing: Icon(Icons.arrow_forward_ios, color: colorScheme.onSurface.withOpacity(0.5)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  // Assuming ThemeSettingsScreen is imported and defined
                  builder: (context) => const ThemeSettingsScreen(),
                ),
              );
            },
          ),

          // --- About ---
          ListTile(
            leading: Icon(Icons.info, color: primaryIconColor),
            title: Text('About', style: theme.textTheme.bodyMedium),
            trailing: Icon(Icons.arrow_forward_ios, color: colorScheme.onSurface.withOpacity(0.5)),
            onTap: () {
              // Navigate to About page
            },
          ),

          //Edit Profile
          ListTile(
            leading: Icon(Icons.person, color: primaryIconColor),
            title: Text('Edit Profile', style: theme.textTheme.bodyMedium),
            trailing: Icon(Icons.arrow_forward_ios, color: colorScheme.onSurface.withOpacity(0.5)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(userData: _userData),
                ),
              ).then((_) {
                _loadUserData();
              });
            },
          ),
        ],
      ),
    );
  }
}

import 'package:alma_mata/screens/profile/themes_setting_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_profile_model.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  bool _pushNotificationsActive = true;

  @override
  void initState() {
    super.initState();
    _loadProfileDataRecord();
  }

  Future<void> _loadProfileDataRecord() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _profile = UserProfile.fromMap(doc.data()!, user.uid);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPreferenceGroup({required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14, top: 18, bottom: 6),
          child: Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(children: children),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: theme.appBarTheme.elevation,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // --- User Summary Header Card ---
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
                    backgroundImage: _profile?.profilePhotoUrl != null
                        ? NetworkImage(_profile!.profilePhotoUrl!)
                        : null,
                    child: _profile?.profilePhotoUrl == null
                        ? Icon(Icons.person_outline_rounded, size: 32, color: theme.colorScheme.onPrimaryContainer)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile?.fullName ?? 'Alma Mater Student',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _profile?.regNumber ?? 'Unregistered Profile',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),

          // --- Profile Management Block ---
          _buildPreferenceGroup(
            title: 'PROFILE MANAGEMENT',
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text('Edit Account Information'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditProfileScreen(profile: _profile!)),
                ).then((modified) {
                  if (modified == true) {
                    setState(() => _isLoading = true);
                    _loadProfileDataRecord();
                  }
                }),
              ),
            ],
          ),

          // --- Preferences & System Settings ---
          _buildPreferenceGroup(
            title: 'PREFERENCES & SYSTEM',
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Visual Theme Scheme Options'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_none_rounded),
                title: const Text('System Push Notifications'),
                trailing: Switch(
                  value: _pushNotificationsActive,
                  activeThumbColor: theme.colorScheme.secondary,
                  onChanged: (v) => setState(() => _pushNotificationsActive = v),
                ),
              ),
            ],
          ),

          // --- Security & Legal parameters ---
          _buildPreferenceGroup(
            title: 'SECURITY & LEGAL',
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Parameters'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('About App Ecosystem'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../Profile/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;

  /// Cached user data to avoid reloading
  static Map<String, dynamic>? _cachedUserData;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (_cachedUserData != null) {
      _userData = _cachedUserData;
      _isLoading = false;
    } else {
      _fetchUserData();
    }
  }

  Future<void> _fetchUserData() async {
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (!mounted) return;

      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _cachedUserData = _userData;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryIconColor = colorScheme.primary;

    Widget shimmerBox({double width = double.infinity, double height = 16}) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          width: width,
          height: height,
          color: Colors.white,
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.onSurface),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- Avatar Section (always fixed) ---
            CircleAvatar(
              radius: 60,
              backgroundColor: colorScheme.surface,
              child: Icon(Icons.person, size: 80, color: primaryIconColor),
            ),
            const SizedBox(height: 15),

            // Name
            _isLoading
                ? shimmerBox(width: 180, height: 24)
                : Text(
              _userData?['full_name'] ?? user?.displayName ?? 'Student Name',
              style: theme.textTheme.headlineSmall!
                  .copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 5),

            // Email
            _isLoading
                ? shimmerBox(width: 200, height: 16)
                : Text(
              _userData?['email'] ?? user?.email ?? 'N/A',
              style: theme.textTheme.bodyMedium!.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7)),
            ),

            Divider(height: 40, color: theme.dividerColor),

            // --- Detail Tiles ---
            _buildProfileTile(context, Icons.phone, 'Phone',
                _isLoading ? null : _userData?['phone'] ?? 'N/A', shimmerBox),
            _buildProfileTile(context, Icons.badge, 'Student ID',
                _isLoading ? null : _userData?['reg_number'] ?? 'N/A', shimmerBox),
            _buildProfileTile(context, Icons.school, 'Institution',
                _isLoading ? null : _userData?['university'] ?? 'JKUAT', shimmerBox),
            _buildProfileTile(context, Icons.email, 'Primary Email',
                _isLoading ? null : _userData?['email'] ?? user?.email ?? 'N/A', shimmerBox),

            const SizedBox(height: 30),

            // --- Sign Out Button (fixed) ---
            ElevatedButton.icon(
              onPressed: _signOut,
              icon: Icon(Icons.logout, color: colorScheme.onError),
              label: Text('Sign Out', style: TextStyle(color: colorScheme.onError)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile(BuildContext context, IconData icon, String title,
      String? subtitle, Widget Function({double width, double height}) shimmerBox) {
    final theme = Theme.of(context);
    final primaryIconColor = theme.colorScheme.primary;

    return ListTile(
      leading: Icon(icon, color: primaryIconColor),
      title: Text(title,
          style: theme.textTheme.bodyMedium!
              .copyWith(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle, style: theme.textTheme.bodyMedium)
          : shimmerBox(width: double.infinity, height: 14),
    );
  }
}

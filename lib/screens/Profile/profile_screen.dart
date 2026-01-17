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

  /// Cached user data
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            // --- Profile Photo ---
            CircleAvatar(
              radius: 60,
              backgroundColor: colorScheme.surface,
              backgroundImage: _userData != null &&
                  _userData!['profile_photo_url'] != null
                  ? NetworkImage(_userData!['profile_photo_url'])
                  : null,
              child: _userData == null ||
                  _userData!['profile_photo_url'] == null
                  ? Icon(Icons.person, size: 80, color: colorScheme.primary)
                  : null,
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

            // --- Personal Info ---
            _buildProfileTile('Phone', _userData?['phone_number'] ?? 'N/A', Icons.phone),
            _buildProfileTile('Student ID', _userData?['reg_number'] ?? 'N/A', Icons.badge),
            _buildProfileTile('Nickname', _userData?['nickname'] ?? 'N/A', Icons.face),
            _buildProfileTile('Birth Date',
                _userData?['birth_date'] != null
                    ? _userData!['birth_date'].toString().split('T').first
                    : 'N/A',
                Icons.cake),
            _buildProfileTile('Role', _userData?['role'] ?? 'N/A', Icons.person_outline),

            Divider(height: 40, color: theme.dividerColor),

            // --- Academic Info ---
            _buildProfileTile('University', _userData?['university'] ?? 'N/A', Icons.school),
            _buildProfileTile('Campus', _userData?['campus'] ?? 'N/A', Icons.location_city),
            _buildProfileTile('College', _userData?['college'] ?? 'N/A', Icons.account_balance),
            _buildProfileTile('School', _userData?['school'] ?? 'N/A', Icons.business),
            _buildProfileTile('Department', _userData?['department'] ?? 'N/A', Icons.category),
            _buildProfileTile('Course', _userData?['course'] ?? 'N/A', Icons.book),
            _buildProfileTile('Year', _userData?['year'] ?? 'N/A', Icons.calendar_today),
            _buildProfileTile('Semester', _userData?['semester'] ?? 'N/A', Icons.timeline),

            Divider(height: 40, color: theme.dividerColor),

            // --- Registered Units ---
            Text('Registered Units', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            _isLoading
                ? shimmerBox(height: 100)
                : (_userData?['registered_units'] != null &&
                (_userData!['registered_units'] as List).isNotEmpty)
                ? ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: (_userData!['registered_units'] as List).length,
              itemBuilder: (context, index) {
                final unit =
                _userData!['registered_units'][index] as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(unit['title'] ?? 'Unit'),
                    subtitle: Text(unit['code'] ?? ''),
                    trailing: Text(unit['type'] ?? ''),
                  ),
                );
              },
            )
                : Text('No units registered', style: theme.textTheme.bodyMedium),

            const SizedBox(height: 30),

            // --- Sign Out ---
            ElevatedButton.icon(
              onPressed: _signOut,
              icon: Icon(Icons.logout, color: colorScheme.onError),
              label: Text('Sign Out', style: TextStyle(color: colorScheme.onError)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile(String title, String? subtitle, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(title,
          style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle, style: theme.textTheme.bodyMedium)
          : shimmerBox(width: double.infinity, height: 14),
    );
  }
}

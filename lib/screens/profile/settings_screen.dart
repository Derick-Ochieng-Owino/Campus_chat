// import 'package:alma_mata/screens/profile/themes_setting_screen.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import '../../models/user_profile_model.dart';
// import '../auth/signin_screen.dart';
// import 'edit_profile_screen.dart';
//
// class SettingsScreen extends StatefulWidget {
//   const SettingsScreen({super.key});
//
//   @override
//   State<SettingsScreen> createState() => _SettingsScreenState();
// }
//
// class _SettingsScreenState extends State<SettingsScreen> {
//   UserProfile? _profile;
//   bool _isLoading = true;
//   bool _pushNotificationsActive = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadProfileDataRecord();
//   }
//
//   Future<void> _loadProfileDataRecord() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;
//     try {
//       final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
//       if (doc.exists && mounted) {
//         setState(() {
//           _profile = UserProfile.fromMap(doc.data()!, user.uid);
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }
//
//   // --- Handlers for Danger Zone Actions ---
//   void _handleLogout() async {
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Logout'),
//         content: const Text('Are you sure you want to log out of your account?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context, true),
//             child: const Text('Logout', style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );
//
//     if (confirmed == true && mounted) {
//       await FirebaseAuth.instance.signOut();
//
//       if (mounted) {
//         Navigator.pushAndRemoveUntil(
//           context,
//           MaterialPageRoute(builder: (_) => const LoginPage()),
//               (route) => false,
//         );
//       }
//     }
//   }
//
//   void _showDeleteAccountVerificationDialog() {
//     final formKey = GlobalKey<FormState>();
//     final emailController = TextEditingController();
//     final regNumberController = TextEditingController();
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) {
//         final theme = Theme.of(context);
//         return AlertDialog(
//           title: Row(
//             children: [
//               Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
//               const SizedBox(width: 8),
//               const Text('Delete Account'),
//             ],
//           ),
//           content: SingleChildScrollView(
//             child: Form(
//               key: formKey,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'This action is permanent and cannot be undone. All your profile data will be completely deleted.',
//                     style: TextStyle(fontSize: 13, height: 1.4),
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     'To confirm, please verify your credentials:',
//                     style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
//                   ),
//                   const SizedBox(height: 12),
//                   TextFormField(
//                     controller: emailController,
//                     keyboardType: TextInputType.emailAddress,
//                     decoration: const InputDecoration(
//                       labelText: 'Verify Email Address',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.email_outlined),
//                     ),
//                     validator: (value) {
//                       final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
//                       if (value == null || value.trim().isEmpty) {
//                         return 'Email is required';
//                       }
//                       if (value.trim().toLowerCase() != currentUserEmail?.toLowerCase()) {
//                         return 'Email does not match your account';
//                       }
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 12),
//                   TextFormField(
//                     controller: regNumberController,
//                     textCapitalization: TextCapitalization.characters,
//                     decoration: const InputDecoration(
//                       labelText: 'Verify Registration Number',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.badge_outlined),
//                     ),
//                     validator: (value) {
//                       final currentRegNum = _profile?.regNumber;
//                       if (value == null || value.trim().isEmpty) {
//                         return 'Registration number is required';
//                       }
//                       if (value.trim().toUpperCase() != currentRegNum?.toUpperCase()) {
//                         return 'Registration number does not match';
//                       }
//                       return null;
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: theme.colorScheme.error,
//                 foregroundColor: theme.colorScheme.onError,
//                 elevation: 0,
//               ),
//               onPressed: () async {
//                 if (formKey.currentState!.validate()) {
//                   // Close verification dialog
//                   Navigator.pop(context);
//                   await _executeAccountDeletion();
//                 }
//               },
//               child: const Text('Permanently Delete'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   Future<void> _executeAccountDeletion() async {
//     setState(() => _isLoading = true);
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         // 1. Delete Firestore user record
//         await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
//
//         // 2. Delete Firebase Authentication user instance
//         await user.delete();
//
//         // Note: If user hasn't logged in recently, Firebase might throw a 'requires-recent-login' exception.
//         // If it throws, you would ideally catch it and prompt them to re-authenticate first.
//       }
//     } on FirebaseException catch (e) {
//       setState(() => _isLoading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(e.message ?? 'An error occurred during account deletion.')),
//       );
//     } catch (e) {
//       setState(() => _isLoading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to delete account. Please try logging in again.')),
//       );
//     }
//   }
//
//   Widget _buildPreferenceGroup({required String title, required List<Widget> children, Color? titleColor, Color? cardColor}) {
//     final theme = Theme.of(context);
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.only(left: 14, top: 18, bottom: 6),
//           child: Text(
//             title,
//             style: TextStyle(
//               color: titleColor ?? theme.colorScheme.primary,
//               fontWeight: FontWeight.bold,
//               fontSize: 12,
//               letterSpacing: 0.5,
//             ),
//           ),
//         ),
//         Card(
//           elevation: 0,
//           color: cardColor ?? theme.colorScheme.surfaceContainerLow,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           child: Column(children: children),
//         ),
//       ],
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//
//     if (_isLoading) {
//       return Scaffold(
//         backgroundColor: theme.scaffoldBackgroundColor,
//         body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
//       );
//     }
//
//     return Scaffold(
//       backgroundColor: theme.scaffoldBackgroundColor,
//       appBar: AppBar(
//         title: const Text('Settings'),
//         centerTitle: true,
//         backgroundColor: theme.appBarTheme.backgroundColor,
//         foregroundColor: theme.appBarTheme.foregroundColor,
//         elevation: theme.appBarTheme.elevation,
//       ),
//       body: ListView(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         children: [
//           // --- User Summary Header Card ---
//           Card(
//             elevation: 0,
//             color: theme.colorScheme.primaryContainer,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: Row(
//                 children: [
//                   CircleAvatar(
//                     radius: 32,
//                     backgroundColor: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
//                     backgroundImage: _profile?.profilePhotoUrl != null
//                         ? NetworkImage(_profile!.profilePhotoUrl!)
//                         : null,
//                     child: _profile?.profilePhotoUrl == null
//                         ? Icon(Icons.person_outline_rounded, size: 32, color: theme.colorScheme.onPrimaryContainer)
//                         : null,
//                   ),
//                   const SizedBox(width: 16),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           _profile?.firstName ?? 'Alma Mater Student',
//                           style: theme.textTheme.titleMedium?.copyWith(
//                             fontWeight: FontWeight.bold,
//                             color: theme.colorScheme.onPrimaryContainer,
//                           ),
//                         ),
//                         const SizedBox(height: 2),
//                         Text(
//                           _profile?.regNumber ?? 'Unregistered Profile',
//                           style: theme.textTheme.bodyMedium?.copyWith(
//                             color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
//                           ),
//                         ),
//                       ],
//                     ),
//                   )
//                 ],
//               ),
//             ),
//           ),
//
//           // --- Profile Management Block ---
//           _buildPreferenceGroup(
//             title: 'PROFILE MANAGEMENT',
//             children: [
//               ListTile(
//                 leading: const Icon(Icons.edit_note_rounded),
//                 title: const Text('Edit Account Information'),
//                 trailing: const Icon(Icons.chevron_right_rounded),
//                 onTap: () => Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (_) => EditProfileScreen(profile: _profile!)),
//                 ).then((modified) {
//                   if (modified == true) {
//                     setState(() => _isLoading = true);
//                     _loadProfileDataRecord();
//                   }
//                 }),
//               ),
//             ],
//           ),
//
//           // --- Preferences & System Settings ---
//           _buildPreferenceGroup(
//             title: 'PREFERENCES & SYSTEM',
//             children: [
//               ListTile(
//                 leading: const Icon(Icons.palette_outlined),
//                 title: const Text('Visual Theme Scheme Options'),
//                 trailing: const Icon(Icons.chevron_right_rounded),
//                 onTap: () => Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
//                 ),
//               ),
//               ListTile(
//                 leading: const Icon(Icons.notifications_none_rounded),
//                 title: const Text('System Push Notifications'),
//                 trailing: Switch(
//                   value: _pushNotificationsActive,
//                   activeThumbColor: theme.colorScheme.secondary,
//                   onChanged: (v) => setState(() => _pushNotificationsActive = v),
//                 ),
//               ),
//             ],
//           ),
//
//           // --- Security & Legal parameters ---
//           _buildPreferenceGroup(
//             title: 'SECURITY & LEGAL',
//             children: [
//               ListTile(
//                 leading: const Icon(Icons.privacy_tip_outlined),
//                 title: const Text('Privacy Parameters'),
//                 trailing: const Icon(Icons.chevron_right_rounded),
//                 onTap: () {},
//               ),
//               ListTile(
//                 leading: const Icon(Icons.info_outline_rounded),
//                 title: const Text('About App Ecosystem'),
//                 trailing: const Icon(Icons.chevron_right_rounded),
//                 onTap: () {},
//               ),
//             ],
//           ),
//
//           // --- Danger Zone Block ---
//           _buildPreferenceGroup(
//             title: 'DANGER ZONE',
//             titleColor: theme.colorScheme.error,
//             cardColor: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
//             children: [
//               ListTile(
//                 leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
//                 title: Text('Log Out', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w500)),
//                 onTap: _handleLogout,
//               ),
//               const Divider(height: 1, indent: 16, endIndent: 16),
//               ListTile(
//                 leading: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
//                 title: Text('Delete Account', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w500)),
//                 onTap: _showDeleteAccountVerificationDialog,
//               ),
//             ],
//           ),
//           const SizedBox(height: 24),
//         ],
//       ),
//     );
//   }
// }

import 'package:alma_mata/screens/profile/themes_setting_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_profile_model.dart';
import '../auth/signin_screen.dart';
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
  bool _isSuperAdmin = false; // Tracks super admin privileges

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
        final data = doc.data()!;
        setState(() {
          _profile = UserProfile.fromMap(data, user.uid);
          // Check if user role matches your privileged designation
          _isSuperAdmin = data['role'] == 'super_admin';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Handlers for Danger Zone Actions ---
  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
        );
      }
    }
  }

  void _showDeleteAccountVerificationDialog() {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final regNumberController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              const Text('Delete Account'),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This action is permanent and cannot be undone. All your profile data will be completely deleted.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'To confirm, please verify your credentials:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Verify Email Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (value.trim().toLowerCase() != currentUserEmail?.toLowerCase()) {
                        return 'Email does not match your account';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: regNumberController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Verify Registration Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (value) {
                      final currentRegNum = _profile?.regNumber;
                      if (value == null || value.trim().isEmpty) {
                        return 'Registration number is required';
                      }
                      if (value.trim().toUpperCase() != currentRegNum?.toUpperCase()) {
                        return 'Registration number does not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                elevation: 0,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Close verification dialog
                  Navigator.pop(context);
                  await _executeAccountDeletion();
                }
              },
              child: const Text('Permanently Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeAccountDeletion() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
        await user.delete();
      }
    } on FirebaseException catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'An error occurred during account deletion.')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete account. Please try logging in again.')),
      );
    }
  }

  Widget _buildPreferenceGroup({required String title, required List<Widget> children, Color? titleColor, Color? cardColor}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14, top: 18, bottom: 6),
          child: Text(
            title,
            style: TextStyle(
              color: titleColor ?? theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: cardColor ?? theme.colorScheme.surfaceContainerLow,
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
                          _profile?.firstName ?? 'Alma Mater Student',
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

          // --- ADMIN CONSOLE WORKSPACE (CONDITIONAL) ---
          if (_isSuperAdmin)
            _buildPreferenceGroup(
              title: 'ADMIN WORKSPACE & TOOLS',
              titleColor: Colors.amber[800],
              cardColor: Colors.amber.withValues(alpha: 0.08),
              children: [
                ListTile(
                  leading: Icon(Icons.analytics_outlined, color: Colors.amber[800]),
                  title: const Text('View Global Platform Metrics', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Monitor online, active, and inactive user scopes'),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.amber[800]),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminMetricsScreen()),
                  ),
                ),
              ],
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

          // --- Danger Zone Block ---
          _buildPreferenceGroup(
            title: 'DANGER ZONE',
            titleColor: theme.colorScheme.error,
            cardColor: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
            children: [
              ListTile(
                leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
                title: Text('Log Out', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w500)),
                onTap: _handleLogout,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
                title: Text('Delete Account', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w500)),
                onTap: _showDeleteAccountVerificationDialog,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// --- NEW SYSTEM SCREEN: ADMIN METRICS CANVAS ---
class AdminMetricsScreen extends StatelessWidget {
  const AdminMetricsScreen({super.key});

  Widget _buildMetricCard({required String label, required String numericalValue, required IconData icon, required Color baseColor, required ThemeData theme}) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: baseColor.withValues(alpha: 0.1),
              child: Icon(icon, color: baseColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(numericalValue, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('System Dashboard'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Real-time Platform Metrics',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          _buildMetricCard(label: 'Total Registered Ecosystem Users', numericalValue: '1,240', icon: Icons.people_alt_outlined, baseColor: theme.colorScheme.primary, theme: theme),
          _buildMetricCard(label: 'Active Users (Online Right Now)', numericalValue: '342', icon: Icons.gpp_good_outlined, baseColor: Colors.green, theme: theme),
          _buildMetricCard(label: 'Inactive Users (Last 30 Days)', numericalValue: '88', icon: Icons.hourglass_disabled_rounded, baseColor: Colors.orange, theme: theme),
          _buildMetricCard(label: 'Dormant Accounts Profile Scopes', numericalValue: '14', icon: Icons.person_off_outlined, baseColor: theme.colorScheme.error, theme: theme),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // Additional descriptive section for future analytics streams
          ListTile(
            leading: const Icon(Icons.history_toggle_off_rounded),
            title: const Text('User Last Seen Tracking History'),
            subtitle: const Text('View transactional timeline audit logs across student endpoints'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              // Expand downstream sub-route operations here
            },
          ),
        ],
      ),
    );
  }
}
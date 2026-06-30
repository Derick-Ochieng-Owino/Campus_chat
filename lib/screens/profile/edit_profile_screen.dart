// // import 'package:flutter/material.dart';
// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// //
// // class EditProfileScreen extends StatefulWidget {
// //   final Map<String, dynamic> userData;
// //
// //   const EditProfileScreen({super.key, required this.userData});
// //
// //   @override
// //   State<EditProfileScreen> createState() => _EditProfileScreenState();
// // }
// //
// // class _EditProfileScreenState extends State<EditProfileScreen> {
// //   final _formKey = GlobalKey<FormState>();
// //
// //   late TextEditingController _nameController;
// //   late TextEditingController _nicknameController;
// //   late TextEditingController _phoneController;
// //
// //   bool _isLoading = false;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     // Initialize controllers with existing data
// //     _nameController = TextEditingController(text: widget.userData['full_name'] ?? '');
// //     _nicknameController = TextEditingController(text: widget.userData['nickname'] ?? '');
// //     _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
// //   }
// //
// //   @override
// //   void dispose() {
// //     _nameController.dispose();
// //     _nicknameController.dispose();
// //     _phoneController.dispose();
// //     super.dispose();
// //   }
// //
// //   Future<void> _saveProfile() async {
// //     if (!_formKey.currentState!.validate()) return;
// //
// //     final user = FirebaseAuth.instance.currentUser;
// //     if (user == null) return;
// //
// //     final theme = Theme.of(context);
// //     final colorScheme = theme.colorScheme;
// //
// //     setState(() => _isLoading = true);
// //
// //     try {
// //       await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
// //         'full_name': _nameController.text.trim(),
// //         'nickname': _nicknameController.text.trim(),
// //         'phone': _phoneController.text.trim(),
// //         'updated_at': FieldValue.serverTimestamp(),
// //       }, SetOptions(merge: true));
// //
// //       if (mounted) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(
// //             content: const Text('Profile saved successfully!'),
// //             backgroundColor: colorScheme.primary,
// //           ),
// //         );
// //         Navigator.pop(context, true);
// //       }
// //     } catch (e) {
// //       if (mounted) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(
// //             content: Text('Failed to save profile: ${e.toString()}'),
// //             backgroundColor: colorScheme.error,
// //           ),
// //         );
// //       }
// //     } finally {
// //       if (mounted) setState(() => _isLoading = false);
// //     }
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final theme = Theme.of(context);
// //     final colorScheme = theme.colorScheme;
// //
// //     return Scaffold(
// //       backgroundColor: theme.scaffoldBackgroundColor,
// //       appBar: AppBar(
// //         title: const Text('Edit Profile'),
// //         backgroundColor: colorScheme.surface,
// //         foregroundColor: colorScheme.onSurface,
// //       ),
// //       body: SingleChildScrollView(
// //         padding: const EdgeInsets.all(20.0),
// //         child: Form(
// //           key: _formKey,
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.stretch,
// //             children: [
// //               TextFormField(
// //                 controller: _nameController,
// //                 decoration: const InputDecoration(
// //                   labelText: 'Full Name',
// //                 ),
// //                 validator: (v) => v!.isEmpty ? 'Full name is required' : null,
// //               ),
// //               const SizedBox(height: 20),
// //
// //               TextFormField(
// //                 controller: _nicknameController,
// //                 decoration: const InputDecoration(
// //                   labelText: 'Nickname (Optional)',
// //                 ),
// //               ),
// //               const SizedBox(height: 20),
// //
// //               TextFormField(
// //                 controller: _phoneController,
// //                 keyboardType: TextInputType.phone,
// //                 decoration: const InputDecoration(
// //                   labelText: 'Phone Number',
// //                 ),
// //                 validator: (v) {
// //                   if (v!.isNotEmpty && !RegExp(r'^\+?[0-9]{7,15}$').hasMatch(v)) {
// //                     return 'Enter a valid phone number';
// //                   }
// //                   return null;
// //                 },
// //               ),
// //               const SizedBox(height: 30),
// //
// //               SizedBox(
// //                 height: 50,
// //                 child: _isLoading
// //                     ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
// //                     : ElevatedButton(
// //                   onPressed: _saveProfile,
// //                   style: ElevatedButton.styleFrom(
// //                     backgroundColor: colorScheme.primary,
// //                     padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
// //                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
// //                   ),
// //                   child: Text(
// //                     'Save Changes',
// //                     style: theme.textTheme.labelLarge!.copyWith(
// //                       color: colorScheme.onPrimary,
// //                       fontSize: 16,
// //                     ),
// //                   ),
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
//
// import '../../models/user_profile_model.dart';
//
// class EditProfileScreen extends StatefulWidget {
//   final UserProfile profile;
//   const EditProfileScreen({super.key, required this.profile});
//
//   @override
//   State<EditProfileScreen> createState() => _EditProfileScreenState();
// }
//
// class _EditProfileScreenState extends State<EditProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   late TextEditingController _nicknameController;
//   late TextEditingController _phoneController;
//   bool _isSaving = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController(text: widget.profile.fullName);
//     _nicknameController = TextEditingController(text: widget.profile.nickname ?? '');
//     _phoneController = TextEditingController(text: widget.profile.phoneNumber);
//   }
//
//   @override
//   void dispose() {
//     _nameController.dispose();
//     _nicknameController.dispose();
//     _phoneController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _persistProfileChanges() async {
//     if (!_formKey.currentState!.validate()) return;
//     setState(() => _isSaving = true);
//
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) return;
//
//       final updatedFields = {
//         'full_name': _nameController.text.trim(),
//         'nickname': _nicknameController.text.trim(),
//         'phone_number': _phoneController.text.trim(),
//         'updated_at': FieldValue.serverTimestamp(),
//       };
//
//       final batch = FirebaseFirestore.instance.batch();
//       final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
//       final studentRef = FirebaseFirestore.instance.collection('university_students').doc(user.uid);
//
//       batch.set(userRef, updatedFields, SetOptions(merge: true));
//       batch.set(studentRef, updatedFields, SetOptions(merge: true));
//       await batch.commit();
//
//       if (!mounted) return;
//       Navigator.pop(context, true);
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error updating records: $e'), backgroundColor: Theme.of(context).colorScheme.error),
//       );
//     } finally {
//       if (mounted) setState(() => _isSaving = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//
//     return Scaffold(
//       backgroundColor: theme.scaffoldBackgroundColor,
//       appBar: AppBar(title: const Text('Edit Account Info')),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               TextFormField(
//                 controller: _nameController,
//                 decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded)),
//                 validator: (v) => (v == null || v.isEmpty) ? 'Name can\'t be empty' : null,
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _nicknameController,
//                 decoration: const InputDecoration(labelText: 'Nickname (Optional)', prefixIcon: Icon(Icons.face_outlined)),
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _phoneController,
//                 keyboardType: TextInputType.phone,
//                 decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_android_rounded)),
//                 validator: (v) => (v != null && v.isNotEmpty && !RegExp(r'^\+?[0-9]{7,15}$').hasMatch(v)) ? 'Invalid phone format' : null,
//               ),
//               const SizedBox(height: 32),
//               SizedBox(
//                 width: double.infinity,
//                 height: 52,
//                 child: _isSaving
//                     ? const Center(child: CircularProgressIndicator())
//                     : FilledButton(
//                   onPressed: _persistProfileChanges,
//                   // border : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                   child: const Text('SAVE ALTERATIONS', style: TextStyle(fontWeight: FontWeight.bold)),
//                 ),
//               )
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile_model.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.profile.firstName);
    _middleNameController = TextEditingController(text: widget.profile.middleName);
    _lastNameController = TextEditingController(text: widget.profile.lastName);
    _phoneController = TextEditingController(text: widget.profile.phoneNumber);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _persistProfileChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final updatedFields = {
        'first_name': _firstNameController.text.trim(),
        'middle_name': _middleNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final studentRef = FirebaseFirestore.instance.collection('university_students').doc(user.uid);

      batch.set(userRef, updatedFields, SetOptions(merge: true));
      batch.set(studentRef, updatedFields, SetOptions(merge: true));
      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating records: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
    if (mounted) setState(() => _isSaving = false);
  }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF0F0F12);
    //const cardColor = Color(0xFF18181C);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(backgroundColor: backgroundColor, elevation: 0, title: const Text('Edit Account Info', style: TextStyle(color: Colors.white, fontSize: 16)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _firstNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'First Name', labelStyle: TextStyle(color: Colors.white60), prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.white60)),
                validator: (v) => (v == null || v.isEmpty) ? 'First name can\'t be empty' : null,
              ),
              TextFormField(
                controller: _middleNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Middle Name', labelStyle: TextStyle(color: Colors.white60), prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.white60)),
                validator: (v) => (v == null || v.isEmpty) ? 'Middle name can\'t be empty' : null,
              ),
              TextFormField(
                controller: _lastNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Last Name', labelStyle: TextStyle(color: Colors.white60), prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.white60)),
                validator: (v) => (v == null || v.isEmpty) ? 'Last name can\'t be empty' : null,
              ),
              // const SizedBox(height: 20),
              // TextFormField(
              //   controller: _nicknameController,
              //   style: const TextStyle(color: Colors.white),
              //   decoration: const InputDecoration(labelText: 'Nickname (Optional)', labelStyle: TextStyle(color: Colors.white60), prefixIcon: Icon(Icons.face_outlined, color: Colors.white60)),
              // ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', labelStyle: TextStyle(color: Colors.white60), prefixIcon: Icon(Icons.phone_android_rounded, color: Colors.white60)),
                validator: (v) => (v != null && v.isNotEmpty && !RegExp(r'^\+?[0-9]{7,15}$').hasMatch(v)) ? 'Invalid phone format' : null,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isSaving
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                    : ElevatedButton(
                  onPressed: _persistProfileChanges,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('SAVE ALTERATIONS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
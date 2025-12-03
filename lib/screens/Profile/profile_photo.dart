import 'dart:io';
import 'package:campus_app/screens/Profile/personal_details.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../home/home_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PersonalDetailsData {
  final String fullName;
  final String regNumber;
  final DateTime birthDate;
  final String? nickname;

  PersonalDetailsData({
    required this.fullName,
    required this.regNumber,
    required this.birthDate,
    this.nickname,
  });
}

class ProfilePhotoPage extends StatefulWidget {
  final AcademicProfileData academicData;
  final PersonalDetailsData personalData;

  const ProfilePhotoPage({super.key, required this.academicData, required this.personalData});

  @override
  State<ProfilePhotoPage> createState() => _ProfilePhotoPageState();
}

class _ProfilePhotoPageState extends State<ProfilePhotoPage> {
  File? _imageFile;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Adjust for max 1MB limit (approx)
      maxWidth: 800,
      maxHeight: 800,
    );

    if (pickedFile != null) {
      // Basic check for file size (approximate, actual upload handles strict size)
      final fileSize = await pickedFile.length();
      if (fileSize > 1024 * 1024) { // 1MB in bytes
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Image size must be less than 1MB'), backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
        return;
      }

      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadProfilePhoto(String uid) async {
    if (_imageFile == null) return null;

    // --- Placeholder for actual Firebase Storage upload logic ---
    // final storageRef = FirebaseStorage.instance.ref().child('profile_photos/$uid.jpg');
    // await storageRef.putFile(_imageFile!);
    // return await storageRef.getDownloadURL();

    // For this example, we'll return a placeholder URL
    return 'https://example.com/placeholder_photo/$uid.jpg';
  }

  // Final Save profile: writes ALL selected data to user doc
  Future<void> _saveAllProfileData() async {
    setState(() => _isLoading = true);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No logged in user');

      final photoUrl = await _uploadProfilePhoto(user.uid);

      final academic = widget.academicData;
      final personal = widget.personalData;

      final profileData = {
        // --- Academic Data ---
        'campus': academic.campus,
        'college': academic.college,
        'school': academic.school,
        'department': academic.department,
        'course': academic.course,
        'year_key': academic.yearKey,
        'semester_key': academic.semesterKey,
        'registered_units': academic.registeredUnits,

        // --- Personal Data ---
        'full_name': personal.fullName,
        'nickname': personal.nickname,
        'reg_number': personal.regNumber,
        'birth_date': personal.birthDate.toIso8601String(), // Store as string

        // --- Final Completion Data ---
        'profile_completed': true,
        'profile_photo_url': photoUrl,
        'updated_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(profileData, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Profile setup complete!'), backgroundColor: colorScheme.primary));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: colorScheme.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Stack(
          children: [
            // --- Header Gradient ---
            Container(
              height: size.height * 0.4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // --- Header Text ---
                    Text('Profile Photo', style: theme.textTheme.headlineSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Add a photo to personalize your profile', style: theme.textTheme.bodyMedium!.copyWith(color: Colors.white70)),
                    const SizedBox(height: 30),
                    Card(
                      elevation: 8,
                      color: theme.cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 70,
                                    backgroundColor: colorScheme.surfaceVariant,
                                    backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                                    child: _imageFile == null
                                        ? Icon(Icons.person, size: 70, color: colorScheme.onSurface.withOpacity(0.5))
                                        : null,
                                  ),
                                  Positioned(
                                    child: IconButton(
                                      icon: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.camera_alt, color: colorScheme.onPrimary),
                                      ),
                                      onPressed: _pickImage,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: TextButton(
                                onPressed: _pickImage,
                                child: Text(_imageFile == null ? 'SELECT PROFILE PHOTO' : 'CHANGE PHOTO'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text('Max size: 1MB', style: theme.textTheme.bodySmall!.copyWith(color: colorScheme.onSurface.withOpacity(0.6))),
                            ),
                            const SizedBox(height: 32),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              child: _isLoading
                                  ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                                  : ElevatedButton(
                                onPressed: _saveAllProfileData,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                child: Text('FINISH & VIEW UNITS', style: theme.textTheme.labelLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onPrimary)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Skip Button
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: _saveAllProfileData, // Saves without a photo
                                child: Text('SKIP FOR NOW', style: theme.textTheme.labelLarge!.copyWith(color: colorScheme.primary)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
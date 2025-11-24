import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // After signing out, rely on the SplashScreen logic to redirect.
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.lightGrey,
                child: Icon(Icons.person, size: 80, color: AppColors.darkGrey),
              ),
              const SizedBox(height: 15),
              Text(
                user?.email ?? 'Student Name Placeholder',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Year 2 • Computer Science',
                style: TextStyle(fontSize: 16, color: AppColors.darkGrey),
              ),
              const Divider(height: 40),
              _buildProfileTile(Icons.phone, 'Phone', user?.phoneNumber ?? 'N/A'),
              _buildProfileTile(Icons.badge, 'Student ID', 'SE-202X-XXXX'),
              _buildProfileTile(Icons.school, 'Institution', 'JKUAT'),
              _buildProfileTile(Icons.email, 'Primary Email', user?.email ?? 'N/A'),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => _signOut(context),
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
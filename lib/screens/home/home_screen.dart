import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/colors.dart';
import '../Notes/notes_screen.dart';
import '../Profile/complete_profile.dart';
import '../Profile/profile_screen.dart';
import '../announcement/announcements_screen.dart';
import '../chat/chat_home_screen.dart';
import '../groups/groups_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  Future<CampusData>? _campusDataFuture;

  @override
  void initState() {
    super.initState();
    _campusDataFuture = _loadCampusData();
  }

  Future<CampusData> _loadCampusData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/campus_data.json');
      final data = CampusData.fromJsonString(jsonString);
      return data;
    } catch (e) {
      debugPrint('Error loading campus JSON: $e');
      return CampusData(campuses: {}); // fallback to empty
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Guest User';
    final isChatScreen = _currentIndex == 0;
    final String appBarTitle = [
      'Campus Chats',
      'Course Notes',
      'Groups',
      'Announcements',
      'My Profile'
    ][_currentIndex];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(appBarTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: isChatScreen ? AppColors.secondary : AppColors.primary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Center(
              child: Text(
                userEmail.split('@').first,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          )
        ],
      ),
      body: FutureBuilder<CampusData>(
        future: _campusDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading campus data: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No campus data found'));
          }

          final campusDataInstance = snapshot.data!;

          final screens = [
            ChatHomeScreen(), // 0
            NotesScreen(campusData: campusDataInstance), // 1
            GroupsScreen(), // 2
            AnnouncementScreen(), // 3
            ProfileScreen(), // 4
          ];

          return screens[_currentIndex];
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.darkGrey,
        items: [
          _buildNavItem(0, Icons.message, "Chat"),
          _buildNavItem(1, Icons.book, "Notes"),
          _buildNavItem(2, Icons.group, "Groups"),
          _buildNavItem(3, Icons.campaign, "Announcements"),
          _buildNavItem(4, Icons.person, "Profile"),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(int index, IconData icon, String label) {
    final bool isActive = index == _currentIndex;

    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: isActive ? Border.all(color: AppColors.primary, width: 1.5) : null,
        ),
        child: Icon(
          icon,
          size: isActive ? 28.0 : 24.0,
          color: isActive ? AppColors.primary : AppColors.darkGrey,
        ),
      ),
      label: label,
    );
  }
}

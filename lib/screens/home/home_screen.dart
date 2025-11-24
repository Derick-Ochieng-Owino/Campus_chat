import 'package:flutter/material.dart';
import 'package:campus_app/screens/announcement/announcements_screen.dart';
import 'package:campus_app/screens/chat/chat_screen.dart';
import 'package:campus_app/screens/Notes/notes_screen.dart';
import 'package:campus_app/screens/Profile/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../chat/chat_home_screen.dart';
import '../groups/groups_screen.dart';

// The main dashboard which handles the bottom navigation and routing to tabs.
// This implements the requested WhatsApp-like UI, five tabs, and animated nav bar.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // 5 Tabs: Chat, Notes, Groups, Announcements, Profile
  final List<Widget> _screens = [
    ChatHomeScreen(),         // 0: WhatsApp-like Chat UI
    NotesScreen(),        // 1: Units listed with Notes (PDF, DOCX, etc.)
    GroupsScreen(),  // 2: Groups
    AnnouncementScreen(),// 3: Notices and School/Department news
    ProfileScreen(),      // 4: User profile and Sign Out
  ];

  @override
  Widget build(BuildContext context) {
    // Current user email for the AppBar title
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Guest User';

    // Customize AppBar based on the active screen
    final isChatScreen = _currentIndex == 0;

    // Determine the title based on the current tab
    final String appBarTitle = [
      'Campus Chats', 'Course Notes', 'Groups', 'Announcements', 'My Profile'
    ][_currentIndex];

    return Scaffold(
      appBar: AppBar(
        // Use different colors for the Chat screen (WhatsApp green)
        automaticallyImplyLeading: false,
        title: Text(appBarTitle, style: const TextStyle(color: Colors.white)),

        backgroundColor: isChatScreen ? AppColors.secondary : AppColors.primary,

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Center(
              child: Text(
                // Displays the username (part before the '@')
                  userEmail.split('@').first,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)
              ),
            ),
          )
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed, // Necessary for 5 items
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

  // Custom Navigation Item for Active/Enlarge Feature (Icon Rises/Enlarges)
  BottomNavigationBarItem _buildNavItem(int index, IconData icon, String label) {
    final bool isActive = index == _currentIndex;

    return BottomNavigationBarItem(
      // AnimatedContainer creates the rising/enlarge effect
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          // Rounded background effect when active
          color: isActive ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          // Rounded border feature
          border: isActive ? Border.all(color: AppColors.primary, width: 1.5) : null,
        ),
        child: Icon(
          icon,
          size: isActive ? 28.0 : 24.0, // Enlarge feature
          color: isActive ? AppColors.primary : AppColors.darkGrey,
        ),
      ),
      label: label,
    );
  }
}
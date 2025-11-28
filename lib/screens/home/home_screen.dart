import 'package:campus_app/core/widgets/loading_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late PageController _pageController;
  Future<CampusData>? _campusDataFuture;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _campusDataFuture = _loadCampusData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<CampusData> _loadCampusData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/campus_data.json');
      final data = CampusData.fromJsonString(jsonString);
      return data;
    } catch (e) {
      return CampusData(campuses: {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: FutureBuilder<CampusData>(
        future: _campusDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: AppLogoLoadingWidget(size: 80,));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading campus data: ${snapshot.error}', style: theme.textTheme.bodyMedium));
          } else if (!snapshot.hasData) {
            return Center(child: Text('No campus data found', style: theme.textTheme.bodyMedium));
          }

          final campusDataInstance = snapshot.data!;

          // Note: All these child screens must contain their own Scaffold and AppBar
          final screens = [
            ChatHomeScreen(),
            NotesScreen(campusData: campusDataInstance),
            GroupsTab(),
            AnnouncementScreen(),
            ProfileScreen(),
          ];

          return PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            children: screens,
          );

        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        },

        type: BottomNavigationBarType.fixed,

        // --- Dynamic Navigation Bar Colors ---
        selectedItemColor: colorScheme.primary, // Primary color for selected item
        unselectedItemColor: colorScheme.onSurface.withOpacity(0.6), // Subtle color for unselected
        backgroundColor: colorScheme.surface, // Use theme surface color for background
        // --- Dynamic Navigation Bar Colors ---

        items: [
          _buildNavItem(context, 0, Icons.message, "Chat"),
          _buildNavItem(context, 1, Icons.book, "Notes"),
          _buildNavItem(context, 2, Icons.group, "Groups"),
          _buildNavItem(context, 3, Icons.campaign, "Announcements"),
          _buildNavItem(context, 4, Icons.person, "Profile"),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isActive = index == _currentIndex;

    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          // Background color for active item (subtle tint of primary)
          color: isActive ? colorScheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          // Border for active item (uses primary color)
          border: isActive ? Border.all(color: colorScheme.primary, width: 1.5) : null,
        ),
        child: Icon(
          icon,
          size: isActive ? 28.0 : 24.0,
          // Icon color uses primary when active, and a subdued onSurface color when inactive
          color: isActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      label: label,
    );
  }
}
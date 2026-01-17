import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Imports for your other screens
import '../../widgets/loading_widget.dart';
import '../Notes/notes_screen.dart';
import '../Profile/complete_profile.dart';
import '../Profile/profile_screen.dart';
import '../announcement/announcements_screen.dart';
import '../chat/chat_home_screen.dart';
import '../groups/groups_screen.dart';
// import 'path/to/app_themes.dart'; // Uncomment if AppThemes is in a separate file

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<UniversityData>? _campusDataFuture;

  @override
  void initState() {
    super.initState();
    _campusDataFuture = _loadUniversityData();
  }

  Future<UniversityData> _loadUniversityData() async {
    try {
      final jsonString =
      await rootBundle.loadString('assets/data/campus_data.json');
      return UniversityData.fromJsonString(jsonString);
    } catch (e) {
      // Return empty data on error
      return UniversityData(universities: {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UniversityData>(
      future: _campusDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: AppLogoLoadingWidget(size: 80)),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        return const MainContent();
      },
    );
  }
}

class MainContent extends StatefulWidget {
  const MainContent({super.key});

  @override
  State<MainContent> createState() => _MainContentState();
}

class _MainContentState extends State<MainContent> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = [
    const ChatHomeScreen(),
    const NotesScreen(),
    const GroupsTab(),
    const AnnouncementScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    int difference = (_currentIndex - index).abs();
    setState(() => _currentIndex = index);

    if(difference > 1) {
      _pageController.jumpToPage(
        index,
      );
    }else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Access the current theme data
    final theme = Theme.of(context);

    // 2. Use theme colors instead of hardcoded hex values
    final backgroundColor = theme.scaffoldBackgroundColor;
    final navBarColor = theme.cardColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: navBarColor,
          // Optional: Add a subtle shadow for elevation
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, Icons.chat_bubble_outline, "Chat"),
              _buildNavItem(1, Icons.book_outlined, "Notes"),
              _buildNavItem(2, Icons.groups_outlined, "Groups"),
              _buildNavItem(3, Icons.campaign_outlined, "Announc.."),
              _buildNavItem(4, Icons.person_outline, "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _currentIndex == index;
    final theme = Theme.of(context);

    // 3. Define Active/Inactive colors based on the theme
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurface.withOpacity(0.6);

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10), // Padding creates space for the background circle
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // 4. "Opaque" background using primary color with opacity
              color: isSelected
                  ? activeColor.withOpacity(0.2) // 20% opacity primary color
                  : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: 24,
              color: isSelected ? activeColor : inactiveColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
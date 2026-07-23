import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/loading_widget.dart';
import '../Notes/notes_screen.dart';
import '../profile/profile_screen.dart';
import '../announcement/announcements_screen.dart';
import '../chat/chat_home_screen.dart';
import '../groups/groups_screen.dart';

// Your existing Models placeholder (ensure this is imported or defined)
class UniversityData {
  final Map universities;
  UniversityData({required this.universities});
  factory UniversityData.fromJsonString(String json) => UniversityData(universities: {});
}

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
      final jsonString = await rootBundle.loadString('assets/data/campus_data.json');
      return UniversityData.fromJsonString(jsonString);
    } catch (e) {
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

    if (difference > 1) {
      _pageController.jumpToPage(index);
    } else {
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
    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;
    final navBarColor = theme.cardColor;

    // Use LayoutBuilder to dynamically check the available width
    return LayoutBuilder(
      builder: (context, constraints) {
        // Broad threshold for landscape/laptop viewing setups (typically > 600 or 720 dp)
        final bool isLandscapeWide = constraints.maxWidth >= 600;

        return Scaffold(
            backgroundColor: backgroundColor,
            body: Row(
                children: [
                // 1. Sidebar Navigation for Wide/Landscape Screens
                if (isLandscapeWide) ...[
        Container(
        decoration: BoxDecoration(
        color: navBarColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(5, 0), // Shadow cast to the right
              ),
            ],
        ),
        child: SafeArea(
        right: false,
        child: Column(
        children: [
        const SizedBox(height: 16),
        // You can place an App Logo or Profile avatar here like WhatsApp Web
        _buildSideNavItem(0, Icons.chat_bubble_outline, "Chat"),
        _buildSideNavItem(1, Icons.book_outlined, "Notes"),
        _buildSideNavItem(2, Icons.groups_outlined, "Groups"),
        _buildSideNavItem(3, Icons.campaign_outlined, "Announc.."),
        _buildSideNavItem(4, Icons.person_outline, "Profile"),
        ],
        ),
        ),
        ),
        // Subtle divider line
        VerticalDivider(thickness: 1, width: 1, color: theme.dividerColor),
        ],

        // 2. Main content pages
        Expanded(
        child: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: _screens,
        ),
        ),
        ],
        ),

        // 3. Bottom Navigation Bar for Mobile Screens Only
        bottomNavigationBar: isLandscapeWide
        ? null // Hides bottom bar on large screens
            : Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
        color: navBarColor,
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
        _buildBottomNavItem(0, Icons.chat_bubble_outline, "Chat"),
        _buildBottomNavItem(1, Icons.book_outlined, "Notes"),
        _buildBottomNavItem(2, Icons.groups_outlined, "Groups"),
        _buildBottomNavItem(3, Icons.campaign_outlined, "Announc.."),
        _buildBottomNavItem(4, Icons.person_outline, "Profile"),
        ],
        ),
        ),
        ),
        );
      },
    );
  }

  // Refactored original item for the Bottom Navigation Bar
  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIconCircle(index, icon),
          const SizedBox(height: 4),
          _buildItemLabel(index, label),
        ],
      ),
    );
  }

  // New item template engineered specifically for the Left Sidebar layout
  Widget _buildSideNavItem(int index, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIconCircle(index, icon),
            const SizedBox(height: 4),
            _buildItemLabel(index, label),
          ],
        ),
      ),
    );
  }

  // Extracted shared UI logic for icons
  Widget _buildIconCircle(int index, IconData icon) {
    final bool isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurface.withOpacity(0.6);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? activeColor.withOpacity(0.2) : Colors.transparent,
      ),
      child: Icon(
        icon,
        size: 24,
        color: isSelected ? activeColor : inactiveColor,
      ),
    );
  }

  // Extracted shared UI logic for labels
  Widget _buildItemLabel(int index, String label) {
    final bool isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurface.withOpacity(0.6);

    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected ? activeColor : inactiveColor,
      ),
    );
  }
}
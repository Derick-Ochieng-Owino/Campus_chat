import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/loading_widget.dart';
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
  Future<UniversityData>? _campusDataFuture;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _campusDataFuture = _loadUniversityData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<UniversityData> _loadUniversityData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/campus_data.json');
      return UniversityData.fromJsonString(jsonString);
    } catch (e) {
      return UniversityData(universities: {});
    }
  }

  void _navigateToPage(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UniversityData>(
      future: _campusDataFuture,
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: AppLogoLoadingWidget(size: 80)),
          );
        }

        // Handle error state
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Error loading campus data: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }

        // Handle no data state
        if (!snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Text(
                'No campus data found',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }

        final screens = [
          ChatHomeScreen(),
          NotesScreen(),
          GroupsTab(),
          AnnouncementScreen(),
          ProfileScreen(),
        ];

        return _buildMobileLayout(context, screens);
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, List<Widget> screens) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // App Bar for Mobile
          // Container(
          //   height: 70,
          //   padding: const EdgeInsets.symmetric(horizontal: 16),
          //   decoration: BoxDecoration(
          //     color: colorScheme.surface,
          //     border: Border(
          //       bottom: BorderSide(
          //         color: colorScheme.outline.withOpacity(0.1),
          //         width: 1,
          //       ),
          //     ),
          //     boxShadow: [
          //       BoxShadow(
          //         color: Colors.black.withOpacity(0.05),
          //         blurRadius: 4,
          //         offset: const Offset(0, 2),
          //       ),
          //     ],
          //   ),
          //   child: Row(
          //     children: [
          //       // App Logo
          //       Container(
          //         width: 40,
          //         height: 40,
          //         decoration: BoxDecoration(
          //           gradient: LinearGradient(
          //             colors: [colorScheme.primary, colorScheme.secondary],
          //             begin: Alignment.topLeft,
          //             end: Alignment.bottomRight,
          //           ),
          //           borderRadius: BorderRadius.circular(12),
          //         ),
          //         child: Icon(
          //           Icons.school,
          //           color: Colors.white,
          //           size: 24,
          //         ),
          //       ),
          //       const SizedBox(width: 12),
          //       // App Name
          //       Expanded(
          //         child: Column(
          //           mainAxisAlignment: MainAxisAlignment.center,
          //           crossAxisAlignment: CrossAxisAlignment.start,
          //           children: [
          //             Text(
          //               'Alma Mater',
          //               style: theme.textTheme.titleMedium?.copyWith(
          //                 fontWeight: FontWeight.bold,
          //                 color: colorScheme.onSurface,
          //               ),
          //             ),
          //             Text(
          //               'University Portal',
          //               style: theme.textTheme.bodySmall?.copyWith(
          //                 color: colorScheme.onSurface.withOpacity(0.6),
          //               ),
          //             ),
          //           ],
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          // Main Content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              children: screens,
            ),
          ),
          // Bottom Navigation for Mobile
          _buildMobileBottomNav(colorScheme),
        ],
      ),
    );
  }

  Widget _buildMobileBottomNav(ColorScheme colorScheme) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _navigateToPage,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.message_outlined),
          selectedIcon: Icon(Icons.message),
          label: 'Chats',
        ),
        NavigationDestination(
          icon: Icon(Icons.book_outlined),
          selectedIcon: Icon(Icons.book),
          label: 'Notes',
        ),
        NavigationDestination(
          icon: Icon(Icons.group_outlined),
          selectedIcon: Icon(Icons.group),
          label: 'Groups',
        ),
        NavigationDestination(
          icon: Icon(Icons.campaign_outlined),
          selectedIcon: Icon(Icons.campaign),
          label: 'Announcements',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outlined),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile_model.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showBackOfCard = false;

  //CHECK ON THIS LATER
  // Semester dates - you can fetch these from Firestore or hardcode
  final DateTime _semesterStart = DateTime(2026, 1, 15); // Example: Jan 15
  final DateTime _semesterEnd = DateTime(2026, 5, 15); // Example: May 15

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (user == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: Text(
            'No active authentication profile session.',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary.withOpacity(0.6),
        elevation: theme.appBarTheme.elevation,
        title: Text(
          'Student Hub Profile',
          style: theme.appBarTheme.titleTextStyle,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: colorScheme.onSurface),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading profile stream context.',
                style: TextStyle(color: colorScheme.error),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.secondary),
            );
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final profile = UserProfile.fromMap(data, user.uid);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Flippable Digital Student Identity Badge ---
                GestureDetector(
                  onTap: () => setState(() => _showBackOfCard = !_showBackOfCard),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return rotationYTransform(animation, child);
                    },
                    child: _showBackOfCard ? _buildCardBack(profile) : _buildCardFront(profile, theme),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flip_camera_android_rounded, size: 14, color: colorScheme.onSurface.withOpacity(0.5)),
                      const SizedBox(width: 6),
                      Text(
                        'Tap card to view verification flip-side',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // --- NEW: Semester Progress Card ---
                _buildSemesterProgressCard(profile, theme),

                const SizedBox(height: 28),

                // --- Units List Section ---
                _buildUnitsList(profile, theme),

                const SizedBox(height: 28),

                // --- Auxiliary Details ---
                _buildAuxiliaryDetails(profile, theme),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- NEW: Semester Progress Card ---
  Widget _buildSemesterProgressCard(UserProfile profile, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final units = profile.registeredUnits;

    // Calculate progress based on semester dates
    final double semesterProgress = _calculateSemesterProgress();
    final int daysRemaining = _calculateDaysRemaining();
    final int totalUnits = units.length;
    final int completedUnits = units.where((u) =>
    u['status']?.toString().toLowerCase() == 'completed' ||
        u['progress'] == 1.0
    ).length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Semester Progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Academic Year ${profile.year} • Semester ${profile.semester}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$daysRemaining days left',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Main Progress
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Overall Progress',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${(semesterProgress * 100).toInt()}%',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: semesterProgress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Quick stats
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        label: 'Total',
                        value: '$totalUnits',
                        color: Colors.white,
                      ),
                      _buildStatItem(
                        label: 'Completed',
                        value: '$completedUnits',
                        color: Colors.green.shade300,
                      ),
                      _buildStatItem(
                        label: 'Remaining',
                        value: '${totalUnits - completedUnits}',
                        color: Colors.orange.shade300,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper: Stat Item ---
  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // --- NEW: Units List ---
  Widget _buildUnitsList(UserProfile profile, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final units = profile.registeredUnits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Registered Units',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (units.isNotEmpty)
              Text(
                '${units.length} units',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        if (units.isEmpty)
          _buildEmptyState(theme)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: units.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final unit = units[index];
              final unitCode = unit['code']?.toString() ?? 'UNIT-000';
              final unitTitle = unit['title']?.toString() ?? 'Course Unit';
              final progress = (unit['progress'] ?? 0.0).toDouble();
              final status = unit['status']?.toString() ?? 'Active';

              return _buildUnitListItem(
                unitCode: unitCode,
                unitTitle: unitTitle,
                progress: progress,
                status: status,
                theme: theme,
              );
            },
          ),
      ],
    );
  }

  // --- NEW: Unit List Item ---
  Widget _buildUnitListItem({
    required String unitCode,
    required String unitTitle,
    required double progress,
    required String status,
    required ThemeData theme,
  }) {
    final colorScheme = theme.colorScheme;
    final isCompleted = progress >= 1.0 || status.toLowerCase() == 'completed';
    final statusColor = isCompleted ? Colors.green : colorScheme.secondary;
    final statusText = isCompleted ? 'Completed' : 'In Progress';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),

          // Main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        unitTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        unitCode,
                        style: TextStyle(
                          color: colorScheme.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: colorScheme.onSurface.withOpacity(0.08),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isCompleted ? Colors.green : colorScheme.secondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Empty State ---
  Widget _buildEmptyState(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.onSurface.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.school_outlined,
            size: 48,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No Registered Units',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your registered units will appear here\nafter enrollment.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Methods for Semester Calculation ---
  double _calculateSemesterProgress() {
    final now = DateTime.now();
    final totalDuration = _semesterEnd.difference(_semesterStart).inDays;
    final elapsedDuration = now.difference(_semesterStart).inDays;

    if (now.isBefore(_semesterStart)) return 0.0;
    if (now.isAfter(_semesterEnd)) return 1.0;

    return (elapsedDuration / totalDuration).clamp(0.0, 1.0);
  }

  int _calculateDaysRemaining() {
    final now = DateTime.now();
    final daysRemaining = _semesterEnd.difference(now).inDays;
    return daysRemaining > 0 ? daysRemaining : 0;
  }

  // --- Auxiliary Details ---
  Widget _buildAuxiliaryDetails(UserProfile profile, ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Academic Information',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.onSurface.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildInfoTile(
                theme: theme,
                icon: Icons.badge_outlined,
                label: 'Student ID',
                value: profile.regNumber.toUpperCase(),
                color: colorScheme.primary,
              ),
              _buildDivider(theme),
              _buildInfoTile(
                theme: theme,
                icon: Icons.calendar_today_outlined,
                label: 'Academic Year',
                value: 'Year ${profile.year}, Semester ${profile.semester}',
                color: colorScheme.secondary,
              ),
              _buildDivider(theme),
              _buildInfoTile(
                theme: theme,
                icon: Icons.location_on_outlined,
                label: 'Campus',
                value: profile.campus,
                color: Colors.orange,
              ),
              if (profile.firstName.isNotEmpty) ...[
                _buildDivider(theme),
                _buildInfoTile(
                  theme: theme,
                  icon: Icons.tag_outlined,
                  label: 'Profile Tag',
                  value: profile.firstName,
                  color: Colors.purple,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // --- Helper: Info Tile ---
  Widget _buildInfoTile({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      color: theme.dividerTheme.color,
      height: 1,
      indent: 16,
      endIndent: 16,
    );
  }

  // --- Original Card Front (unchanged) ---
  Widget _buildCardFront(UserProfile profile, ThemeData theme) {
    const darkTextColor = Color(0xFF111111);

    return Container(
      key: const ValueKey(true),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFBEF7BC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9CCC65), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: 110,
                height: 110,
                child: Image.asset(
                  'assets/images/jkuat_logo.png',
                  fit: BoxFit.contain,
                  opacity: const AlwaysStoppedAnimation(0.12),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: JkuatCardPatternPainter(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/jkuat_logo.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.university.split('&')[0].trim(),
                            style: const TextStyle(color: darkTextColor, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                          ),
                          if (profile.university.contains('&'))
                            Text(
                              '& ${profile.university.split('&')[1].trim()}',
                              style: const TextStyle(color: darkTextColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                            ),
                          const SizedBox(height: 2),
                          const Text(
                            '"A University of global excellence in Training, Research, Innovation and Entrepreneurship for development."',
                            style: TextStyle(color: Colors.black87, fontSize: 7, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            color: const Color(0xFFC62828),
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: const Text(
                              'STUDENT IDENTIFICATION CARD',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                            ),
                          ),
                          Text(
                            profile.firstName,
                            style: const TextStyle(color: darkTextColor, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                          ),
                          const SizedBox(height: 10),
                          const Text('COURSE', style: TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.bold)),
                          Text(
                            profile.course,
                            style: const TextStyle(color: darkTextColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          const Text('REG NO', style: TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.bold)),
                          Text(
                            profile.regNumber,
                            style: const TextStyle(color: darkTextColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 10),
                          const Text('COLLEGE', style: TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.bold)),
                          Text(
                            profile.college,
                            style: const TextStyle(color: darkTextColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        Container(
                          width: 85,
                          height: 105,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D1D6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black26, width: 1.5),
                            image: profile.profilePhotoUrl != null
                                ? DecorationImage(image: NetworkImage(profile.profilePhotoUrl!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: profile.profilePhotoUrl == null ? const Icon(Icons.person_rounded, size: 40, color: Colors.black38) : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'VALID: ${profile.validityPeriod}',
                          style: const TextStyle(color: darkTextColor, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Original Card Back (unchanged) ---
  Widget _buildCardBack(UserProfile profile) {
    return Container(
      key: const ValueKey(false),
      width: double.infinity,
      height: 226,
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'IF FOUND RETURN TO JKUAT MAIN CAMPUS,\nOR POST TO P.O. BOX 62000-00200, NRB. Kenya.\nTel: 254-67-52711/52181-4 Fax: 254-67-52164\nwww.jkuat.ac.ke',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.bold, height: 1.4),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              Container(
                width: 180,
                height: 38,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage('https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/Bar_code_128.svg/800px-Bar_code_128.svg.png'),
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.regNumber,
                style: const TextStyle(color: Colors.black, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('------------------', style: TextStyle(color: Colors.black38, fontSize: 10)),
                  SizedBox(height: 2),
                  Text('Student Signature', style: TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(Icons.gavel_rounded, color: Colors.blueAccent, size: 20),
              )
            ],
          )
        ],
      ),
    );
  }

  // --- Original Rotation Transform ---
  Widget rotationYTransform(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final angle = animation.value * 3.141592653589793;
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          alignment: Alignment.center,
          child: angle >= 1.5707963267948966
              ? Transform(
            transform: Matrix4.identity()..rotateY(3.141592653589793),
            alignment: Alignment.center,
            child: child,
          )
              : child,
        );
      },
    );
  }
}

// --- Original Pattern Painter (unchanged) ---
class JkuatCardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset centerPoint = Offset(size.width / 2, size.height / 2);
    const double plainSpaceRadius = 48.0;

    final Path totalCanvasPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final Path clearCirclePath = Path()
      ..addOval(Rect.fromCircle(center: centerPoint, radius: plainSpaceRadius));

    final Path gridMaskPath = Path.combine(
      PathOperation.difference,
      totalCanvasPath,
      clearCirclePath,
    );

    canvas.save();
    canvas.clipPath(gridMaskPath);

    final Paint linePaint = Paint()
      ..color = const Color(0xFF1B5E20).withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    final Paint fillPaint = Paint()
      ..color = const Color(0xFF1B5E20).withOpacity(0.03)
      ..style = PaintingStyle.fill;

    const double triangleWidth = 24.0;
    const double triangleHeight = triangleWidth * 0.866025;

    final int colCount = (size.width / triangleWidth).ceil() + 1;
    final int rowCount = (size.height / triangleHeight).ceil() + 1;

    for (int row = -1; row <= rowCount; row++) {
      for (int col = -1; col <= colCount; col++) {
        final double xOffset = (row % 2 == 0) ? 0 : triangleWidth / 2;

        final double currentX = col * triangleWidth + xOffset;
        final double currentY = row * triangleHeight;

        final double nextX = currentX + triangleWidth;
        final double bottomX = currentX - (row % 2 == 0 ? -triangleWidth / 2 : triangleWidth / 2);
        final double bottomY = currentY + triangleHeight;
        final double nextBottomX = bottomX + triangleWidth;

        final Path pathA = Path()
          ..moveTo(currentX, currentY)
          ..lineTo(nextX, currentY)
          ..lineTo(nextBottomX, bottomY)
          ..close();

        final Path pathB = Path()
          ..moveTo(currentX, currentY)
          ..lineTo(bottomX, bottomY)
          ..lineTo(nextBottomX, bottomY)
          ..close();

        if ((col + row) % 2 == 0) {
          canvas.drawPath(pathA, fillPaint);
        } else {
          canvas.drawPath(pathB, fillPaint);
        }

        canvas.drawPath(pathA, linePaint);
        canvas.drawPath(pathB, linePaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
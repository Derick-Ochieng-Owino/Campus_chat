import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import '../../widgets/theme_manager.dart';

class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _currentUserProfile;
  String? _currentUserId;
  String? _fullCoursePath;
  String? _academicYear;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;

    _currentUserId = user.uid;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!mounted) return;

      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          _currentUserProfile = data;
          _fullCoursePath = data['fullCoursePath'];
          _academicYear = data['academicYear'];
        });
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  bool _hasAdminPrivileges() {
    if (_currentUserProfile == null) return false;
    final role = _currentUserProfile!['role']?.toString().toLowerCase();
    return role == 'admin' || role == 'class_rep' || role == 'assistant' || role == 'lecturer';
  }

  // Get user's current courses for this semester
  Future<List<Map<String, dynamic>>> _getCurrentCourses() async {
    if (_currentUserProfile == null) return [];

    try {
      final query = await _firestore
          .collection('courseUnits')
          .where('university', isEqualTo: _currentUserProfile!['university'])
          .where('campus', isEqualTo: _currentUserProfile!['campus'])
          .where('college', isEqualTo: _currentUserProfile!['college'])
          .where('school', isEqualTo: _currentUserProfile!['school'])
          .where('department', isEqualTo: _currentUserProfile!['department'])
          .where('course', isEqualTo: _currentUserProfile!['course'])
          .where('year', isEqualTo: _currentUserProfile!['year'])
          .where('semester', isEqualTo: _currentUserProfile!['semester'])
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'code': data['code'],
          'title': data['title'],
          'type': data['type'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading courses: $e');
      return [];
    }
  }

    void _showSnackbar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Study Groups', style: theme.textTheme.titleLarge),
              if (_academicYear != null)
                Text(
                  '$_academicYear',
                  style: theme.textTheme.bodySmall!.copyWith(color: theme.disabledColor),
                ),
            ],
          ),
          backgroundColor: colorScheme.surface,
          foregroundColor: theme.appBarTheme.foregroundColor,
          elevation: theme.appBarTheme.elevation,
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Class Groups'),
              Tab(text: 'Course Groups'),
            ],
            labelColor: colorScheme.primary,
            unselectedLabelColor: theme.disabledColor,
            indicatorColor: colorScheme.primary,
          ),
        ),
        body: _fullCoursePath == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            // Tab 1: Class Groups (Same as before, filtered by full course)
            _buildClassGroupsTab(theme),

            // Tab 2: Course-Specific Groups
            _buildCourseGroupsTab(theme),
          ],
        ),
        floatingActionButton: _hasAdminPrivileges()
            ? FloatingActionButton(
          backgroundColor: colorScheme.secondary,
          onPressed: _showCreateGroupDialog,
          child: Icon(Icons.add, color: colorScheme.onSecondary),
        )
            : null,
      ),
    );
  }

  Widget _buildClassGroupsTab(ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('groups')
          .where('fullCoursePath', isEqualTo: _fullCoursePath)
          .where('year', isEqualTo: _currentUserProfile!['year'])
          .where('semester', isEqualTo: _currentUserProfile!['semester'])
          .where('courseCode', isNull: true) // Class groups don't have specific course code
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildShimmerLoading(theme);
        }

        final groups = snapshot.data!.docs;
        if (groups.isEmpty) {
          return _buildEmptyState(
            theme,
            icon: Icons.group_outlined,
            message: 'No class groups yet',
            actionText: 'Create First Group',
            onAction: _showCreateClassGroupDialog,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: groups.length,
          itemBuilder: (context, index) =>
              _buildGroupWidget(groups[index], index, theme, isCourseGroup: false),
        );
      },
    );
  }

  Widget _buildCourseGroupsTab(ThemeData theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getCurrentCourses(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildShimmerLoading(theme);
        }

        final courses = snapshot.data!;
        if (courses.isEmpty) {
          return _buildEmptyState(
            theme,
            icon: Icons.menu_book_outlined,
            message: 'No courses found for this semester',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: courses.length,
          itemBuilder: (context, index) {
            final course = courses[index];
            return _buildCourseGroupSection(course, theme);
          },
        );
      },
    );
  }

  Widget _buildCourseGroupSection(Map<String, dynamic> course, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('groups')
          .where('fullCoursePath', isEqualTo: _fullCoursePath)
          .where('year', isEqualTo: _currentUserProfile!['year'])
          .where('semester', isEqualTo: _currentUserProfile!['semester'])
          .where('courseCode', isEqualTo: course['code'])
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        final groups = snapshot.data?.docs ?? [];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: course['type'] == 'CORE'
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        course['code'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: course['type'] == 'CORE' ? Colors.blue : Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course['title'],
                            style: theme.textTheme.bodyMedium!.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            course['type'],
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Groups for this course
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.group_add_outlined,
                            size: 48,
                            color: theme.disabledColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No study groups for this course',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => _showCreateCourseGroupDialog(course),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.secondary,
                            ),
                            child: const Text('Create Study Group'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...groups.map((group) =>
                      _buildGroupWidget(group, groups.indexOf(group), theme, isCourseGroup: true)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupWidget(
      QueryDocumentSnapshot group,
      int index,
      ThemeData theme, {
        required bool isCourseGroup,
      }) {
    final groupData = group.data() as Map<String, dynamic>;
    final colorScheme = theme.colorScheme;

    final groupName = groupData['name'] ?? 'Group';
    final groupA = groupData['A'] as List<dynamic>? ?? [];
    final groupB = groupData['B'] as List<dynamic>? ?? [];
    final totalMembers = groupA.length + groupB.length;
    final courseCode = groupData['courseCode'];

    final accentList = [
      colorScheme.secondary,
      colorScheme.primary,
      kSunsetOrange.withOpacity(0.7),
      kAmberGold.withOpacity(0.6),
      kRoyalPurple.withOpacity(0.8),
    ];
    final accent = accentList[index % accentList.length];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () => _showGroupModal(group, isCourseGroup),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withOpacity(0.18), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCourseGroup ? Icons.menu_book : Icons.group,
                    size: 32,
                    color: accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                        if (isCourseGroup && courseCode != null)
                          Text(
                            courseCode,
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                        Text(
                          '${totalMembers} member${totalMembers != 1 ? 's' : ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _getBadgeBgColor(totalMembers),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: _getBadgeColor(totalMembers), width: 1.5),
                    ),
                    child: Text(
                      totalMembers.toString(),
                      style: TextStyle(
                        color: _getBadgeColor(totalMembers),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildSubdivisionBadge('A', groupA.length, Colors.blue),
                  const SizedBox(width: 8),
                  _buildSubdivisionBadge('B', groupB.length, Colors.green),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBadgeColor(int members) {
    if (members <= 4) return Colors.redAccent;
    if (members <= 7) return Colors.amberAccent;
    return Colors.greenAccent;
  }

  Color _getBadgeBgColor(int members) => _getBadgeColor(members).withOpacity(0.18);

  Widget _buildSubdivisionBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $count/5',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(ThemeData theme) {
    final base = theme.cardColor;
    final highlight = theme.dividerColor.withOpacity(0.15);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: base.withOpacity(0.6),
        highlightColor: highlight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          height: 90,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      ThemeData theme, {
        required IconData icon,
        required String message,
        String? actionText,
        VoidCallback? onAction,
      }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
              ),
              child: Text(actionText),
            ),
          ],
        ],
      ),
    );
  }

  // Create Group Dialog
  Future<void> _showCreateGroupDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Group'),
          content: const Text('What type of group would you like to create?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('class'),
              child: const Text('Class Group'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('course'),
              child: const Text('Course Study Group'),
            ),
          ],
        );
      },
    );

    if (choice == 'class') {
      await _showCreateClassGroupDialog();
    } else if (choice == 'course') {
      await _showCourseSelectionDialog();
    }
  }

  Future<void> _showCreateClassGroupDialog() async {
    if (_currentUserProfile == null) return;

    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text('Create Class Group', style: theme.textTheme.titleMedium),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'e.g., Study Group 1',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'What is this group for?',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Group name is required')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _createClassGroup(
        name: nameController.text.trim(),
        description: descController.text.trim(),
      );
    }
  }

  Future<void> _showCourseSelectionDialog() async {
    final courses = await _getCurrentCourses();

    if (courses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No courses found for this semester')),
      );
      return;
    }

    final selectedCourse = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Course'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];
                return ListTile(
                  leading: Icon(
                    course['type'] == 'CORE' ? Icons.book : Icons.auto_stories,
                    color: course['type'] == 'CORE' ? Colors.blue : Colors.green,
                  ),
                  title: Text(course['code']),
                  subtitle: Text(course['title']),
                  onTap: () => Navigator.of(context).pop(course),
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedCourse != null) {
      await _showCreateCourseGroupDialog(selectedCourse);
    }
  }

  Future<void> _showCreateCourseGroupDialog(Map<String, dynamic> course) async {
    final nameController = TextEditingController(
      text: '${course['code']} Study Group',
    );
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Study Group', style: theme.textTheme.titleMedium),
              Text(
                course['code'],
                style: theme.textTheme.bodySmall!.copyWith(color: theme.disabledColor),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'e.g., For group assignments and study sessions',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Group name is required')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _createCourseGroup(
        name: nameController.text.trim(),
        description: descController.text.trim(),
        courseCode: course['code'],
        courseTitle: course['title'],
      );
    }
  }

  Future<void> _createClassGroup({
    required String name,
    required String description,
  }) async {
    if (_currentUserProfile == null) return;

    try {
      await _firestore.collection('groups').add({
        'name': name,
        'description': description,

        // University hierarchy
        'university': _currentUserProfile!['university'],
        'campus': _currentUserProfile!['campus'],
        'college': _currentUserProfile!['college'],
        'school': _currentUserProfile!['school'],
        'department': _currentUserProfile!['department'],
        'course': _currentUserProfile!['course'],
        'year': _currentUserProfile!['year'],
        'semester': _currentUserProfile!['semester'],

        // Computed fields
        'fullCoursePath': _fullCoursePath,
        'academicYear': _academicYear,
        'courseCode': null, // No specific course for class groups

        // Group structure
        'A': [],
        'B': [],
        'maxPerSubdivision': 5,
        'type': 'class', // class or course

        // Metadata
        'createdBy': _currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group "$name" created successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create group: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _createCourseGroup({
    required String name,
    required String description,
    required String courseCode,
    required String courseTitle,
  }) async {
    if (_currentUserProfile == null) return;

    try {
      await _firestore.collection('groups').add({
        'name': name,
        'description': description,

        // University hierarchy
        'university': _currentUserProfile!['university'],
        'campus': _currentUserProfile!['campus'],
        'college': _currentUserProfile!['college'],
        'school': _currentUserProfile!['school'],
        'department': _currentUserProfile!['department'],
        'course': _currentUserProfile!['course'],
        'year': _currentUserProfile!['year'],
        'semester': _currentUserProfile!['semester'],

        // Course-specific
        'courseCode': courseCode,
        'courseTitle': courseTitle,

        // Computed fields
        'fullCoursePath': _fullCoursePath,
        'academicYear': _academicYear,

        // Group structure
        'A': [],
        'B': [],
        'maxPerSubdivision': 5,
        'type': 'course',

        // Metadata
        'createdBy': _currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Study group for $courseCode created successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create group: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Run this once to populate your Firestore with course units
  Future<void> populateCourseUnits() async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Load JSON from assets
      final jsonString = await rootBundle.loadString('assets/data/campus_data.json');
      final Map<String, dynamic> universitiesJson = json.decode(jsonString);

      // Counter for tracking
      int unitsAdded = 0;
      int batchCount = 0;
      WriteBatch batch = firestore.batch();

      for (final uniEntry in universitiesJson['universities'].entries) {
        final university = uniEntry.key;
        final uniData = uniEntry.value;

        for (final campusEntry in uniData['campuses'].entries) {
          final campus = campusEntry.key;
          final campusData = campusEntry.value;

          for (final collegeEntry in campusData['colleges'].entries) {
            final college = collegeEntry.key;
            final collegeData = collegeEntry.value;

            for (final schoolEntry in collegeData['schools'].entries) {
              final school = schoolEntry.key;
              final schoolData = schoolEntry.value;

              for (final deptEntry in schoolData['departments'].entries) {
                final department = deptEntry.key;
                final deptData = deptEntry.value;

                for (final courseEntry in deptData['courses'].entries) {
                  final course = courseEntry.key;
                  final courseData = courseEntry.value;

                  // Check if courses has years
                  if (courseData['years'] != null) {
                    for (final yearEntry in courseData['years'].entries) {
                      final year = int.parse(yearEntry.key.trim());
                      final yearData = yearEntry.value;

                      for (final semesterEntry in yearData.entries) {
                        final semesterKey = semesterEntry.key;
                        // Handle both "1" and "semester1" format
                        final semester = semesterKey.contains('semester')
                            ? int.parse(semesterKey.replaceAll('semester', '').trim())
                            : int.parse(semesterKey.trim());

                        final units = semesterEntry.value as List;

                        for (final unit in units) {
                          final docRef = firestore.collection('courseUnits').doc();

                          batch.set(docRef, {
                            'university': university,
                            'campus': campus,
                            'college': college,
                            'school': school,
                            'department': department,
                            'course': course,
                            'year': year,
                            'semester': semester,
                            'code': unit['code'],
                            'title': unit['title'],
                            'type': unit['type'],
                            'credits': unit['credits'] ?? 3, // Default to 3 if not specified
                            'id': docRef.id,
                            'createdAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          unitsAdded++;
                          batchCount++;

                          // Commit batch every 500 operations (Firestore limit)
                          if (batchCount >= 500) {
                            await batch.commit();
                            batch = firestore.batch();
                            batchCount = 0;
                            debugPrint('Batch committed. Total units: $unitsAdded');
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Commit any remaining operations
      if (batchCount > 0) {
        await batch.commit();
      }

      debugPrint('✅ Successfully added $unitsAdded course units to Firestore');

    } catch (e) {
      debugPrint('❌ Error populating course units: $e');
      rethrow;
    }
  }

  Future<void> _showGroupModal(QueryDocumentSnapshot group, bool isCourseGroup) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData == null) return;

    final userGroupId = userData['groupId'] as String?;
    final userSubdivision = userData['subdivision'] as String?;
    final userName = (userData['name'] as String?) ?? 'User';

    final latestGroupSnap = await _firestore.collection('groups').doc(group.id).get();
    final groupData = latestGroupSnap.data();
    if (groupData == null) return;

    final groupA = (groupData['A'] as List<dynamic>?)
        ?.map((m) => m as Map<String, dynamic>)
        .toList() ??
        [];
    final groupB = (groupData['B'] as List<dynamic>?)
        ?.map((m) => m as Map<String, dynamic>)
        .toList() ??
        [];

    final isMember = userGroupId == group.id;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  groupData['name'] ?? 'Group',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Text('Group A', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${groupA.length}/5'),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: groupA.length,
                  itemBuilder: (_, index) {
                    final member = groupA[index];
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(member['name'] ?? 'Unknown'),
                    );
                  },
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Text('Group B', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${groupB.length}/5'),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: groupB.length,
                  itemBuilder: (_, index) {
                    final member = groupB[index];
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(member['name'] ?? 'Unknown'),
                    );
                  },
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMember ? Colors.red[100] : Colors.green[100],
                        ),
                        onPressed: () async {
                          if (isMember) {
                            if (userSubdivision != null) {
                              await _leaveSubdivision(group, user.uid, userSubdivision);
                            }
                          } else if (userGroupId == null) {
                            final selected = await showDialog<String>(
                              context: ctx,
                              builder: (ctx2) {
                                return AlertDialog(
                                  title: const Text('Select Subdivision'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton(
                                        onPressed: groupA.length < 5 ? () => Navigator.of(ctx2).pop('A') : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: groupA.length < 5 ? Colors.green[100] : Colors.grey[200],
                                          foregroundColor: groupA.length < 5 ? Colors.green[800] : Colors.grey[500],
                                        ),
                                        child: Text('Join Group A (${groupA.length}/5)'),
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton(
                                        onPressed: groupB.length < 5 ? () => Navigator.of(ctx2).pop('B') : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: groupB.length < 5 ? Colors.green[100] : Colors.grey[200],
                                          foregroundColor: groupB.length < 5 ? Colors.green[800] : Colors.grey[500],
                                        ),
                                        child: Text('Join Group B (${groupB.length}/5)'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );

                            if (selected != null) {
                              await _joinSubdivision(group, user.uid, userName, selected);
                            }
                          }
                          if (context.mounted) Navigator.of(ctx).pop();
                        },
                        child: Text(
                          isMember ? 'Leave Group' : 'Join Group',
                          style: TextStyle(color: isMember ? Colors.red : Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!isMember && userGroupId != null)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
                          onPressed: null,
                          child: const Text('Already in another group', style: TextStyle(color: Colors.black)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

    Future<void> _joinSubdivision(
      QueryDocumentSnapshot group,
      String uid,
      String name,
      String sub,
      ) async {
    final userRef = _firestore.collection('users').doc(uid);
    final groupRef = _firestore.collection('groups').doc(group.id);

    try {
      await _firestore.runTransaction((tx) async {
        final userSnap = await tx.get(userRef);
        final groupSnap = await tx.get(groupRef);

        if (userSnap.exists && userSnap.data()?['groupId'] != null) {
          throw Exception("You are already a member of a group.");
        }

        final members = (groupSnap.data()?[sub] as List<dynamic>?) ?? [];
        if (members.length >= 5) {
          throw Exception("The selected subdivision is full (Max 5).");
        }

        members.add({'uid': uid, 'name': name});

        tx.update(groupRef, {sub: members});
        tx.update(userRef, {'groupId': group.id, 'subdivision': sub});
      });
      _showSnackbar('Successfully joined ${group['name']} ($sub)!');
    } catch (e) {
      final errorMessage = e.toString().split(':').last.trim();
      _showSnackbar(errorMessage, isError: true);
    }
  }

  Future<void> _leaveSubdivision(
      QueryDocumentSnapshot group,
      String uid,
      String sub,
      ) async {
    final userRef = _firestore.collection('users').doc(uid);
    final groupRef = _firestore.collection('groups').doc(group.id);

    try {
      await _firestore.runTransaction((tx) async {
        final groupSnap = await tx.get(groupRef);
        final members = (groupSnap.data()?[sub] as List<dynamic>?) ?? [];
        members.removeWhere((m) => m['uid'] == uid);

        tx.update(groupRef, {sub: members});
        tx.update(userRef, {
          'groupId': FieldValue.delete(),
          'subdivision': FieldValue.delete(),
        });
      });
      _showSnackbar('Successfully left ${group['name']}!');
    } catch (e) {
      _showSnackbar('Failed to leave group: ${e.toString().split(':').last.trim()}', isError: true);
    }
  }
}
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:shimmer/shimmer.dart';
//
// import '../../widgets/theme_manager.dart';
//
// class GroupsTab extends StatefulWidget {
//   const GroupsTab({super.key});
//
//   @override
//   State<GroupsTab> createState() => _GroupsTabState();
// }
//
// class _GroupsTabState extends State<GroupsTab> with AutomaticKeepAliveClientMixin {
//   @override
//   bool get wantKeepAlive => true;
//
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   String? _currentUserRole;
//   String? _currentUserId;
//   String? _currentUserCourseId;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadCurrentUser();
//   }
//
//   Future<void> _loadCurrentUser() async {
//     final user = _auth.currentUser;
//
//     if (!mounted || user == null) return;
//
//     _currentUserId = user.uid;
//
//     try {
//       final userDoc = await _firestore.collection('users').doc(user.uid).get();
//       final data = userDoc.data();
//       if (!mounted) return;
//       if (data != null) {
//         setState(() {
//           // guard against unexpected types / capitalization
//           final role = data['role'];
//           _currentUserRole = role is String ? role.toLowerCase() : null;
//           _currentUserCourseId = data['courseId'];
//         });
//       }
//     } catch (e) {
//       debugPrint('Error loading current user role: $e');
//     }
//   }
//
//   bool _hasAdminPrivileges() {
//     final role = _currentUserRole?.toLowerCase();
//     return role == 'admin' || role == 'class_rep' || role == 'assistant';
//   }
//
//   // Keep the original red/yellow/green badge logic
//   Color _getBadgeColor(int members) {
//     if (members <= 4) return Colors.redAccent;
//     if (members <= 7) return Colors.amberAccent;
//     return Colors.greenAccent;
//   }
//
//   Color _getBadgeBgColor(int members) => _getBadgeColor(members).withOpacity(0.18);
//
//   void _showSnackbar(String message, {bool isError = false}) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           backgroundColor: isError ? Colors.red : Colors.green,
//         ),
//       );
//     }
//   }
//
//   Future<void> _joinSubdivision(
//       QueryDocumentSnapshot group,
//       String uid,
//       String name,
//       String sub,
//       ) async {
//     final userRef = _firestore.collection('users').doc(uid);
//     final groupRef = _firestore.collection('groups').doc(group.id);
//
//     try {
//       await _firestore.runTransaction((tx) async {
//         final userSnap = await tx.get(userRef);
//         final groupSnap = await tx.get(groupRef);
//
//         if (userSnap.exists && userSnap.data()?['groupId'] != null) {
//           throw Exception("You are already a member of a group.");
//         }
//
//         final members = (groupSnap.data()?[sub] as List<dynamic>?) ?? [];
//         if (members.length >= 5) {
//           throw Exception("The selected subdivision is full (Max 5).");
//         }
//
//         members.add({'uid': uid, 'name': name});
//
//         tx.update(groupRef, {sub: members});
//         tx.update(userRef, {'groupId': group.id, 'subdivision': sub});
//       });
//       _showSnackbar('Successfully joined ${group['name']} ($sub)!');
//     } catch (e) {
//       final errorMessage = e.toString().split(':').last.trim();
//       _showSnackbar(errorMessage, isError: true);
//     }
//   }
//
//   Future<void> _leaveSubdivision(
//       QueryDocumentSnapshot group,
//       String uid,
//       String sub,
//       ) async {
//     final userRef = _firestore.collection('users').doc(uid);
//     final groupRef = _firestore.collection('groups').doc(group.id);
//
//     try {
//       await _firestore.runTransaction((tx) async {
//         final groupSnap = await tx.get(groupRef);
//         final members = (groupSnap.data()?[sub] as List<dynamic>?) ?? [];
//         members.removeWhere((m) => m['uid'] == uid);
//
//         tx.update(groupRef, {sub: members});
//         tx.update(userRef, {
//           'groupId': FieldValue.delete(),
//           'subdivision': FieldValue.delete(),
//         });
//       });
//       _showSnackbar('Successfully left ${group['name']}!');
//     } catch (e) {
//       _showSnackbar('Failed to leave group: ${e.toString().split(':').last.trim()}', isError: true);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     super.build(context); // important for AutomaticKeepAliveClientMixin
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//
//     return Scaffold(
//       backgroundColor: theme.scaffoldBackgroundColor,
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         title: Text('Class Groups', style: theme.textTheme.titleLarge),
//         backgroundColor: colorScheme.surface,
//         foregroundColor: theme.appBarTheme.foregroundColor,
//         elevation: theme.appBarTheme.elevation,
//       ),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: _firestore
//             .collection('groups')
//             .where('courseId', isEqualTo: _currentUserCourseId)
//             .orderBy('name')
//             .snapshots(),
//
//         builder: (context, snapshot) {
//           if (!snapshot.hasData) {
//             return _buildShimmerLoading(theme);
//           }
//
//           final groups = snapshot.data!.docs;
//           if (groups.isEmpty) {
//             return Center(
//               child: Text('No groups yet', style: theme.textTheme.bodyMedium),
//             );
//           }
//
//           return ListView.builder(
//             padding: const EdgeInsets.all(12),
//             itemCount: groups.length,
//             itemBuilder: (context, index) => _buildGroupWidget(groups[index], index, theme),
//           );
//         },
//       ),
//       floatingActionButton: _hasAdminPrivileges()
//           ? FloatingActionButton(
//         backgroundColor: colorScheme.secondary,
//         onPressed: _addNewGroup,
//         child: Icon(Icons.add, color: colorScheme.onSecondary),
//       )
//           : null,
//     );
//   }
//
//   // Build each group card — now theme-consistent, keeps the original badge colours
//   Widget _buildGroupWidget(QueryDocumentSnapshot group, int index, ThemeData theme) {
//     final colorScheme = theme.colorScheme;
//
//     final groupName = (group.data() as Map<String, dynamic>?)?['name'] as String? ?? 'Group';
//     final groupA = (group.data() as Map<String, dynamic>?)?['A'] as List<dynamic>? ?? [];
//     final groupB = (group.data() as Map<String, dynamic>?)?['B'] as List<dynamic>? ?? [];
//     final totalMembers = groupA.length + groupB.length;
//
//     // Accent choice rotates through a small set that plays nicely with the app theme
//     final accentList = [
//       colorScheme.secondary,
//       colorScheme.primary,
//       kSunsetOrange.withOpacity(0.7),
//       kAmberGold.withOpacity(0.6),
//       kRoyalPurple.withOpacity(0.8),
//     ];
//     final accent = accentList[index % accentList.length];
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: GestureDetector(
//         onTap: () => _showGroupModal(group),
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
//           decoration: BoxDecoration(
//             color: theme.cardColor,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: accent.withOpacity(0.18), width: 1),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black26,
//                 blurRadius: 6,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//           child: Row(
//             children: [
//               Icon(Icons.group, size: 32, color: accent),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Text(
//                   groupName,
//                   style: theme.textTheme.bodyMedium!.copyWith(
//                     fontWeight: FontWeight.bold,
//                     color: accent,
//                   ),
//                 ),
//               ),
//               Container(
//                 width: 50,
//                 height: 50,
//                 alignment: Alignment.center,
//                 decoration: BoxDecoration(
//                   color: _getBadgeBgColor(totalMembers),
//                   borderRadius: BorderRadius.circular(25),
//                   border: Border.all(color: _getBadgeColor(totalMembers), width: 1.5),
//                 ),
//                 child: Text(
//                   totalMembers.toString(),
//                   style: TextStyle(
//                     color: _getBadgeColor(totalMembers),
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildShimmerLoading(ThemeData theme) {
//     final base = theme.cardColor;
//     final highlight = theme.dividerColor.withOpacity(0.15);
//
//     return ListView.builder(
//       padding: const EdgeInsets.all(12),
//       itemCount: 5,
//       itemBuilder: (_, __) => Shimmer.fromColors(
//         baseColor: base.withOpacity(0.6),
//         highlightColor: highlight,
//         child: Container(
//           margin: const EdgeInsets.symmetric(vertical: 6),
//           height: 70,
//           decoration: BoxDecoration(
//             color: base,
//             borderRadius: BorderRadius.circular(16),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Future<void> _addNewGroup() async {
//     final nameController = TextEditingController();
//
//     final result = await showDialog<bool>(
//       context: context,
//       builder: (ctx) {
//         final theme = Theme.of(ctx);
//         return AlertDialog(
//           backgroundColor: theme.cardColor,
//           title: Text('Add New Group', style: theme.textTheme.titleMedium),
//           content: TextField(
//             controller: nameController,
//             style: theme.textTheme.bodyMedium,
//             decoration: InputDecoration(
//               labelText: 'Group Name',
//               labelStyle: theme.textTheme.bodySmall,
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(ctx).pop(false),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => Navigator.of(ctx).pop(true),
//               style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
//               child: Text('Add', style: TextStyle(color: theme.colorScheme.onSecondary)),
//             ),
//           ],
//         );
//       },
//     );
//
//     if (result == true && nameController.text.trim().isNotEmpty) {
//       await _firestore.collection('groups').add({
//         'name': nameController.text.trim(),
//         'A': [],
//         'B': [],
//         'courseI': _currentUserCourseId,
//         'createdAt': FieldValue.serverTimestamp(),
//       });
//       _showSnackbar('Group "${nameController.text.trim()}" created!');
//     }
//   }
//
//   Future<void> _showGroupModal(QueryDocumentSnapshot group) async {
//     final user = _auth.currentUser;
//     if (user == null) return;
//
//     final userDoc = await _firestore.collection('users').doc(user.uid).get();
//     final userData = userDoc.data();
//     if (userData == null) return;
//
//     final userGroupId = userData['groupId'] as String?;
//     final userSubdivision = userData['subdivision'] as String?;
//     final userName = (userData['name'] as String?) ?? 'User';
//
//     final latestGroupSnap = await _firestore.collection('groups').doc(group.id).get();
//     final groupData = latestGroupSnap.data();
//     if (groupData == null) return;
//
//     final groupA = (groupData['A'] as List<dynamic>?)
//         ?.map((m) => m as Map<String, dynamic>)
//         .toList() ??
//         [];
//     final groupB = (groupData['B'] as List<dynamic>?)
//         ?.map((m) => m as Map<String, dynamic>)
//         .toList() ??
//         [];
//
//     final isMember = userGroupId == group.id;
//
//     await showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (ctx) {
//         final theme = Theme.of(ctx);
//         return SizedBox(
//           height: MediaQuery.of(ctx).size.height * 0.75,
//           child: Column(
//             children: [
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Text(
//                   groupData['name'] ?? 'Group',
//                   style: theme.textTheme.headlineSmall,
//                 ),
//               ),
//               const Divider(),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//                 child: Row(
//                   children: [
//                     const Text('Group A', style: TextStyle(fontWeight: FontWeight.bold)),
//                     const Spacer(),
//                     Text('${groupA.length}/5'),
//                   ],
//                 ),
//               ),
//               Expanded(
//                 child: ListView.builder(
//                   shrinkWrap: true,
//                   itemCount: groupA.length,
//                   itemBuilder: (_, index) {
//                     final member = groupA[index];
//                     return ListTile(
//                       leading: const Icon(Icons.person),
//                       title: Text(member['name'] ?? 'Unknown'),
//                     );
//                   },
//                 ),
//               ),
//               const Divider(),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//                 child: Row(
//                   children: [
//                     const Text('Group B', style: TextStyle(fontWeight: FontWeight.bold)),
//                     const Spacer(),
//                     Text('${groupB.length}/5'),
//                   ],
//                 ),
//               ),
//               Expanded(
//                 child: ListView.builder(
//                   shrinkWrap: true,
//                   itemCount: groupB.length,
//                   itemBuilder: (_, index) {
//                     final member = groupB[index];
//                     return ListTile(
//                       leading: const Icon(Icons.person),
//                       title: Text(member['name'] ?? 'Unknown'),
//                     );
//                   },
//                 ),
//               ),
//               const Divider(),
//               Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: isMember ? Colors.red[100] : Colors.green[100],
//                         ),
//                         onPressed: () async {
//                           if (isMember) {
//                             if (userSubdivision != null) {
//                               await _leaveSubdivision(group, user.uid, userSubdivision);
//                             }
//                           } else if (userGroupId == null) {
//                             final selected = await showDialog<String>(
//                               context: ctx,
//                               builder: (ctx2) {
//                                 return AlertDialog(
//                                   title: const Text('Select Subdivision'),
//                                   content: Column(
//                                     mainAxisSize: MainAxisSize.min,
//                                     children: [
//                                       ElevatedButton(
//                                         onPressed: groupA.length < 5 ? () => Navigator.of(ctx2).pop('A') : null,
//                                         style: ElevatedButton.styleFrom(
//                                           backgroundColor: groupA.length < 5 ? Colors.green[100] : Colors.grey[200],
//                                           foregroundColor: groupA.length < 5 ? Colors.green[800] : Colors.grey[500],
//                                         ),
//                                         child: Text('Join Group A (${groupA.length}/5)'),
//                                       ),
//                                       const SizedBox(height: 12),
//                                       ElevatedButton(
//                                         onPressed: groupB.length < 5 ? () => Navigator.of(ctx2).pop('B') : null,
//                                         style: ElevatedButton.styleFrom(
//                                           backgroundColor: groupB.length < 5 ? Colors.green[100] : Colors.grey[200],
//                                           foregroundColor: groupB.length < 5 ? Colors.green[800] : Colors.grey[500],
//                                         ),
//                                         child: Text('Join Group B (${groupB.length}/5)'),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                               },
//                             );
//
//                             if (selected != null) {
//                               await _joinSubdivision(group, user.uid, userName, selected);
//                             }
//                           }
//                           if (context.mounted) Navigator.of(ctx).pop();
//                         },
//                         child: Text(
//                           isMember ? 'Leave Group' : 'Join Group',
//                           style: TextStyle(color: isMember ? Colors.red : Colors.green),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     if (!isMember && userGroupId != null)
//                       Expanded(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
//                           onPressed: null,
//                           child: const Text('Already in another group', style: TextStyle(color: Colors.black)),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

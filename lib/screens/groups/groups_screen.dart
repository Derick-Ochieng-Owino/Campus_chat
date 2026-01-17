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
  String? _academicYear;
  List<Map<String, dynamic>> _currentCourses = [];

  @override
  void initState() {
    super.initState();
    debugPrint('[GroupsTab] initState called');
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    debugPrint('[GroupsTab] Loading current user...');
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[GroupsTab] No user logged in');
      return;
    }

    _currentUserId = user.uid;
    debugPrint('[GroupsTab] Current user ID: $_currentUserId');

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      debugPrint('[GroupsTab] User document exists: ${userDoc.exists}');

      if (!mounted) {
        debugPrint('[GroupsTab] Widget not mounted, skipping update');
        return;
      }

      if (userDoc.exists) {
        final data = userDoc.data()!;
        debugPrint('[GroupsTab] User data keys: ${data.keys.join(', ')}');
        debugPrint('[GroupsTab] User role: ${data['role']}');
        debugPrint('[GroupsTab] User year: ${data['year']}');
        debugPrint('[GroupsTab] User semester: ${data['semester']}');

        setState(() {
          _currentUserProfile = data;
          _academicYear = data['academicYear'] ?? "2025/2026";
        });

        _loadRegisteredUnits();
      } else {
        debugPrint('[GroupsTab] User document not found');
      }
    } catch (e) {
      debugPrint('[GroupsTab] Error loading current user: $e');
    }
  }

  void _loadRegisteredUnits() {
    debugPrint('[GroupsTab] Loading registered units...');

    if (_currentUserProfile == null) {
      debugPrint('[GroupsTab] No user profile available');
      return;
    }

    final units = _currentUserProfile!['registered_units'];
    debugPrint('[GroupsTab] Registered units type: ${units.runtimeType}');
    debugPrint('[GroupsTab] Registered units value: $units');

    if (units == null || units is! List) {
      debugPrint('[GroupsTab] No valid units list found');
      if (mounted) {
        setState(() => _currentCourses = []);
      }
      return;
    }

    try {
      final courses = units.map<Map<String, dynamic>>((unit) {
        debugPrint('[GroupsTab] Processing unit: $unit');
        return {
          'code': unit['code'] ?? 'Unknown',
          'title': unit['title'] ?? 'Unknown Title',
          'type': unit['type'] ?? 'CORE',
        };
      }).toList();

      debugPrint('[GroupsTab] Loaded ${courses.length} courses');

      if (mounted) {
        setState(() => _currentCourses = courses);
      }
    } catch (e) {
      debugPrint('[GroupsTab] Error parsing units: $e');
      if (mounted) {
        setState(() => _currentCourses = []);
      }
    }
  }

  bool _hasAdminPrivileges() {
    if (_currentUserProfile == null) {
      debugPrint('[GroupsTab] No user profile for admin check');
      return false;
    }
    final role = _currentUserProfile!['role']?.toString().toLowerCase();
    debugPrint('[GroupsTab] User role for admin check: $role');
    final isAdmin = role == 'admin' || role == 'class_rep' || role == 'assistant' || role == 'lecturer';
    debugPrint('[GroupsTab] Has admin privileges: $isAdmin');
    return isAdmin;
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
      debugPrint('[GroupsTab] Snackbar: $message');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    debugPrint('[GroupsTab] Building with ${_currentCourses.length} courses');

    return Scaffold(
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
      ),
      body: _currentUserProfile == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          debugPrint('[GroupsTab] Pull to refresh triggered');
          await _loadCurrentUser();
        },
        child: _buildMainContent(theme),
      ),
      floatingActionButton: _hasAdminPrivileges()
          ? FloatingActionButton(
        backgroundColor: colorScheme.secondary,
        onPressed: _showCourseSelectionDialog,
        child: Icon(Icons.add, color: colorScheme.onSecondary),
      )
          : null,
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    if (_currentCourses.isEmpty) {
      debugPrint('[GroupsTab] No courses to display');
      return _buildEmptyState(
        theme,
        icon: Icons.menu_book_outlined,
        message: 'No courses found for this semester',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _currentCourses.length,
      itemBuilder: (context, index) {
        final course = _currentCourses[index];
        debugPrint('[GroupsTab] Building course section: ${course['code']}');
        return _buildCourseGroupSection(course, theme);
      },
    );
  }

  Widget _buildCourseGroupSection(Map<String, dynamic> course, ThemeData theme) {
    debugPrint('[GroupsTab] Setting up stream for course: ${course['code']}');
    debugPrint('[GroupsTab] User year: ${_currentUserProfile!['year']}');
    debugPrint('[GroupsTab] User semester: ${_currentUserProfile!['semester']}');
    debugPrint('[GroupsTab] User course: ${_currentUserProfile!['course']}');

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('groups')
          .where('course', isEqualTo: _currentUserProfile!['course'])
          .where('year', isEqualTo: _currentUserProfile!['year'])
          .where('semester', isEqualTo: _currentUserProfile!['semester'])
          .where('courseCode', isEqualTo: course['code'])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        debugPrint('[GroupsTab] Stream state: ${snapshot.connectionState}');
        debugPrint('[GroupsTab] Stream has data: ${snapshot.hasData}');
        debugPrint('[GroupsTab] Stream error: ${snapshot.error}');

        if (snapshot.hasError) {
          debugPrint('[GroupsTab] Stream error: ${snapshot.error}');
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Error loading groups: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 12),
                  Text('Loading groups for ${course['code']}...'),
                ],
              ),
            ),
          );
        }

        final groups = snapshot.data?.docs ?? [];
        debugPrint('[GroupsTab] Found ${groups.length} groups for ${course['code']}');

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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                  _buildEmptyCourseState(course, theme)
                else
                  ...groups.map((group) =>
                      _buildGroupWidget(group, groups.indexOf(group), theme)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyCourseState(Map<String, dynamic> course, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(
            Icons.group_add_outlined,
            size: 48,
            color: theme.disabledColor,
          ),
          const SizedBox(height: 8),
          Text(
            'No study groups for ${course['code']}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (_hasAdminPrivileges())
            ElevatedButton(
              onPressed: () => _showCreateGroupDialog(course),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
              ),
              child: const Text('Create Study Group'),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupWidget(
      QueryDocumentSnapshot group,
      int index,
      ThemeData theme,
      ) {
    final groupData = group.data() as Map<String, dynamic>;
    final colorScheme = theme.colorScheme;

    debugPrint('[GroupsTab] Building group widget: ${groupData['name']}');
    debugPrint('[GroupsTab] Group data keys: ${groupData.keys.join(', ')}');

    final groupName = groupData['name'] ?? 'Group';
    final maxMembers = groupData['maxMembers'] ?? 10;
    final members = (groupData['members'] as List<dynamic>? ?? []);
    final subdivisions = groupData['subdivisions'] as Map<String, dynamic>? ?? {};
    final totalMembers = members.length;
    final isFull = totalMembers >= maxMembers;

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
        onTap: () => _showGroupModal(group),
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
                    Icons.group,
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
                        if (groupData['description'] != null)
                          Text(
                            groupData['description'],
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isFull ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isFull ? Colors.red : Colors.green,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '$totalMembers/$maxMembers',
                      style: TextStyle(
                        color: isFull ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Show subdivisions if they exist
              if (subdivisions.isNotEmpty) ...[
                const Divider(height: 16),
                Text(
                  'Subdivisions:',
                  style: theme.textTheme.bodySmall!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: subdivisions.entries.map((entry) {
                    final subName = entry.key;
                    final subMembers = (entry.value as List<dynamic>? ?? []).length;
                    return Chip(
                      label: Text('$subName: $subMembers'),
                      backgroundColor: _getSubdivisionColor(subName),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getSubdivisionColor(String subName) {
    final colors = {
      'A': Colors.blue.withOpacity(0.1),
      'B': Colors.green.withOpacity(0.1),
      'C': Colors.orange.withOpacity(0.1),
      'D': Colors.purple.withOpacity(0.1),
      'E': Colors.red.withOpacity(0.1),
    };
    return colors[subName] ?? Colors.grey.withOpacity(0.1);
  }

  Widget _buildShimmerLoading(ThemeData theme) {
    final base = theme.cardColor;
    final highlight = theme.dividerColor.withOpacity(0.15);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      itemBuilder: (_, _) => Shimmer.fromColors(
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

  Future<void> _showCourseSelectionDialog() async {
    debugPrint('[GroupsTab] Showing course selection dialog');

    if (_currentCourses.isEmpty) {
      _showSnackbar('No courses found for this semester', isError: true);
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
              itemCount: _currentCourses.length,
              itemBuilder: (context, index) {
                final course = _currentCourses[index];
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
      debugPrint('[GroupsTab] Selected course: ${selectedCourse['code']}');
      await _showCreateGroupDialog(selectedCourse);
    }
  }

  Future<void> _showCreateGroupDialog(Map<String, dynamic> course) async {
    debugPrint('[GroupsTab] Showing create group dialog for ${course['code']}');

    final nameController = TextEditingController(
      text: '${course['code']} Study Group',
    );
    final descController = TextEditingController();
    final maxMembersController = TextEditingController(text: '10');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (context, setState) {
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: maxMembersController,
                      decoration: const InputDecoration(
                        labelText: 'Maximum Members',
                        hintText: 'Enter maximum number of members',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Subdivisions can be created later from group management',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
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
                    final maxMembers = int.tryParse(maxMembersController.text);
                    if (maxMembers == null || maxMembers < 1 || maxMembers > 50) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid number between 1 and 50')),
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
      },
    );

    if (result == true) {
      debugPrint('[GroupsTab] Creating group for ${course['code']}');
      await _createGroup(
        name: nameController.text.trim(),
        description: descController.text.trim(),
        maxMembers: int.parse(maxMembersController.text),
        courseCode: course['code'],
        courseTitle: course['title'],
        courseType: course['type'],
      );
    }
  }

  Future<void> _createGroup({
    required String name,
    required String description,
    required int maxMembers,
    required String courseCode,
    required String courseTitle,
    required String courseType,
  }) async {
    debugPrint('[GroupsTab] Creating group: $name');
    debugPrint('[GroupsTab] Course: $courseCode, Type: $courseType');
    debugPrint('[GroupsTab] Current user profile: $_currentUserProfile');

    if (_currentUserProfile == null) {
      _showSnackbar('User profile not loaded', isError: true);
      return;
    }

    try {
      final groupData = {
        'name': name,
        'description': description,
        'maxMembers': maxMembers,
        'university': _currentUserProfile!['university'] ?? 'JKUAT',
        'campus': _currentUserProfile!['campus'] ?? 'Main',
        'college': _currentUserProfile!['college'] ?? 'COPAS',
        'school': _currentUserProfile!['school'] ?? 'SCIT',
        'department': _currentUserProfile!['department'] ?? 'IT',
        'course': _currentUserProfile!['course'] ?? 'BIT',
        'year': _currentUserProfile!['year'] ?? '2',
        'semester': _currentUserProfile!['semester'] ?? '1',
        'courseCode': courseCode,
        'courseTitle': courseTitle,
        'courseType': courseType,
        'academicYear': _academicYear ?? "2025/2026",
        'members': [], // List of member objects
        'subdivisions': {}, // Map of subdivisions (optional)
        'type': 'course',

        // Admin info
        'createdBy': _currentUserId,
        'createdByName': _currentUserProfile!['name'] ?? _currentUserProfile!['full_name'] ?? 'Unknown',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      };

      debugPrint('[GroupsTab] Group data to save: $groupData');

      await _firestore.collection('groups').add(groupData);

      _showSnackbar('Study group for $courseCode created successfully');
      debugPrint('[GroupsTab] Group created successfully');
    } catch (e) {
      debugPrint('[GroupsTab] Failed to create group: $e');
      _showSnackbar('Failed to create group: ${e.toString()}', isError: true);
    }
  }

  Future<void> _showGroupModal(QueryDocumentSnapshot group) async {
    debugPrint('[GroupsTab] Showing group modal for ${group.id}');

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[GroupsTab] No user logged in');
      return;
    }

    final groupId = group.id;
    final groupData = group.data() as Map<String, dynamic>;

    debugPrint('[GroupsTab] Group data: ${groupData.keys.join(', ')}');

    // Check if user is already in a group for this course
    final userGroupsQuery = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('course_groups')
        .where('courseCode', isEqualTo: groupData['courseCode'])
        .get();

    debugPrint('[GroupsTab] User groups for this course: ${userGroupsQuery.docs.length}');

    final isAlreadyInCourseGroup = userGroupsQuery.docs.isNotEmpty;
    final isGroupAdmin = _hasAdminPrivileges();

    final members = (groupData['members'] as List<dynamic>? ?? []);
    final isMember = members.any((member) => member['uid'] == user.uid);
    final currentMemberCount = members.length;
    final maxMembers = groupData['maxMembers'] ?? 10;
    final isFull = currentMemberCount >= maxMembers;

    debugPrint('[GroupsTab] User is member: $isMember');
    debugPrint('[GroupsTab] Group is full: $isFull');
    debugPrint('[GroupsTab] User is admin: $isGroupAdmin');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.group, color: theme.primaryColor, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        groupData['name'] ?? 'Group',
                        style: theme.textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Course info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupData['courseCode'] ?? 'Course',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (groupData['description'] != null)
                      Text(
                        groupData['description'],
                        style: theme.textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$currentMemberCount/$maxMembers members',
                          style: theme.textTheme.bodySmall,
                        ),
                        const Spacer(),
                        if (isGroupAdmin)
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showManageGroupDialog(group),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Subdivisions section
              if (groupData['subdivisions'] != null &&
                  (groupData['subdivisions'] as Map).isNotEmpty) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subdivisions',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...(groupData['subdivisions'] as Map<String, dynamic>)
                          .entries
                          .map((entry) {
                        final subName = entry.key;
                        final subMembers = (entry.value as List<dynamic>? ?? []);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getSubdivisionColor(subName),
                            child: Text(subName),
                          ),
                          title: Text('Group $subName'),
                          subtitle: Text('${subMembers.length} members'),
                          trailing: isGroupAdmin
                              ? IconButton(
                            icon: const Icon(Icons.manage_accounts),
                            onPressed: () =>
                                _showManageSubdivisionDialog(group, subName),
                          )
                              : null,
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],

              // Members section
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: const [
                          Tab(text: 'Members'),
                          Tab(text: 'Requests'),
                        ],
                        labelColor: theme.primaryColor,
                        indicatorColor: theme.primaryColor,
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Members tab
                            ListView.builder(
                              itemCount: members.length,
                              itemBuilder: (context, index) {
                                final member = members[index];
                                return ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text(member['name'] ?? 'Unknown'),
                                  subtitle: Text(member['subdivision'] ?? 'No subdivision'),
                                  trailing: isGroupAdmin
                                      ? IconButton(
                                    icon: const Icon(Icons.remove_circle),
                                    color: Colors.red,
                                    onPressed: () => _removeMember(group, member['uid']),
                                  )
                                      : null,
                                );
                              },
                            ),

                            // Requests tab (only for admins)
                            isGroupAdmin
                                ? _buildRequestsTab(group, theme)
                                : const Center(
                                child: Text('Only group admins can view requests')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (isGroupAdmin) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showCreateSubdivisionDialog(group),
                          child: const Text('Add Subdivision'),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMember
                              ? Colors.red
                              : isAlreadyInCourseGroup
                              ? Colors.grey
                              : isFull
                              ? Colors.grey
                              : Colors.green,
                        ),
                        onPressed: () async {
                          if (isMember) {
                            await _leaveGroup(group);
                          } else if (!isAlreadyInCourseGroup && !isFull) {
                            await _joinGroup(group);
                          }
                          if (context.mounted) Navigator.of(ctx).pop();
                        },
                        child: Text(
                          isMember
                              ? 'Leave Group'
                              : isAlreadyInCourseGroup
                              ? 'Already in course group'
                              : isFull
                              ? 'Group Full'
                              : 'Join Group',
                          style: const TextStyle(color: Colors.white),
                        ),
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

  Widget _buildRequestsTab(QueryDocumentSnapshot group, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('group_requests')
          .where('groupId', isEqualTo: group.id)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        debugPrint('[GroupsTab] Requests stream state: ${snapshot.connectionState}');

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;
        debugPrint('[GroupsTab] Found ${requests.length} pending requests');

        if (requests.isEmpty) {
          return const Center(child: Text('No pending requests'));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final requestData = request.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_add)),
                title: Text(requestData['userName'] ?? 'Unknown'),
                subtitle: Text(requestData['userEmail'] ?? 'No email'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _handleJoinRequest(group, request, true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _handleJoinRequest(group, request, false),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _joinGroup(QueryDocumentSnapshot group) async {
    debugPrint('[GroupsTab] Joining group: ${group.id}');

    final user = _auth.currentUser;
    if (user == null) {
      _showSnackbar('You must be logged in', isError: true);
      return;
    }

    final groupData = group.data() as Map<String, dynamic>;
    final groupId = group.id;

    // Check if user is already in this group
    final members = (groupData['members'] as List<dynamic>? ?? []);
    if (members.any((member) => member['uid'] == user.uid)) {
      _showSnackbar('You are already in this group', isError: true);
      return;
    }

    // Check if group is full
    final maxMembers = groupData['maxMembers'] ?? 10;
    if (members.length >= maxMembers) {
      _showSnackbar('Group is full', isError: true);
      return;
    }

    try {
      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null) {
        _showSnackbar('User data not found', isError: true);
        return;
      }

      final userName = userData['name'] ?? userData['full_name'] ?? 'Unknown';
      debugPrint('[GroupsTab] Adding user $userName to group');

      // Add to group members
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([
          {
            'uid': user.uid,
            'name': userName,
            'email': userData['email'],
            'joinedAt': FieldValue.serverTimestamp(),
            'subdivision': null, // No subdivision by default
          }
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add to user's course groups
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('course_groups')
          .doc(groupId)
          .set({
        'groupId': groupId,
        'groupName': groupData['name'],
        'courseCode': groupData['courseCode'],
        'courseTitle': groupData['courseTitle'],
        'joinedAt': FieldValue.serverTimestamp(),
      });

      _showSnackbar('Successfully joined group');
      debugPrint('[GroupsTab] Successfully joined group');
    } catch (e) {
      debugPrint('[GroupsTab] Failed to join group: $e');
      _showSnackbar('Failed to join group: ${e.toString()}', isError: true);
    }
  }

  Future<void> _leaveGroup(QueryDocumentSnapshot group) async {
    debugPrint('[GroupsTab] Leaving group: ${group.id}');

    final user = _auth.currentUser;
    if (user == null) {
      _showSnackbar('You must be logged in', isError: true);
      return;
    }

    final groupId = group.id;

    try {
      // First, find the member to remove
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final groupData = groupDoc.data() as Map<String, dynamic>;
      final members = (groupData['members'] as List<dynamic>? ?? []);

      final memberToRemove = members.firstWhere(
            (member) => member['uid'] == user.uid,
        orElse: () => null,
      );

      if (memberToRemove == null) {
        _showSnackbar('You are not in this group', isError: true);
        return;
      }

      // Remove from group members
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove([memberToRemove]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Remove from user's course groups
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('course_groups')
          .doc(groupId)
          .delete();

      _showSnackbar('Successfully left group');
      debugPrint('[GroupsTab] Successfully left group');
    } catch (e) {
      debugPrint('[GroupsTab] Failed to leave group: $e');
      _showSnackbar('Failed to leave group: ${e.toString()}', isError: true);
    }
  }

  Future<void> _removeMember(QueryDocumentSnapshot group, String memberUid) async {
    debugPrint('[GroupsTab] Removing member: $memberUid from group: ${group.id}');

    if (!_hasAdminPrivileges()) {
      _showSnackbar('You do not have permission', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final groupId = group.id;

      // First, find the member to remove
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final groupData = groupDoc.data() as Map<String, dynamic>;
      final members = (groupData['members'] as List<dynamic>? ?? []);

      final memberToRemove = members.firstWhere(
            (member) => member['uid'] == memberUid,
        orElse: () => null,
      );

      if (memberToRemove == null) {
        _showSnackbar('Member not found', isError: true);
        return;
      }

      debugPrint('[GroupsTab] Removing member: ${memberToRemove['name']}');

      // Remove from group members
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove([memberToRemove]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Remove from user's course groups
      await _firestore
          .collection('users')
          .doc(memberUid)
          .collection('course_groups')
          .doc(groupId)
          .delete();

      _showSnackbar('Member removed successfully');
      debugPrint('[GroupsTab] Member removed successfully');
    } catch (e) {
      debugPrint('[GroupsTab] Failed to remove member: $e');
      _showSnackbar('Failed to remove member: ${e.toString()}', isError: true);
    }
  }

  Future<void> _showManageGroupDialog(QueryDocumentSnapshot group) async {
    debugPrint('[GroupsTab] Showing manage group dialog');

    final groupData = group.data() as Map<String, dynamic>;
    final nameController = TextEditingController(text: groupData['name']);
    final descController = TextEditingController(text: groupData['description']);
    final maxMembersController = TextEditingController(
        text: groupData['maxMembers']?.toString() ?? '10');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Manage Group'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Group Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: maxMembersController,
                  decoration: const InputDecoration(labelText: 'Maximum Members'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                final maxMembers = int.tryParse(maxMembersController.text);
                if (maxMembers == null || maxMembers < 1 || maxMembers > 50) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid number between 1 and 50')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _updateGroup(
        group.id,
        name: nameController.text.trim(),
        description: descController.text.trim(),
        maxMembers: int.parse(maxMembersController.text),
      );
    }
  }

  Future<void> _updateGroup(
      String groupId, {
        required String name,
        required String description,
        required int maxMembers,
      }) async {
    debugPrint('[GroupsTab] Updating group: $groupId');

    try {
      await _firestore.collection('groups').doc(groupId).update({
        'name': name,
        'description': description,
        'maxMembers': maxMembers,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackbar('Group updated successfully');
      debugPrint('[GroupsTab] Group updated successfully');
    } catch (e) {
      debugPrint('[GroupsTab] Failed to update group: $e');
      _showSnackbar('Failed to update group: ${e.toString()}', isError: true);
    }
  }

  Future<void> _showCreateSubdivisionDialog(QueryDocumentSnapshot group) async {
    debugPrint('[GroupsTab] Showing create subdivision dialog');

    final nameController = TextEditingController(text: 'A');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Create Subdivision'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Subdivision Name',
                  hintText: 'e.g., A, B, Team 1',
                ),
                maxLength: 20,
              ),
            ],
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
                    const SnackBar(content: Text('Subdivision name is required')),
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
      await _createSubdivision(group.id, nameController.text.trim());
    }
  }

  Future<void> _createSubdivision(String groupId, String subName) async {
    debugPrint('[GroupsTab] Creating subdivision: $subName for group: $groupId');

    try {
      await _firestore.collection('groups').doc(groupId).update({
        'subdivisions.$subName': [],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackbar('Subdivision $subName created');
      debugPrint('[GroupsTab] Subdivision created successfully');
    } catch (e) {
      debugPrint('[GroupsTab] Failed to create subdivision: $e');
      _showSnackbar('Failed to create subdivision: ${e.toString()}', isError: true);
    }
  }

  Future<void> _showManageSubdivisionDialog(
      QueryDocumentSnapshot group, String subName) async {
    debugPrint('[GroupsTab] Showing manage subdivision dialog for: $subName');

    final groupData = group.data() as Map<String, dynamic>;
    final subdivisions = groupData['subdivisions'] as Map<String, dynamic>? ?? {};
    final subMembers = (subdivisions[subName] as List<dynamic>? ?? []);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Manage Subdivision $subName'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Members: ${subMembers.length}'),
                const SizedBox(height: 16),
                ...subMembers.map((member) {
                  return ListTile(
                    title: Text(member['name'] ?? 'Unknown'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _removeFromSubdivision(
                          group, subName, member['uid']),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () => _deleteSubdivision(group, subName),
              child: const Text('Delete Subdivision', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeFromSubdivision(
      QueryDocumentSnapshot group, String subName, String memberUid) async {
    debugPrint('[GroupsTab] Removing member $memberUid from subdivision $subName');

    try {
      await _firestore.collection('groups').doc(group.id).update({
        'subdivisions.$subName': FieldValue.arrayRemove([
          {'uid': memberUid}
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackbar('Member removed from subdivision');
      debugPrint('[GroupsTab] Member removed from subdivision');
    } catch (e) {
      debugPrint('[GroupsTab] Failed to remove member: $e');
      _showSnackbar('Failed to remove member: ${e.toString()}', isError: true);
    }
  }

  Future<void> _deleteSubdivision(QueryDocumentSnapshot group, String subName) async {
    debugPrint('[GroupsTab] Deleting subdivision: $subName');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subdivision'),
        content: Text('Are you sure you want to delete subdivision $subName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('groups').doc(group.id).update({
        'subdivisions.$subName': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackbar('Subdivision deleted');
      debugPrint('[GroupsTab] Subdivision deleted successfully');
    } catch (e) {
      debugPrint('[GroupsTab] Failed to delete subdivision: $e');
      _showSnackbar('Failed to delete subdivision: ${e.toString()}', isError: true);
    }
  }

  Future<void> _handleJoinRequest(
      QueryDocumentSnapshot group, DocumentSnapshot request, bool approved) async {
    debugPrint('[GroupsTab] Handling join request: approved=$approved');

    final requestData = request.data() as Map<String, dynamic>;
    final userId = requestData['userId'];
    final userName = requestData['userName'];

    debugPrint('[GroupsTab] Request for user: $userName ($userId)');

    try {
      if (approved) {
        // Add to group members
        await _firestore.collection('groups').doc(group.id).update({
          'members': FieldValue.arrayUnion([
            {
              'uid': userId,
              'name': userName,
              'email': requestData['userEmail'],
              'joinedAt': FieldValue.serverTimestamp(),
            }
          ]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Add to user's course groups
        final groupData = group.data() as Map<String, dynamic>?;

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('course_groups')
            .doc(group.id)
            .set({
          'groupId': group.id,
          'groupName': groupData?['name'] ?? 'Unnamed Group',
          'courseCode': groupData?['courseCode'] ?? 'Unknown Code',
          'courseTitle': groupData?['courseTitle'] ?? 'Unknown Title',
          'joinedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update request status
      await _firestore.collection('group_requests').doc(request.id).update({
        'status': approved ? 'approved' : 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': _currentUserId,
      });

      _showSnackbar(approved ? 'Request approved' : 'Request rejected');
      debugPrint('[GroupsTab] Request processed successfully');
    } catch (e) {
      debugPrint('[GroupsTab] Failed to process request: $e');
      _showSnackbar('Failed to process request: ${e.toString()}', isError: true);
    }
  }
}
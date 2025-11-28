// lib/screens/groups/groups_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/theme_manager.dart';

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

  String? _currentUserRole;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = _auth.currentUser;
    if (!mounted || user == null) return;

    _currentUserId = user.uid;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      if (!mounted) return;
      if (data != null) {
        setState(() {
          // guard against unexpected types / capitalization
          final role = data['role'];
          _currentUserRole = role is String ? role.toLowerCase() : null;
        });
      }
    } catch (e) {
      debugPrint('Error loading current user role: $e');
    }
  }

  bool _hasAdminPrivileges() {
    final role = _currentUserRole?.toLowerCase();
    return role == 'admin' || role == 'class_rep' || role == 'assistant';
  }

  // Keep the original red/yellow/green badge logic
  Color _getBadgeColor(int members) {
    if (members <= 4) return Colors.redAccent;
    if (members <= 7) return Colors.amberAccent;
    return Colors.greenAccent;
  }

  Color _getBadgeBgColor(int members) => _getBadgeColor(members).withOpacity(0.18);

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

  @override
  Widget build(BuildContext context) {
    super.build(context); // important for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Class Groups', style: theme.textTheme.titleLarge),
        backgroundColor: colorScheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: theme.appBarTheme.elevation,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('groups').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _buildShimmerLoading(theme);
          }

          final groups = snapshot.data!.docs;
          if (groups.isEmpty) {
            return Center(
              child: Text('No groups yet', style: theme.textTheme.bodyMedium),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: groups.length,
            itemBuilder: (context, index) => _buildGroupWidget(groups[index], index, theme),
          );
        },
      ),
      floatingActionButton: _hasAdminPrivileges()
          ? FloatingActionButton(
        backgroundColor: colorScheme.secondary,
        onPressed: _addNewGroup,
        child: Icon(Icons.add, color: colorScheme.onSecondary),
      )
          : null,
    );
  }

  // Build each group card — now theme-consistent, keeps the original badge colours
  Widget _buildGroupWidget(QueryDocumentSnapshot group, int index, ThemeData theme) {
    final colorScheme = theme.colorScheme;

    final groupName = (group.data() as Map<String, dynamic>?)?['name'] as String? ?? 'Group';
    final groupA = (group.data() as Map<String, dynamic>?)?['A'] as List<dynamic>? ?? [];
    final groupB = (group.data() as Map<String, dynamic>?)?['B'] as List<dynamic>? ?? [];
    final totalMembers = groupA.length + groupB.length;

    // Accent choice rotates through a small set that plays nicely with the app theme
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
                color: Colors.black26,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.group, size: 32, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  groupName,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
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
                  ),
                ),
              ),
            ],
          ),
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
          height: 70,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _addNewGroup() async {
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text('Add New Group', style: theme.textTheme.titleMedium),
          content: TextField(
            controller: nameController,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              labelText: 'Group Name',
              labelStyle: theme.textTheme.bodySmall,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
              child: Text('Add', style: TextStyle(color: theme.colorScheme.onSecondary)),
            ),
          ],
        );
      },
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await _firestore.collection('groups').add({
        'name': nameController.text.trim(),
        'A': [],
        'B': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      _showSnackbar('Group "${nameController.text.trim()}" created!');
    }
  }

  Future<void> _showGroupModal(QueryDocumentSnapshot group) async {
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
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';

// Assuming Colors.dart is available, but using standard Flutter colors here
// import '../../core/constants/colors.dart';

class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserRole;
  String? _currentUserId;

  final List<List<Color>> _colorSchemes = const [
    [Color(0xFFE0F7FA), Colors.cyan], // Light Cyan, Cyan
    // [Color(0xFFF3E5F5), Colors.purple], // Light Purple, Purple
    // [Color(0xFFFFECB3), Colors.orange], // Light Yellow, Orange
    // [Color(0xFFE8F5E9), Colors.teal], // Light Green, Teal
    // [Color(0xFFFCE4EC), Colors.pink], // Light Pink, Pink
  ];

  // Utility function to get a color scheme based on the index
  List<Color> _getColorScheme(int index) {
    return _colorSchemes[index % _colorSchemes.length];
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  // Loads current user ID and Role
  Future<void> _loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _currentUserId = user.uid;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    if (data != null) {
      setState(() {
        _currentUserRole = data['role'] as String?;
      });
    }
  }

  // --- Utility Functions ---

  Color _getBadgeColor(int members) {
    if (members <= 4) return Colors.red;
    if (members <= 7) return Colors.amber;
    return Colors.green;
  }

  Color _getBadgeBgColor(int members) =>
      _getBadgeColor(members).withOpacity(0.2);

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

  // --- Database Operations ---

  Future<void> _joinSubdivision(QueryDocumentSnapshot group, String uid,
      String name, String sub) async {
    final userRef = _firestore.collection('users').doc(uid);
    final groupRef = _firestore.collection('groups').doc(group.id);

    try {
      await _firestore.runTransaction((tx) async {
        final userSnap = await tx.get(userRef);
        final groupSnap = await tx.get(groupRef);

        // Check 1: User is not already in a group
        if (userSnap.exists && userSnap.data()?['groupId'] != null) {
          throw Exception("You are already a member of a group.");
        }

        // Read the current members list for the selected subdivision ('A' or 'B')
        final members = (groupSnap.data()?[sub] as List<dynamic>?) ?? [];

        // Check 2: Subdivision limit (assuming a max of 5)
        if (members.length >= 5) {
          throw Exception("The selected subdivision is full (Max 5).");
        }

        // Add user details (UID and Name) to the subdivision list
        members.add({'uid': uid, 'name': name});

        // 1. Update Group Document (Add member to A or B array)
        tx.update(groupRef, {sub: members});

        // 2. Update User Document (Set group details)
        tx.update(userRef, {'groupId': group.id, 'subdivision': sub});
      });
      _showSnackbar('Successfully joined ${group['name']} ($sub)!');
    } catch (e) {
      String errorMessage = e.toString().split(':').last.trim();
      _showSnackbar(errorMessage, isError: true);
    }
  }

  Future<void> _leaveSubdivision(QueryDocumentSnapshot group, String uid,
      String sub) async {
    final userRef = _firestore.collection('users').doc(uid);
    final groupRef = _firestore.collection('groups').doc(group.id);

    try {
      await _firestore.runTransaction((tx) async {
        final groupSnap = await tx.get(groupRef);

        // Read the current members list for the subdivision the user is leaving
        final members = (groupSnap.data()?[sub] as List<dynamic>?) ?? [];

        // Remove user from the subdivision list by UID
        members.removeWhere((m) => m['uid'] == uid);

        // 1. Update Group Document (Remove member from A or B array)
        tx.update(groupRef, {sub: members});

        // 2. Update User Document (Remove group details)
        tx.update(userRef, {
          'groupId': FieldValue.delete(),
          'subdivision': FieldValue.delete()
        });
      });
      _showSnackbar('Successfully left ${group['name']}!');
    } catch (e) {
      _showSnackbar('Failed to leave group: ${e.toString().split(':').last.trim()}', isError: true);
    }
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Class Groups", style:const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('groups').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final groups = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              // Pass the index along with the group document
              return _buildGroupWidget(groups[index], index);
            },
          );
        },
      ),

      floatingActionButton: (_currentUserRole == 'admin' ||
          _currentUserRole == 'class_rep' ||
          _currentUserRole == 'assistant')
          ? FloatingActionButton(
        backgroundColor: Colors.green[600],
        onPressed: () async {
          final nameController = TextEditingController();

          final result = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Add New Group'),
              content: TextField(
                controller: nameController,
                decoration:
                const InputDecoration(labelText: 'Group Name'),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[100],
                    foregroundColor: Colors.red[800],
                  ),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[100],
                    foregroundColor: Colors.green[800],
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Add'),
                ),
              ],
            ),
          );

          if (result == true && nameController.text.trim().isNotEmpty) {
            // Initializing with empty A and B arrays as required
            await _firestore.collection('groups').add({
              'name': nameController.text.trim(),
              'A': [],
              'B': [],
              'createdAt': FieldValue.serverTimestamp(),
            });
            _showSnackbar('Group "${nameController.text.trim()}" created!');
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
    );
  }

  Widget _buildGroupWidget(QueryDocumentSnapshot group, int index) {
    final groupName = group['name'] as String? ?? 'Group';

    final colorScheme = _getColorScheme(index);
    final backgroundColor = colorScheme[0];
    final iconTextColor = colorScheme[1];

    final groupA = (group['A'] as List<dynamic>?)?.length ?? 0;
    final groupB = (group['B'] as List<dynamic>?)?.length ?? 0;
    final totalMembers = groupA + groupB;

    // Define a constant for the widget's vertical padding for consistent sizing
    const double verticalPadding = 10.0;
    // Define a constant for the desired square badge size (e.g., total height)
    // This value is approximate since text sizing is dynamic, but we'll aim for a typical row height.
    const double badgeSize = 60.0;
    const double borderRadius = 16.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () => _showGroupModal(group),
        child: Container(
          // Use the defined vertical padding
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: backgroundColor, // Set the dynamic background color
            borderRadius: BorderRadius.circular(borderRadius), // Apply rounded corners
            border: Border.all(color: iconTextColor, width: 1), // Optional: border color matches icon/text
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.group, size: 32, color: iconTextColor),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                    groupName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: iconTextColor, // Set dynamic text color
                    ),
                  )),

              // 1. ADMIN DELETE BUTTON (TRASH BIN) - Now before the member count
              if (_currentUserRole == 'admin')
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) =>
                          AlertDialog(
                            title: const Text('Delete Group'),
                            content: Text(
                                'Are you sure you want to delete "$groupName"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[100],
                                  foregroundColor: Colors.red[800],
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                    );
                    if (confirm == true) {
                      await _firestore
                          .collection('groups')
                          .doc(group.id)
                          .delete();
                      // Assuming _showSnackbar is defined in _GroupsTabState
                      _showSnackbar('Group "$groupName" deleted.');
                    }
                  },
                ),

              // 2. MEMBER COUNT BADGE - Styled as a rounded square
              Container(
                width: badgeSize,
                height: badgeSize,
                alignment: Alignment.center,
                padding: EdgeInsets.zero,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: _getBadgeBgColor(totalMembers),
                  borderRadius: BorderRadius.circular(badgeSize / 2),
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
        ),
      ),
    );
  }

  Future<void> _showGroupModal(QueryDocumentSnapshot group) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // --- IMPORTANT: Fetch User details and latest Group details for Modal ---
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData == null) return;

    final userGroupId = userData['groupId'] as String?;
    final userSubdivision = userData['subdivision'] as String?;
    final userName = userData['name'] as String? ?? 'User'; // Ensure 'name' field exists on your user document!

    // Fetch the latest group snapshot inside the modal function to get real-time member lists
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
      builder: (ctx) =>
          SizedBox(
            height: MediaQuery
                .of(ctx)
                .size
                .height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    groupData['name'] ?? 'Group',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),

                // Group A members
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text('Group A',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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

                // Group B members
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text('Group B',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
                      // Join / Leave buttons
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMember ? Colors.red[100] : Colors.green[100],
                          ),
                          onPressed: () async {
                            if (isMember) {
                              // Leave the group (requires subdivision)
                              if(userSubdivision != null) {
                                await _leaveSubdivision(group, user.uid, userSubdivision);
                              }
                            } else if (userGroupId == null) {
                              // Join: prompt for A or B
                              String? selected = await showDialog<String>(
                                context: ctx,
                                builder: (ctx2) => AlertDialog(
                                  title: const Text('Select Subdivision'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton(
                                        onPressed: groupA.length < 5
                                            ? () => Navigator.of(ctx2).pop('A')
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: groupA.length < 5 ? Colors.green[100] : Colors.grey[200],
                                          foregroundColor: groupA.length < 5 ? Colors.green[800] : Colors.grey[500],
                                        ),
                                        child: Text('Join Group A (${groupA.length}/5)'),
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton(
                                        onPressed: groupB.length < 5
                                            ? () => Navigator.of(ctx2).pop('B')
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: groupB.length < 5 ? Colors.green[100] : Colors.grey[200],
                                          foregroundColor: groupB.length < 5 ? Colors.green[800] : Colors.grey[500],
                                        ),
                                        child: Text('Join Group B (${groupB.length}/5)'),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              if (selected != null) {
                                // Join the group using the retrieved name
                                await _joinSubdivision(group, user.uid, userName, selected);
                              }
                            }
                            // Close the modal to refresh the list state
                            if(context.mounted) Navigator.of(ctx).pop();
                          },
                          child: Text(
                            isMember ? 'Leave Group' : 'Join Group',
                            style: TextStyle(color: isMember
                                ? Colors.red
                                : Colors.green),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (!isMember && userGroupId != null)
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300]),
                            onPressed: null,
                            child: const Text(
                                'Already in another group', style: TextStyle(
                                color: Colors.black)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
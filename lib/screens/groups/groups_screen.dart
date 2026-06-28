// // ignore_for_file: deprecated_member_use
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:shimmer/shimmer.dart';
// import '../../models/unit_model.dart'; // Reuses your unified Unit model structure
// import '../../widgets/theme_manager.dart'; // Imports kSunsetOrange, kAmberGold, kRoyalPurple
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
//   late Future<List<Unit>> _futureUnits;
//   Map<String, dynamic>? _currentUserProfile;
//   String? _currentUserId;
//   bool _isProfileLoading = true;
//
//   static const String _cacheKey = 'cachedGroupUnits_v2';
//   static const Duration _cacheMaxAge = Duration(hours: 24);
//
//   @override
//   void initState() {
//     super.initState();
//     _futureUnits = _loadUnitsOnce();
//     _loadUserProfileContext();
//   }
//
//   Future<void> _loadUserProfileContext() async {
//     final user = _auth.currentUser;
//     if (user == null) return;
//     _currentUserId = user.uid;
//
//     try {
//       final doc = await _firestore.collection('users').doc(user.uid).get();
//       if (doc.exists && mounted) {
//         setState(() {
//           _currentUserProfile = doc.data();
//           _isProfileLoading = false;
//         });
//       }
//     } catch (e) {
//       debugPrint('Error loading user metadata context: $e');
//       if (mounted) setState(() => _isProfileLoading = false);
//     }
//   }
//
//   /// Reuses your high-performance SharedPreferences local caching manager
//   Future<List<Unit>> _loadUnitsOnce({bool forceRefresh = false}) async {
//     final prefs = await SharedPreferences.getInstance();
//
//     if (!forceRefresh) {
//       final tsStr = prefs.getString('${_cacheKey}_ts');
//       final cachedData = prefs.getString(_cacheKey);
//       if (cachedData != null && tsStr != null) {
//         final ts = DateTime.tryParse(tsStr);
//         if (ts != null && DateTime.now().difference(ts) < _cacheMaxAge) {
//           try {
//             return Unit.decodeList(cachedData);
//           } catch (_) {}
//         }
//       }
//     }
//
//     final user = _auth.currentUser;
//     if (user == null) return [];
//
//     final doc = await _firestore.collection('users').doc(user.uid).get();
//     if (!doc.exists) return [];
//
//     final data = doc.data()!;
//     final List<dynamic> registeredUnits = data['registered_units'] ?? [];
//     final year = data['year'] ?? "1";
//     final semester = data['semester'] ?? "1";
//     final currentYear = int.tryParse(year.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
//     final currentSemester = int.tryParse(semester.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
//
//     final units = registeredUnits
//         .map((u) => Unit(
//       id: u['code'],
//       name: u['title'],
//       year: currentYear,
//       semester: currentSemester,
//     ))
//         .toList();
//
//     await prefs.setString(_cacheKey, Unit.encodeList(units));
//     await prefs.setString('${_cacheKey}_ts', DateTime.now().toIso8601String());
//
//     return units;
//   }
//
//   bool _hasAdminPrivileges() {
//     final r = _currentUserProfile?['role'] ?? '';
//     return r == 'admin' || r == 'class_rep' || r == 'assistant';
//   }
//
//   String _sanitizePathSegment(String input) {
//     if (input.trim().isEmpty) return 'UNKNOWN';
//     return input.replaceAll(RegExp(r'[^\w\s\-]'), '').trim().replaceAll(RegExp(r'[\s\-]+'), '_').toUpperCase();
//   }
//
//   void _showNotification(String message, {bool isError = false}) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
//         backgroundColor: isError ? Colors.red : kSunsetOrange,
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     super.build(context);
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//
//     if (_isProfileLoading) {
//       return Scaffold(backgroundColor: theme.scaffoldBackgroundColor, body: _buildShimmerGrid(theme));
//     }
//
//     return Scaffold(
//       backgroundColor: theme.scaffoldBackgroundColor,
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         title: Text('Study Groups Dropdown', style: theme.appBarTheme.titleTextStyle),
//         backgroundColor: colorScheme.surface,
//         foregroundColor: theme.appBarTheme.foregroundColor,
//         elevation: theme.appBarTheme.elevation,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh_rounded),
//             onPressed: () async {
//               final prefs = await SharedPreferences.getInstance();
//               await prefs.remove(_cacheKey);
//               await prefs.remove('${_cacheKey}_ts');
//               setState(() {
//                 _futureUnits = _loadUnitsOnce(forceRefresh: true);
//               });
//             },
//           )
//         ],
//       ),
//       body: FutureBuilder<List<Unit>>(
//         future: _futureUnits,
//         builder: (context, snap) {
//           if (snap.connectionState == ConnectionState.waiting) {
//             return _buildShimmerGrid(theme);
//           }
//           final units = snap.data ?? [];
//           if (units.isEmpty) {
//             return _buildEmptyState(theme, Icons.group_off_rounded, 'No active academic units found for your active profile layout.');
//           }
//
//           return ListView.builder(
//             padding: const EdgeInsets.symmetric(vertical: 8),
//             itemCount: units.length,
//             itemBuilder: (context, index) => _buildDropdownUnitAccordion(units[index], theme, colorScheme),
//           );
//         },
//       ),
//     );
//   }
//
//   // --- DROP-DOWN ACCORDION BLOCK (Matches Notes Tiles Perfectly) ---
//   Widget _buildDropdownUnitAccordion(Unit unit, ThemeData theme, ColorScheme colorScheme) {
//     final String campus = _sanitizePathSegment(_currentUserProfile?['campus'] ?? 'MAIN_CAMPUS');
//     final String college = _sanitizePathSegment(_currentUserProfile?['college'] ?? 'COPAS');
//     final String school = _sanitizePathSegment(_currentUserProfile?['school'] ?? 'SCIT');
//     final String dept = _sanitizePathSegment(_currentUserProfile?['department'] ?? 'COMPUTING');
//     final String coursePath = _sanitizePathSegment(_currentUserProfile?['course'] ?? 'BSc_IT');
//     final String year = 'YEAR_${unit.year}';
//     final String sem = 'SEM_${unit.semester}';
//     final String unitCode = _sanitizePathSegment(unit.id);
//
//     final groupsStream = _firestore
//         .collection('groups')
//         .doc(campus)
//         .collection(college)
//         .doc(school)
//         .collection(dept)
//         .doc(coursePath)
//         .collection(year)
//         .doc(sem)
//         .collection(unitCode)
//         .orderBy('created_at', descending: false)
//         .snapshots();
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//       child: Card(
//         color: theme.cardColor,
//         elevation: 3,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
//         child: ExpansionTile(
//           tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//           leading: Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(color: kRoyalPurple.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
//             child: const Icon(Icons.bubble_chart_rounded, color: kRoyalPurple, size: 24),
//           ),
//           title: Text(unit.name, style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
//           subtitle: Text(unit.id, style: theme.textTheme.bodySmall),
//           children: [
//             StreamBuilder<QuerySnapshot>(
//               stream: groupsStream,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
//
//                 final docs = snapshot.data?.docs ?? [];
//
//                 // Track user's joined group in this unit block
//                 DocumentSnapshot? joinedDoc;
//                 for (var d in docs) {
//                   final List members = d['members'] ?? [];
//                   if (members.any((m) => m['uid'] == _currentUserId)) {
//                     joinedDoc = d;
//                     break;
//                   }
//                 }
//
//                 return Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       if (_hasAdminPrivileges() && docs.length < 4) ...[
//                         Align(
//                           alignment: Alignment.centerRight,
//                           child: ElevatedButton.icon(
//                             style: ElevatedButton.styleFrom(backgroundColor: kAmberGold.withOpacity(0.2), foregroundColor: kAmberGold),
//                             onPressed: () => _showAdminGroupCreationDialog(unit, docs.length),
//                             icon: const Icon(Icons.add_circle_outline, size: 16),
//                             label: const Text('Add Block Partition', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
//                           ),
//                         ),
//                         const SizedBox(height: 12),
//                       ],
//
//                       if (docs.isEmpty)
//                         const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No study group segments created yet.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13))))
//                       else ...[
//                         Text('Choose Group Partition:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.disabledColor)),
//                         const SizedBox(height: 8),
//
//                         // Interactive dynamic Dropdown Selection Box
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 12),
//                           decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: colorScheme.outlineVariant)),
//                           child: DropdownButtonHideUnderline(
//                             child: DropdownButton<String>(
//                               isExpanded: true,
//                               value: joinedDoc?.id,
//                               hint: const Text('Select a group to enter/join...'),
//                               dropdownColor: theme.cardColor,
//                               items: docs.map((d) {
//                                 final List mems = d['members'] ?? [];
//                                 return DropdownMenuItem<String>(
//                                   value: d.id,
//                                   child: Text('${d['name']} (${mems.length} / ${d['max_members']} members)'),
//                                 );
//                               }).toList(),
//                               onChanged: (selectedId) {
//                                 if (selectedId == null) return;
//                                 final selectedDoc = docs.firstWhere((element) => element.id == selectedId);
//                                 _processGroupSelection(selectedDoc, unit, joinedDoc);
//                               },
//                             ),
//                           ),
//                         ),
//
//                         // Active Member Directory list presentation layer
//                         if (joinedDoc != null) ...[
//                           const SizedBox(height: 16),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text('Active Member Directory:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: kSunsetOrange)),
//                               TextButton.icon(
//                                 style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
//                                 onPressed: () => _promptLeaveGroupModal(joinedDoc!, unit),
//                                 icon: const Icon(Icons.exit_to_app_rounded, size: 16),
//                                 label: const Text('Leave Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
//                               )
//                             ],
//                           ),
//                           const SizedBox(height: 6),
//                           _buildMembersListDirectory(joinedDoc, theme),
//                         ]
//                       ]
//                     ],
//                   ),
//                 );
//               },
//             )
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildMembersListDirectory(DocumentSnapshot doc, ThemeData theme) {
//     final List members = doc['members'] ?? [];
//     return Container(
//       height: 120,
//       decoration: BoxDecoration(color: theme.scaffoldBackgroundColor.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
//       child: ListView.builder(
//         shrinkWrap: true,
//         itemCount: members.length,
//         itemBuilder: (context, index) {
//           final m = members[index];
//           return Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//             child: Row(
//               children: [
//                 const Icon(Icons.account_circle, size: 16, color: kRoyalPurple),
//                 const SizedBox(width: 8),
//                 Text(m['name'] ?? 'Student', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
//                 if (m['uid'] == _currentUserId)
//                   const Text(' (You)', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   // --- BUSINESS OPERATION LOGIC PARSERS ---
//   Future<void> _processGroupSelection(DocumentSnapshot targetDoc, Unit unit, DocumentSnapshot? currentJoinedDoc) async {
//     if (currentJoinedDoc?.id == targetDoc.id) {
//       // Rule Evaluation: If already a member, push down to Chat viewport instantly
//       Navigator.pushNamed(context, '/chatRoomWindow', arguments: {
//         'chatId': targetDoc.id,
//         'chatTitle': targetDoc['name'] ?? 'Group Room Channel',
//         'type': 'group_chat'
//       });
//       return;
//     }
//
//     if (currentJoinedDoc != null) {
//       _showNotification('Constraint Violated: You are already joined to ${currentJoinedDoc['name']}. Leave it first.', isError: true);
//       return;
//     }
//
//     final List mems = targetDoc['members'] ?? [];
//     if (mems.length >= (targetDoc['max_members'] ?? 10)) {
//       _showNotification('Operation Aborted: Target block partition capacity is completely full.', isError: true);
//       return;
//     }
//
//     // Execute atomic transation join process matrix
//     await _executeDatabaseJoin(targetDoc, unit);
//   }
//
//   Future<void> _executeDatabaseJoin(DocumentSnapshot targetDoc, Unit unit) async {
//     final String campus = _sanitizePathSegment(_currentUserProfile?['campus'] ?? 'MAIN_CAMPUS');
//     final String college = _sanitizePathSegment(_currentUserProfile?['college'] ?? 'COPAS');
//     final String school = _sanitizePathSegment(_currentUserProfile?['school'] ?? 'SCIT');
//     final String dept = _sanitizePathSegment(_currentUserProfile?['department'] ?? 'COMPUTING');
//     final String coursePath = _sanitizePathSegment(_currentUserProfile?['course'] ?? 'BSc_IT');
//     final String year = 'YEAR_${unit.year}';
//     final String sem = 'SEM_${unit.semester}';
//     final String unitCode = _sanitizePathSegment(unit.id);
//
//     final docRef = _firestore
//         .collection('groups')
//         .doc(campus)
//         .collection(college)
//         .doc(school)
//         .collection(dept)
//         .doc(coursePath)
//         .collection(year)
//         .doc(sem)
//         .collection(unitCode)
//         .doc(targetDoc.id);
//
//     try {
//       await _firestore.runTransaction((transaction) async {
//         final snap = await transaction.get(docRef);
//         if (!snap.exists) return;
//
//         List currentMembers = List.from(snap.data()?['members'] ?? []);
//         currentMembers.add({
//           'uid': _currentUserId,
//           'name': _currentUserProfile?['name'] ?? 'Student User',
//           'joined_at': Timestamp.now()
//         });
//
//         transaction.update(docRef, {'members': currentMembers});
//       });
//       _showNotification('Joined ${targetDoc['name']} successfully!');
//     } catch (e) {
//       _showNotification('Transaction Execution Failure: $e', isError: true);
//     }
//   }
//
//   Future<void> _promptLeaveGroupModal(DocumentSnapshot joinedDoc, Unit unit) async {
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Leave Study Block Partition?'),
//         content: Text('Are you sure you want to resign your structural seat position from "${joinedDoc['name']}"?'),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             onPressed: () => Navigator.pop(ctx, true),
//             child: const Text('Confirm Resign', style: TextStyle(color: Colors.white)),
//           )
//         ],
//       ),
//     );
//
//     if (confirmed != true) return;
//
//     final String campus = _sanitizePathSegment(_currentUserProfile?['campus'] ?? 'MAIN_CAMPUS');
//     final String college = _sanitizePathSegment(_currentUserProfile?['college'] ?? 'COPAS');
//     final String school = _sanitizePathSegment(_currentUserProfile?['school'] ?? 'SCIT');
//     final String dept = _sanitizePathSegment(_currentUserProfile?['department'] ?? 'COMPUTING');
//     final String coursePath = _sanitizePathSegment(_currentUserProfile?['course'] ?? 'BSc_IT');
//     final String year = 'YEAR_${unit.year}';
//     final String sem = 'SEM_${unit.semester}';
//     final String unitCode = _sanitizePathSegment(unit.id);
//
//     final docRef = _firestore
//         .collection('groups')
//         .doc(campus)
//         .collection(college)
//         .doc(school)
//         .collection(dept)
//         .doc(coursePath)
//         .collection(year)
//         .doc(sem)
//         .collection(unitCode)
//         .doc(joinedDoc.id);
//
//     try {
//       await _firestore.runTransaction((transaction) async {
//         final snap = await transaction.get(docRef);
//         if (!snap.exists) return;
//
//         List currentMembers = List.from(snap.data()?['members'] ?? []);
//         currentMembers.removeWhere((element) => element['uid'] == _currentUserId);
//
//         transaction.update(docRef, {'members': currentMembers});
//       });
//       _showNotification('Resigned membership cleanly.');
//     } catch (e) {
//       _showNotification('Disengagement failed: $e', isError: true);
//     }
//   }
//
//   // --- ADMINISTRATOR MANAGEMENT CONFIGURATORS ---
//   Future<void> _showAdminGroupCreationDialog(Unit unit, int existingCount) async {
//     if (existingCount >= 4) {
//       _showNotification('Validation Constraint Failed: Maximum group partition parameters capped at 4.', isError: true);
//       return;
//     }
//
//     final nameController = TextEditingController(text: 'Group Partition Block ${existingCount + 1}');
//     final capacityController = TextEditingController(text: '12');
//
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: Text('Create Group Allocation', style: TextStyle(color: kRoyalPurple, fontWeight: FontWeight.bold)),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Block Reference Name')),
//             const SizedBox(height: 12),
//             TextField(controller: capacityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Maximum Size Capacity Constraint')),
//           ],
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
//           ElevatedButton(
//             onPressed: () {
//               final cap = int.tryParse(capacityController.text);
//               if (nameController.text.trim().isEmpty || cap == null || cap < 1) return;
//               Navigator.pop(ctx);
//               _commitGroupToDatabaseMatrix(unit, nameController.text.trim(), cap);
//             },
//             child: const Text('Post Segment Node'),
//           )
//         ],
//       ),
//     );
//   }
//
//   Future<void> _commitGroupToDatabaseMatrix(Unit unit, String groupName, int maxMembers) async {
//     final String campus = _sanitizePathSegment(_currentUserProfile?['campus'] ?? 'MAIN_CAMPUS');
//     final String college = _sanitizePathSegment(_currentUserProfile?['college'] ?? 'COPAS');
//     final String school = _sanitizePathSegment(_currentUserProfile?['school'] ?? 'SCIT');
//     final String dept = _sanitizePathSegment(_currentUserProfile?['department'] ?? 'COMPUTING');
//     final String coursePath = _sanitizePathSegment(_currentUserProfile?['course'] ?? 'BSc_IT');
//     final String year = 'YEAR_${unit.year}';
//     final String sem = 'SEM_${unit.semester}';
//     final String unitCode = _sanitizePathSegment(unit.id);
//
//     try {
//       await _firestore
//           .collection('groups')
//           .doc(campus)
//           .collection(college)
//           .doc(school)
//           .collection(dept)
//           .doc(coursePath)
//           .collection(year)
//           .doc(sem)
//           .collection(unitCode)
//           .add({
//         'name': groupName,
//         'max_members': maxMembers,
//         'course_code': unit.id,
//         'created_by': _currentUserId,
//         'created_at': FieldValue.serverTimestamp(),
//         'members': [],
//       });
//       _showNotification('New collection layout partition created successfully.');
//     } catch (e) {
//       _showNotification('Failed to generate collection block: $e', isError: true);
//     }
//   }
//
//   Widget _buildEmptyState(ThemeData theme, IconData icon, String message) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(icon, size: 54, color: theme.disabledColor),
//             const SizedBox(height: 16),
//             Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildShimmerGrid(ThemeData theme) {
//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: 4,
//       itemBuilder: (_, _) => Shimmer.fromColors(
//         baseColor: theme.cardColor.withOpacity(0.5),
//         highlightColor: theme.cardColor.withOpacity(0.2),
//         child: Container(height: 85, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
//       ),
//     );
//   }
// }
// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/unit_model.dart'; // Reuses your unified Unit model structure
import '../../widgets/theme_manager.dart'; // Imports kSunsetOrange, kAmberGold, kRoyalPurple

class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Future<List<Unit>> _futureUnits;
  Map<String, dynamic>? _currentUserProfile;
  String? _currentUserId;
  bool _isProfileLoading = true;

  static const String _cacheKey = 'cachedGroupUnits_v2';
  static const Duration _cacheMaxAge = Duration(hours: 24);

  @override
  void initState() {
    super.initState();
    _futureUnits = _loadUnitsOnce();
    _loadUserProfileContext();
  }

  Future<void> _loadUserProfileContext() async {
    final user = _auth.currentUser;
    if (user == null) return;
    _currentUserId = user.uid;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _currentUserProfile = doc.data();
          _isProfileLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user metadata context: $e');
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  Future<List<Unit>> _loadUnitsOnce({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final tsStr = prefs.getString('${_cacheKey}_ts');
      final cachedData = prefs.getString(_cacheKey);
      if (cachedData != null && tsStr != null) {
        final ts = DateTime.tryParse(tsStr);
        if (ts != null && DateTime.now().difference(ts) < _cacheMaxAge) {
          try {
            return Unit.decodeList(cachedData);
          } catch (_) {}
        }
      }
    }

    final user = _auth.currentUser;
    if (user == null) return [];

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return [];

    final data = doc.data()!;
    final List<dynamic> registeredUnits = data['registered_units'] ?? [];
    final year = data['year'] ?? "1";
    final semester = data['semester'] ?? "1";
    final currentYear =
        int.tryParse(year.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final currentSemester =
        int.tryParse(semester.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

    final units = registeredUnits
        .map(
          (u) => Unit(
        id: u['code'],
        name: u['title'],
        year: currentYear,
        semester: currentSemester,
      ),
    )
        .toList();

    await prefs.setString(_cacheKey, Unit.encodeList(units));
    await prefs.setString('${_cacheKey}_ts', DateTime.now().toIso8601String());

    return units;
  }

  bool _hasAdminPrivileges() {
    final r = _currentUserProfile?['role'] ?? '';
    return r == 'admin' || r == 'class_rep' || r == 'assistant';
  }

  String _sanitizePathSegment(String input) {
    if (input.trim().isEmpty) return 'UNKNOWN';
    return input
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .toUpperCase();
  }

  void _showNotification(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.red : kSunsetOrange,
      ),
    );
  }

  // --- DOWNLOAD DATA UTILITY MATRIX ---
  Future<void> _downloadGroupDirectory({
    required String unitCode,
    required String groupName,
    required List members,
  }) async {
    try {
      final StringBuffer csvContent = StringBuffer();
      csvContent.writeln('STUDY GROUP ROSTER: $groupName ($unitCode)');
      csvContent.writeln('Generated on: ${DateTime.now().toLocal()}');
      csvContent.writeln('');
      csvContent.writeln('Index,Student Name,Registration Number,Joined Date');

      for (int i = 0; i < members.length; i++) {
        final m = members[i];
        final String name = m['full_name'] ?? m['name'] ?? 'N/A';
        // ✅ FIX: Maps directly to your specific 'reg_number' key configuration signature
        final String regNo = m['reg_number'] ?? m['reg_no'] ?? 'NOT_PROVIDED';
        final String joinedDate = m['joined_at'] != null
            ? (m['joined_at'] as Timestamp).toDate().toLocal().toString().split(
          ' ',
        )[0]
            : 'N/A';

        csvContent.writeln('${i + 1},$name,$regNo,$joinedDate');
      }

      final directory = await getTemporaryDirectory();
      final String safeName = groupName
          .replaceAll(RegExp(r'[\s\-]+'), '_')
          .toLowerCase();
      final File csvFile = File(
        '${directory.path}/${unitCode}_${safeName}_members.csv',
      );

      await csvFile.writeAsString(csvContent.toString());

      if (csvFile.existsSync()) {
        await Share.shareXFiles([
          XFile(csvFile.path),
        ], text: 'Academic Export Registry: $groupName - $unitCode');
      }
    } catch (e) {
      debugPrint('Export failed: $e');
      _showNotification(
        'Failed to generate spreadsheet export document.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isProfileLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: _buildShimmerGrid(theme),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Study Groups Dropdown',
          style: theme.appBarTheme.titleTextStyle,
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: theme.appBarTheme.elevation,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_cacheKey);
              await prefs.remove('${_cacheKey}_ts');
              setState(() {
                _futureUnits = _loadUnitsOnce(forceRefresh: true);
              });
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          FutureBuilder<List<Unit>>(
            future: _futureUnits,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(child: _buildShimmerGrid(theme));
              }
              final units = snap.data ?? [];
              if (units.isEmpty) {
                return SliverFillRemaining(
                  child: _buildEmptyState(
                    theme,
                    Icons.group_off_rounded,
                    'No active academic units found for your active profile layout.',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildDropdownUnitAccordion(
                      units[index],
                      theme,
                      colorScheme,
                    ),
                    childCount: units.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownUnitAccordion(
      Unit unit,
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    final String campus = _sanitizePathSegment(
      _currentUserProfile?['campus'] ?? 'MAIN_CAMPUS',
    );
    final String college = _sanitizePathSegment(
      _currentUserProfile?['college'] ?? 'COPAS',
    );
    final String school = _sanitizePathSegment(
      _currentUserProfile?['school'] ?? 'SCIT',
    );
    final String dept = _sanitizePathSegment(
      _currentUserProfile?['department'] ?? 'COMPUTING',
    );
    final String coursePath = _sanitizePathSegment(
      _currentUserProfile?['course'] ?? 'BSc_IT',
    );
    final String year = 'YEAR_${unit.year}';
    final String sem = 'SEM_${unit.semester}';
    final String unitCode = _sanitizePathSegment(unit.id);

    final groupsStream = _firestore
        .collection('groups')
        .doc(campus)
        .collection(college)
        .doc(school)
        .collection(dept)
        .doc(coursePath)
        .collection(year)
        .doc(sem)
        .collection(unitCode)
        .orderBy('created_at', descending: false)
        .snapshots();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        color: theme.cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          // border: Border.all(
          //   color: colorScheme.outlineVariant.withOpacity(0.4),
          //   width: 1,
          // ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ExpansionTile(
            backgroundColor: theme.cardColor,
            collapsedBackgroundColor: theme.cardColor,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            childrenPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kRoyalPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: kRoyalPurple,
                size: 22,
              ),
            ),
            title: Text(
              unit.name,
              style: theme.textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                unit.id.toUpperCase(),
                style: theme.textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.disabledColor,
                ),
              ),
            ),
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: groupsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  DocumentSnapshot? joinedDoc;
                  for (var d in docs) {
                    final List members = d['members'] ?? [];
                    if (members.any((m) => m['uid'] == _currentUserId)) {
                      joinedDoc = d;
                      break;
                    }
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor.withOpacity(0.3),
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outlineVariant.withOpacity(0.4),
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (docs.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'No study group segments created yet.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          )
                        else ...[
                          Text(
                            'AVAILABLE WORKSPACE PARTITIONS',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: theme.disabledColor.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 10),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            itemBuilder: (context, idx) {
                              final groupDoc = docs[idx];
                              final String gName =
                                  groupDoc['name'] ?? 'Group Segment';
                              final List memsList = groupDoc['members'] ?? [];
                              final int maxCap = groupDoc['max_members'] ?? 12;
                              final bool isSelectedGroup =
                                  joinedDoc?.id == groupDoc.id;
                              final bool isGroupFull =
                                  memsList.length >= maxCap;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _handleInteractiveGroupTap(
                                    groupDoc,
                                    unit,
                                    joinedDoc,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelectedGroup
                                          ? kRoyalPurple.withOpacity(0.06)
                                          : theme.cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelectedGroup
                                            ? kRoyalPurple
                                            : colorScheme.outlineVariant
                                            .withOpacity(0.6),
                                        width: isSelectedGroup ? 1.8 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(
                                            isSelectedGroup ? 0.04 : 0.01,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelectedGroup
                                              ? Icons.check_circle_rounded
                                              : (isGroupFull
                                              ? Icons.lock_rounded
                                              : Icons
                                              .radio_button_unchecked_rounded),
                                          color: isSelectedGroup
                                              ? kRoyalPurple
                                              : (isGroupFull
                                              ? Colors.red.shade400
                                              : theme.disabledColor),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                gName,
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                  fontWeight:
                                                  FontWeight.bold,
                                                  color: isSelectedGroup
                                                      ? kRoyalPurple
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${memsList.length} of $maxCap seats occupied',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: isGroupFull
                                                      ? Colors.red.shade400
                                                      : theme.disabledColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelectedGroup
                                                ? kRoyalPurple.withOpacity(0.12)
                                                : (isGroupFull
                                                ? Colors.red.withOpacity(
                                              0.08,
                                            )
                                                : colorScheme
                                                .surfaceVariant),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            isSelectedGroup
                                                ? 'ENTER CHAT'
                                                : (isGroupFull
                                                ? 'FULL'
                                                : 'JOIN'),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isSelectedGroup
                                                  ? kRoyalPurple
                                                  : (isGroupFull
                                                  ? Colors.red
                                                  : theme.disabledColor),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          if (joinedDoc != null) ...[
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: kSunsetOrange,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'MEMBER DIRECTORY',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                        color: kSunsetOrange,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red.shade400,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _promptLeaveGroupModal(joinedDoc!, unit),
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    size: 14,
                                  ),
                                  label: const Text(
                                    'Leave Group',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildMembersListDirectory(
                              joinedDoc,
                              theme,
                              colorScheme,
                            ),
                          ],
                        ],

                        if (_hasAdminPrivileges() && docs.length < 4) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: kAmberGold.withOpacity(0.15),
                                foregroundColor: kAmberGold,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _showAdminGroupCreationDialog(
                                unit,
                                docs.length,
                              ),
                              icon: const Icon(Icons.add_box_rounded, size: 18),
                              label: const Text(
                                'Create New Partition Segment Allocation',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersListDirectory(
      DocumentSnapshot doc,
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    final List members = doc['members'] ?? [];
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: members.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 0.5,
          color: colorScheme.outlineVariant.withOpacity(0.4),
        ),
        itemBuilder: (context, index) {
          final m = members[index];
          // ✅ FIX: Reads 'full_name' first to capture profile format parameters cleanly
          final String name = m['full_name'] ?? m['name'] ?? 'Student';
          final bool isMe = m['uid'] == _currentUserId;

          final List<String> nameParts = name.trim().split(' ');
          final String initials = nameParts.length > 1
              ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
              : nameParts[0][0].toUpperCase();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isMe
                      ? kSunsetOrange.withOpacity(0.1)
                      : kRoyalPurple.withOpacity(0.1),
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isMe ? kSunsetOrange : kRoyalPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isMe)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.disabledColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'YOU',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleInteractiveGroupTap(
      DocumentSnapshot targetDoc,
      Unit unit,
      DocumentSnapshot? currentJoinedDoc,
      ) {
    final List mems = targetDoc['members'] ?? [];
    final int maxCapacity = targetDoc['max_members'] ?? 12;
    final String groupName = targetDoc['name'] ?? 'Group Segment';

    if (currentJoinedDoc?.id == targetDoc.id) {
      Navigator.pushNamed(
        context,
        '/chatRoomWindow',
        arguments: {
          'chatId': targetDoc.id,
          'chatTitle': groupName,
          'type': 'group_chat',
        },
      );
      return;
    }

    if (currentJoinedDoc != null) {
      _showNotification(
        'Constraint Violated: You already belong to ${currentJoinedDoc['name']}. Leave it first.',
        isError: true,
      );
      return;
    }

    _showGroupJoinDialog(targetDoc, unit, mems, maxCapacity, groupName);
  }

  void _showGroupJoinDialog(
      DocumentSnapshot targetDoc,
      Unit unit,
      List mems,
      int maxCapacity,
      String groupName,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isFull = mems.length >= maxCapacity;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: theme.cardColor,
        title: Row(
          children: [
            Icon(
              Icons.diversity_3_rounded,
              color: isFull ? Colors.red : kRoyalPurple,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                groupName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Partition Capacity:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isFull
                        ? Colors.red.withOpacity(0.12)
                        : Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isFull
                        ? 'FULL (${mems.length}/$maxCapacity)'
                        : '${mems.length} / $maxCapacity Seats Taken',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isFull ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Roster Directory:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: theme.disabledColor,
                  ),
                ),
                if (_hasAdminPrivileges())
                  IconButton(
                    icon: const Icon(
                      Icons.sim_card_download_rounded,
                      color: kSunsetOrange,
                      size: 22,
                    ),
                    tooltip: 'Download CSV Roster Registry Spreadsheet',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _downloadGroupDirectory(
                        unitCode: unit.id,
                        groupName: groupName,
                        members: mems,
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),

            Container(
              height: 140,
              width: double.maxFinite,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withOpacity(0.4),
                ),
              ),
              child: mems.isEmpty
                  ? const Center(
                child: Text(
                  'No students joined this partition yet.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
                  : ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: mems.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withOpacity(0.3),
                ),
                itemBuilder: (c, idx) {
                  final student = mems[idx];
                  // ✅ FIX: Reads profile mapping properties correctly matching transaction setups
                  final String stdName =
                      student['full_name'] ?? student['name'] ?? 'Student';
                  final String regNum =
                      student['reg_number'] ??
                          student['reg_no'] ??
                          'NOT_PROVIDED';
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person,
                          size: 14,
                          color: kRoyalPurple,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            stdName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          regNum,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.disabledColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (!isFull)
              Text(
                'Do you want to join group $groupName?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              )
            else
              const Text(
                'This partition slot configuration is completely full and closed.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isFull ? 'CLOSE' : 'NO',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          if (!isFull)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kRoyalPurple),
              onPressed: () {
                Navigator.pop(ctx);
                _executeDatabaseJoin(targetDoc, unit);
              },
              child: const Text(
                'YES, JOIN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _executeDatabaseJoin(
      DocumentSnapshot targetDoc,
      Unit unit,
      ) async {
    final String campus = _sanitizePathSegment(
      _currentUserProfile?['campus'] ?? 'MAIN_CAMPUS',
    );
    final String college = _sanitizePathSegment(
      _currentUserProfile?['college'] ?? 'COPAS',
    );
    final String school = _sanitizePathSegment(
      _currentUserProfile?['school'] ?? 'SCIT',
    );
    final String dept = _sanitizePathSegment(
      _currentUserProfile?['department'] ?? 'COMPUTING',
    );
    final String coursePath = _sanitizePathSegment(
      _currentUserProfile?['course'] ?? 'BSc_IT',
    );
    final String year = 'YEAR_${unit.year}';
    final String sem = 'SEM_${unit.semester}';
    final String unitCode = _sanitizePathSegment(unit.id);

    final docRef = _firestore
        .collection('groups')
        .doc(campus)
        .collection(college)
        .doc(school)
        .collection(dept)
        .doc(coursePath)
        .collection(year)
        .doc(sem)
        .collection(unitCode)
        .doc(targetDoc.id);

    try {
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) return;

        List currentMembers = List.from(snap.data()?['members'] ?? []);
        // ✅ FIX: Formats values exactly to match your user node fields ('full_name' and 'reg_number')
        currentMembers.add({
          'uid': _currentUserId,
          'full_name':
          _currentUserProfile?['full_name'] ?? 'Student User',
          'reg_number':
          _currentUserProfile?['reg_number'] ?? 'NOT_PROVIDED',
          'joined_at': Timestamp.now(),
        });

        transaction.update(docRef, {'members': currentMembers});
      });
      _showNotification('Joined ${targetDoc['name']} successfully!');
    } catch (e) {
      _showNotification('Transaction Execution Failure: $e', isError: true);
    }
  }

  Future<void> _promptLeaveGroupModal(
      DocumentSnapshot joinedDoc,
      Unit unit,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Study Block Partition?'),
        content: Text(
          'Are you sure you want to resign your structural seat position from "${joinedDoc['name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Confirm Resign',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final String campus = _sanitizePathSegment(
      _currentUserProfile?['campus'] ?? 'MAIN_CAMPUS',
    );
    final String college = _sanitizePathSegment(
      _currentUserProfile?['college'] ?? 'COPAS',
    );
    final String school = _sanitizePathSegment(
      _currentUserProfile?['school'] ?? 'SCIT',
    );
    final String dept = _sanitizePathSegment(
      _currentUserProfile?['department'] ?? 'COMPUTING',
    );
    final String coursePath = _sanitizePathSegment(
      _currentUserProfile?['course'] ?? 'BSc_IT',
    );
    final String year = 'YEAR_${unit.year}';
    final String sem = 'SEM_${unit.semester}';
    final String unitCode = _sanitizePathSegment(unit.id);

    final docRef = _firestore
        .collection('groups')
        .doc(campus)
        .collection(college)
        .doc(school)
        .collection(dept)
        .doc(coursePath)
        .collection(year)
        .doc(sem)
        .collection(unitCode)
        .doc(joinedDoc.id);

    try {
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) return;

        List currentMembers = List.from(snap.data()?['members'] ?? []);
        currentMembers.removeWhere(
              (element) => element['uid'] == _currentUserId,
        );

        transaction.update(docRef, {'members': currentMembers});
      });
      _showNotification('Resigned membership cleanly.');
    } catch (e) {
      _showNotification('Disengagement failed: $e', isError: true);
    }
  }

  Future<void> _showAdminGroupCreationDialog(
      Unit unit,
      int existingCount,
      ) async {
    if (existingCount >= 4) {
      _showNotification(
        'Validation Constraint Failed: Maximum group partition parameters capped at 4.',
        isError: true,
      );
      return;
    }

    final nameController = TextEditingController(
      text: 'Group Partition Block ${existingCount + 1}',
    );
    final capacityController = TextEditingController(text: '12');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Create Group Allocation',
          style: TextStyle(color: kRoyalPurple, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Block Reference Name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Maximum Size Capacity Constraint',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final cap = int.tryParse(capacityController.text);
              if (nameController.text.trim().isEmpty || cap == null || cap < 1)
                return;
              Navigator.pop(ctx);
              _commitGroupToDatabaseMatrix(
                unit,
                nameController.text.trim(),
                cap,
              );
            },
            child: const Text('Post Segment Node'),
          ),
        ],
      ),
    );
  }

  Future<void> _commitGroupToDatabaseMatrix(
      Unit unit,
      String groupName,
      int maxMembers,
      ) async {
    final String campus = _sanitizePathSegment(
      _currentUserProfile?['campus'] ?? 'MAIN_CAMPUS',
    );
    final String college = _sanitizePathSegment(
      _currentUserProfile?['college'] ?? 'COPAS',
    );
    final String school = _sanitizePathSegment(
      _currentUserProfile?['school'] ?? 'SCIT',
    );
    final String dept = _sanitizePathSegment(
      _currentUserProfile?['department'] ?? 'COMPUTING',
    );
    final String coursePath = _sanitizePathSegment(
      _currentUserProfile?['course'] ?? 'BSc_IT',
    );
    final String year = 'YEAR_${unit.year}';
    final String sem = 'SEM_${unit.semester}';
    final String unitCode = _sanitizePathSegment(unit.id);

    try {
      await _firestore
          .collection('groups')
          .doc(campus)
          .collection(college)
          .doc(school)
          .collection(dept)
          .doc(coursePath)
          .collection(year)
          .doc(sem)
          .collection(unitCode)
          .add({
        'name': groupName,
        'max_members': maxMembers,
        'course_code': unit.id,
        'created_by': _currentUserId,
        'created_at': FieldValue.serverTimestamp(),
        'members': [],
      });
      _showNotification(
        'New collection layout partition created successfully.',
      );
    } catch (e) {
      _showNotification(
        'Failed to generate collection block: $e',
        isError: true,
      );
    }
  }

  Widget _buildEmptyState(ThemeData theme, IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 54, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerGrid(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: theme.cardColor.withOpacity(0.5),
        highlightColor: theme.cardColor.withOpacity(0.2),
        child: Container(
          height: 85,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
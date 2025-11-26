import 'package:campus_app/screens/announcement/upload_announcement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart'; // Ensure this import points to your file

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _canPost = false;

  // --- FILTER STATE ---
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Class Confirmation',
    'Notes',
    'Assignment',
    'CAT'
  ];

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  /// Checks Firestore to see if the user has permission to view the FAB
  Future<void> _checkUserRole() async {
    if (currentUser == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists) {
        final role = doc.data()?['role'] ?? 'student';
        // Check against the allowed roles list
        if (role == 'admin' || role == 'class_rep' || role == 'assistant') {
          if (mounted) {
            setState(() => _canPost = true);
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking role: $e");
    }
  }

  /// Color logic based on Announcement Type
  Color _getColorForType(String type) {
    switch (type) {
      case 'Notes':
        return Colors.blue;
      case 'Assignment':
        return AppColors.secondary; // Green
      case 'CAT':
        return AppColors.error; // Red
      case 'Class Confirmation':
        return AppColors.primary; // Indigo
      default:
        return AppColors.darkGrey;
    }
  }

  /// Icon logic based on Announcement Type
  IconData _getIconForType(String type) {
    switch (type) {
      case 'Notes':
        return Icons.book;
      case 'Assignment':
        return Icons.assignment;
      case 'CAT':
        return Icons.warning_amber_rounded;
      case 'Class Confirmation':
        return Icons.class_;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Class Groups", style:const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
      ),
      backgroundColor: AppColors.background,
      floatingActionButton: _canPost
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CreateAnnouncementScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        tooltip: 'Post Announcement',
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      )
          : null,
      body: Column(
        children: [
          // --- FILTER CHIPS SECTION ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _filterOptions.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  // Get color for the filter text/border (use Primary for 'All')
                  final typeColor = filter == 'All'
                      ? AppColors.primary
                      : _getColorForType(filter);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.white : typeColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        if (selected) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        }
                      },
                      selectedColor: typeColor,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? Colors.transparent : typeColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      // Remove default padding/elevation behavior
                      showCheckmark: false,
                      elevation: isSelected ? 2 : 0,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // --- LIST SECTION ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('announcements')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading announcements"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary));
                }

                final allData = snapshot.data!.docs;

                // --- FILTER LOGIC ---
                final filteredData = _selectedFilter == 'All'
                    ? allData
                    : allData.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['type'] == _selectedFilter;
                }).toList();

                if (filteredData.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list_off,
                            size: 64, color: AppColors.darkGrey.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFilter == 'All'
                              ? "No announcements yet."
                              : "No $_selectedFilter found.",
                          style: const TextStyle(
                              color: AppColors.darkGrey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredData.length,
                  itemBuilder: (context, index) {
                    final item = filteredData[index].data() as Map<String, dynamic>;
                    final String type = item['type'] ?? 'General';
                    final String title = item['title'] ?? 'No Title';
                    final String desc = item['description'] ?? '';
                    final Timestamp? targetDate = item['target_date'];

                    final color = _getColorForType(type);

                    return Card(
                      elevation: 3,
                      shadowColor: Colors.black12,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.lightGrey, width: 1),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Color Strip (Left Border)
                            Container(
                              width: 6,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Type Badge and Short Date
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.1),
                                            borderRadius:
                                            BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(_getIconForType(type),
                                                  size: 14, color: color),
                                              const SizedBox(width: 6),
                                              Text(
                                                type.toUpperCase(),
                                                style: TextStyle(
                                                  color: color,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (targetDate != null)
                                          Text(
                                            DateFormat('MMM d')
                                                .format(targetDate.toDate()),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.darkGrey,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Title
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Description
                                    Text(
                                      desc,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(
                                            0xFF4B5563), // Slightly darker grey for readability
                                        height: 1.4,
                                      ),
                                    ),

                                    // Footer: Detailed Date/Time
                                    if (targetDate != null) ...[
                                      const SizedBox(height: 16),
                                      Divider(
                                          color: AppColors.lightGrey, height: 1),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.event_available,
                                              size: 16, color: color),
                                          const SizedBox(width: 8),
                                          Text(
                                            type == 'CAT'
                                                ? 'Sitting:'
                                                : type == 'Assignment'
                                                ? 'Due:'
                                                : 'Date:',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: color,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormat('EEE, MMM d @ h:mm a')
                                                .format(targetDate.toDate()),
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      )
                                    ]
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
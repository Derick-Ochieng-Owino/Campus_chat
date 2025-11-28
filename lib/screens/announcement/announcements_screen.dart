import 'package:campus_app/screens/announcement/upload_announcement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/theme_manager.dart'; // Add shimmer dependency in pubspec.yaml

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  bool _canPost = false;
  bool _isLoading = true;

  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Class Confirmation',
    'Notes',
    'Assignment',
    'CAT'
  ];

  /// Local cache of announcements for the session
  static List<Map<String, dynamic>>? _cachedAnnouncements;

  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadAnnouncements();
  }

  Future<void> _checkUserRole() async {
    if (currentUser == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists) {
        final role = doc.data()?['role'] ?? 'student';
        if (role == 'admin' || role == 'class_rep' || role == 'assistant') {
          if (mounted) setState(() => _canPost = true);
        }
      }
    } catch (e) {
      debugPrint("Error checking role: $e");
    }
  }

  Future<void> _loadAnnouncements() async {
    if (_cachedAnnouncements != null) {
      // Use cache
      setState(() {
        _announcements = _cachedAnnouncements!;
        _isLoading = false;
      });
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('created_at', descending: true)
          .get();

      final now = DateTime.now();

      List<Map<String, dynamic>> tempAnnouncements = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final Timestamp? targetTimestamp = data['target_date'];

        // Auto-delete Class Confirmations 24 hrs after the class
        if (data['type'] == 'Class Confirmation' && targetTimestamp != null) {
          final classTime = targetTimestamp.toDate();
          if (now.difference(classTime).inHours >= 24) {
            // Delete old announcement
            FirebaseFirestore.instance.collection('announcements').doc(doc.id).delete();
            continue; // Skip adding it to list
          }
        }

        tempAnnouncements.add({
          ...data,
          'docId': doc.id, // Keep docId in case you want to update/delete
        });
      }

      if (!mounted) return;

      setState(() {
        _announcements = tempAnnouncements;
        _cachedAnnouncements = tempAnnouncements; // cache for session
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading announcements: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Color _getColorForType(BuildContext context, String type) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case 'Notes':
        return Colors.blue.shade400;
      case 'Assignment':
        return colorScheme.secondary;
      case 'CAT':
        return colorScheme.error;
      case 'Class Confirmation':
        return kAmberGold;
      default:
        return colorScheme.onSurface.withOpacity(0.6);
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Notes':
        return Icons.book_rounded;
      case 'Assignment':
        return Icons.assignment_turned_in_rounded;
      case 'CAT':
        return Icons.warning_amber_rounded;
      case 'Class Confirmation':
        return Icons.class_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurfaceSubtle = colorScheme.onSurface.withOpacity(0.7);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Announcements", style: theme.textTheme.titleLarge),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      floatingActionButton: _canPost
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CreateAnnouncementScreen()),
          );
        },
        backgroundColor: colorScheme.primary,
        tooltip: 'Post Announcement',
        child: Icon(Icons.add, color: colorScheme.onPrimary, size: 28),
      )
          : null,
      body: Column(
        children: [
          // --- FILTER CHIPS SECTION ---
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _filterOptions.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  final typeColor =
                  filter == 'All' ? colorScheme.primary : _getColorForType(context, filter);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        filter,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: isSelected ? colorScheme.onSecondary : typeColor,
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
                      backgroundColor: theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? Colors.transparent : typeColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      showCheckmark: false,
                      elevation: isSelected ? 2 : 0,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? _buildShimmerLoading(context)
                : _announcements.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.filter_list_off_rounded,
                      size: 64, color: onSurfaceSubtle),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFilter == 'All'
                        ? "No announcements yet."
                        : "No $_selectedFilter found.",
                    style: theme.textTheme.bodyMedium!
                        .copyWith(color: onSurfaceSubtle),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _announcements.length,
              itemBuilder: (context, index) {
                final item = _announcements[index];
                final String type = item['type'] ?? 'General';
                final String title = item['title'] ?? 'No Title';
                final String desc = item['description'] ?? '';
                final Timestamp? targetDate = item['target_date'];

                if (_selectedFilter != 'All' && type != _selectedFilter) {
                  return const SizedBox.shrink();
                }

                final color = _getColorForType(context, type);

                return Card(
                  color: theme.cardColor,
                  elevation: 3,
                  shadowColor: Colors.black12,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: colorScheme.onSurface.withOpacity(0.1),
                        width: 1),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_getIconForType(type),
                                              size: 14, color: color),
                                          const SizedBox(width: 6),
                                          Text(
                                            type.toUpperCase(),
                                            style: theme.textTheme.bodySmall!
                                                .copyWith(
                                              color: color,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (targetDate != null)
                                      Text(
                                        DateFormat('MMM d').format(targetDate.toDate()),
                                        style: theme.textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  title,
                                  style: theme.textTheme.titleMedium!.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  desc,
                                  style: theme.textTheme.bodyMedium!.copyWith(
                                    color: colorScheme.onSurface.withOpacity(0.7),
                                    height: 1.4,
                                  ),
                                ),
                                if (targetDate != null) ...[
                                  const SizedBox(height: 16),
                                  Divider(color: theme.dividerColor, height: 1),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.event_available_rounded,
                                          size: 16, color: color),
                                      const SizedBox(width: 8),
                                      Text(
                                        type == 'CAT'
                                            ? 'Sitting:'
                                            : type == 'Assignment'
                                            ? 'Due:'
                                            : 'Date:',
                                        style: theme.textTheme.bodySmall!.copyWith(
                                          color: color,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('EEE, MMM d @ h:mm a')
                                            .format(targetDate.toDate()),
                                        style: theme.textTheme.bodySmall!
                                            .copyWith(fontWeight: FontWeight.w500),
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
            ),
          ),
        ],
      ),
    );
  }

  // Shimmer loading skeleton
  Widget _buildShimmerLoading(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: theme.cardColor.withOpacity(0.4),
        highlightColor: theme.cardColor.withOpacity(0.1),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 120,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

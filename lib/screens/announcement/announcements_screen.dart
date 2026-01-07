import 'package:alma_mata/screens/announcement/upload_announcement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../widgets/theme_manager.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  bool _canPost = false;
  String _selectedFilter = 'All';

  final List<String> _filterOptions = [
    'All',
    'Class Confirmation',
    'Notes',
    'Assignment',
    'CAT',
    'Past Paper'
  ];

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists && mounted) {
        final role = doc.data()?['role'] ?? 'student';
        setState(() {
          _canPost = (role == 'admin' || role == 'class_rep' || role == 'assistant');
        });
      }
    } catch (e) {
      debugPrint("Error checking role: $e");
    }
  }

  Color _getColorForType(BuildContext context, String type) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case 'Notes': return Colors.blue.shade400;
      case 'Past Paper': return Colors.teal.shade400;
      case 'Assignment': return colorScheme.secondary;
      case 'CAT': return colorScheme.error;
      case 'Class Confirmation': return kAmberGold;
      default: return colorScheme.onSurface.withOpacity(0.6);
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Notes': return Icons.book_rounded;
      case 'Past Paper': return Icons.history_edu_rounded;
      case 'Assignment': return Icons.assignment_turned_in_rounded;
      case 'CAT': return Icons.warning_amber_rounded;
      case 'Class Confirmation': return Icons.class_rounded;
      default: return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateAnnouncementScreen()),
        ),
        backgroundColor: colorScheme.primary,
        child: Icon(Icons.add, color: colorScheme.onPrimary, size: 28),
      )
          : null,
      body: Column(
        children: [
          _buildFilterChips(theme, colorScheme),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('announcements')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error loading announcements"));
                if (snapshot.connectionState == ConnectionState.waiting) return _buildShimmerLoading(context);

                final now = DateTime.now();

                // Real-time Filtering logic
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'General';
                  final targetTimestamp = data['target_date'] as Timestamp?;

                  // 1. Hide Class Confirmations older than 24 hours
                  if (type == 'Class Confirmation' && targetTimestamp != null) {
                    if (now.difference(targetTimestamp.toDate()).inHours >= 24) return false;
                  }

                  // 2. Chip Filter
                  if (_selectedFilter == 'All') return true;
                  return type == _selectedFilter;
                }).toList();

                if (filteredDocs.isEmpty) return _buildEmptyState(theme, colorScheme);

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final item = filteredDocs[index].data() as Map<String, dynamic>;
                    return _buildAnnouncementCard(context, item, theme, colorScheme);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _filterOptions.map((filter) {
            final isSelected = _selectedFilter == filter;
            final typeColor = filter == 'All' ? colorScheme.primary : _getColorForType(context, filter);
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(filter, style: TextStyle(color: isSelected ? colorScheme.onPrimary : typeColor)),
                selected: isSelected,
                onSelected: (selected) => setState(() => _selectedFilter = filter),
                selectedColor: typeColor,
                backgroundColor: theme.cardColor,
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(BuildContext context, Map<String, dynamic> item, ThemeData theme, ColorScheme colorScheme) {
    final type = item['type'] ?? 'General';
    final color = _getColorForType(context, type);
    final targetDate = item['target_date'] as Timestamp?;

    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 6, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTypeBadge(type, color, theme),
                        if (targetDate != null) Text(DateFormat('MMM d').format(targetDate.toDate()), style: theme.textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(item['title'] ?? 'No Title', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(item['description'] ?? '', style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                    if (targetDate != null) ...[
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(Icons.event_available_rounded, size: 16, color: color),
                          const SizedBox(width: 8),
                          Text(DateFormat('EEE, MMM d @ h:mm a').format(targetDate.toDate()), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
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
  }

  Widget _buildTypeBadge(String type, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(_getIconForType(type), size: 14, color: color),
          const SizedBox(width: 6),
          Text(type.toUpperCase(), style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off_rounded, size: 64, color: colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text("No announcements found.", style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Theme.of(context).cardColor.withOpacity(0.5),
        highlightColor: Theme.of(context).cardColor.withOpacity(0.2),
        child: Container(height: 120, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
      ),
    );
  }
}
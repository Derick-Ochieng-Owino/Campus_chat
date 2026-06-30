import 'package:alma_mata/screens/announcement/upload_announcement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
// import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import 'fcm_initializer.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen>
    with AutomaticKeepAliveClientMixin {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  Stream<QuerySnapshot>? _announcementsStream;

  bool _canPost = false;
  bool _isProfileLoading = true;
  String _selectedFilter = 'All';
  DateTime _focusedCalendarMonth = DateTime.now();
  DateTime? _selectedCalendarDay;
  Map<String, dynamic>? _userAcademicProfile;

  final List<String> _filterOptions = [
    'All',
    'Calendar',
    'General',
    'Class Confirmation',
    'Notes',
    'Assignment',
    'CAT',
    'Past Paper',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchUserDataAndInitStream();
  }

  String _sanitizePathSegment(String input) {
    if (input.trim().isEmpty) return 'UNKNOWN';
    return input
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .toUpperCase();
  }

  Future<void> _fetchUserDataAndInitStream() async {
    if (currentUser == null) {
      setState(() => _isProfileLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        final role = data['role'] ?? 'student';

        final String campus = _sanitizePathSegment(
          data['campus'] ?? 'MAIN_CAMPUS',
        );
        final String college = _sanitizePathSegment(data['college'] ?? 'COPAS');
        final String school = _sanitizePathSegment(data['school'] ?? 'SCIT');
        final String dept = _sanitizePathSegment(
          data['department'] ?? 'COMPUTING',
        );
        final String course = _sanitizePathSegment(data['course'] ?? 'BSc_IT');
        final String rawYear =
            data['year']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '1';
        final String rawSem =
            data['semester']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ??
            '1';
        final String year = 'YEAR_$rawYear';
        final String sem = 'SEM_$rawSem';

        setState(() {
          _userAcademicProfile = data;
          _canPost =
              (role == 'admin' || role == 'class_rep' || role == 'assistant');

          _announcementsStream = FirebaseFirestore.instance
              .collection('announcements')
              .doc(campus)
              .collection(college)
              .doc(school)
              .collection(dept)
              .doc(course)
              .collection(year)
              .doc(sem)
              .collection('notices')
              .orderBy('created_at', descending: true)
              .snapshots();

          _isProfileLoading = false;
        });
      } else {
        setState(() => _isProfileLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading profile metrics: $e");
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  void _showAdministrativeOptions(
    BuildContext context,
    String documentId,
    Map<String, dynamic> currentData,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.edit_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text(
                  'Edit Account Information',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Modify description, title, text notes or attachments.',
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateAnnouncementScreen(
                        existingDocId: documentId,
                        existingData: currentData,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_rounded,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Delete Announcement Permanently',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Clears notice from everyone\'s device logs instantly.',
                ),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  try {
                    final String campus = _sanitizePathSegment(
                      _userAcademicProfile?['campus'] ?? 'MAIN_CAMPUS',
                    );
                    final String college = _sanitizePathSegment(
                      _userAcademicProfile?['college'] ?? 'COPAS',
                    );
                    final String school = _sanitizePathSegment(
                      _userAcademicProfile?['school'] ?? 'SCIT',
                    );
                    final String dept = _sanitizePathSegment(
                      _userAcademicProfile?['department'] ?? 'COMPUTING',
                    );
                    final String course = _sanitizePathSegment(
                      _userAcademicProfile?['course'] ?? 'BSc_IT',
                    );
                    final String rawYear =
                        _userAcademicProfile?['year']?.toString().replaceAll(
                          RegExp(r'[^0-9]'),
                          '',
                        ) ??
                        '1';
                    final String rawSem =
                        _userAcademicProfile?['semester']
                            ?.toString()
                            .replaceAll(RegExp(r'[^0-9]'), '') ??
                        '1';
                    final String year = 'YEAR_$rawYear';
                    final String sem = 'SEM_$rawSem';

                    await FirebaseFirestore.instance
                        .collection('announcements')
                        .doc(campus)
                        .collection(college)
                        .doc(school)
                        .collection(dept)
                        .doc(course)
                        .collection(year)
                        .doc(sem)
                        .collection('notices')
                        .doc(documentId)
                        .delete();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Announcement safely purged from database.",
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Deletion failed: $e"),
                          backgroundColor: theme.colorScheme.error,
                        ),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(bottomSheetContext),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Color _getColorForType(BuildContext context, String type) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case 'General':
        return const Color(0xFF7C4DFF);
      case 'Notes':
        return Colors.blue.shade400;
      case 'Past Paper':
        return Colors.teal.shade400;
      case 'Assignment':
        return colorScheme.secondary;
      case 'CAT':
        return colorScheme.error;
      case 'Class Confirmation':
        return const Color(0xFFFFC107);
      default:
        return colorScheme.onSurface.withOpacity(0.6);
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'General':
        return Icons.campaign_outlined;
      case 'Notes':
        return Icons.book_rounded;
      case 'Past Paper':
        return Icons.history_edu_rounded;
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

  List<InlineSpan> _parseTextWithClickableLinks(
    String text,
    ColorScheme scheme,
  ) {
    final List<InlineSpan> spans = [];
    final RegExp linkExp = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);
    int start = 0;
    final Iterable<RegExpMatch> matches = linkExp.allMatches(text);

    for (final RegExpMatch match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final String urlString = match.group(0)!;
      spans.add(
        TextSpan(
          text: urlString,
          style: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final Uri targetUri = Uri.parse(urlString);
              if (await canLaunchUrl(targetUri)) {
                await launchUrl(
                  targetUri,
                  mode: LaunchMode.externalApplication,
                );
              }
            },
        ),
      );
      start = match.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isProfileLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: _buildShimmerLoading(context),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Announcements", style: theme.textTheme.titleLarge),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      floatingActionButton: _canPost
          ? FloatingActionButton(
              heroTag: 'create_announcement_fab',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateAnnouncementScreen(),
                ),
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
              stream: _announcementsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Error fetching records: ${snapshot.error}"),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return _buildShimmerLoading(context);
                }

                final rawDocs = snapshot.data?.docs ?? [];
                final scopedDocs = _processAndFilterAnnouncements(rawDocs);

                if (scopedDocs.isNotEmpty) {
                  FCMInitializer.scheduleAcademicReminders(rawDocs);
                }

                if (scopedDocs.isEmpty) {
                  return _buildEmptyState(theme, colorScheme);
                }

                final Map<String, List<Color>> calendarMap = {};
                for (var doc in scopedDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final targetTimestamp = data['target_date'] as Timestamp?;
                  if (targetTimestamp != null) {
                    final String dayKey = DateFormat(
                      'yyyy-MM-dd',
                    ).format(targetTimestamp.toDate());
                    final String type = data['type'] ?? 'General';
                    calendarMap
                        .putIfAbsent(dayKey, () => [])
                        .add(_getColorForType(context, type));
                  }
                }

                if (_selectedFilter == 'Calendar' &&
                    _selectedCalendarDay == null) {
                  _selectedCalendarDay = DateTime.now();
                }

                final finalDisplayDocs = scopedDocs.where((doc) {
                  if ((_selectedFilter == 'All' ||
                          _selectedFilter == 'Calendar') &&
                      _selectedCalendarDay != null) {
                    final data = doc.data() as Map<String, dynamic>;
                    final target = data['target_date'] as Timestamp?;
                    if (target == null) return false;
                    return DateFormat('yyyy-MM-dd').format(target.toDate()) ==
                        DateFormat('yyyy-MM-dd').format(_selectedCalendarDay!);
                  }
                  return true;
                }).toList();

                return Column(
                  children: [
                    if (_selectedFilter == 'Calendar')
                      _buildCalendarModule(theme, colorScheme, calendarMap),
                    Expanded(
                      child: finalDisplayDocs.isEmpty
                          ? _buildEmptyState(theme, colorScheme)
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: finalDisplayDocs.length,
                              itemBuilder: (context, index) {
                                final doc = finalDisplayDocs[index];
                                return _buildAnnouncementCard(
                                  context,
                                  doc.id,
                                  doc.data() as Map<String, dynamic>,
                                  theme,
                                  colorScheme,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot> _processAndFilterAnnouncements(
    List<QueryDocumentSnapshot> docs,
  ) {
    final now = DateTime.now();
    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['type'] ?? 'General';
      final targetTimestamp = data['target_date'] as Timestamp?;
      final createdAtTimestamp = data['created_at'] as Timestamp?;

      final DateTime createdDate = createdAtTimestamp?.toDate() ?? now;
      final DateTime targetDate = targetTimestamp?.toDate() ?? now;

      if (type == 'Assignment' || type == 'CAT') {
        if (now.isAfter(targetDate)) return false;
      } else if (type == 'Class Confirmation') {
        if (now.difference(targetDate).inDays >= 1) return false;
      } else if (type == 'Notes' || type == 'Past Paper' || type == 'General') {
        if (now.difference(createdDate).inDays >= 7) return false;
      }

      if (_selectedFilter == 'All' || _selectedFilter == 'Calendar') {
        return true;
      }
      return type == _selectedFilter;
    }).toList();

    filtered.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      final typeA = dataA['type'] ?? '';
      final typeB = dataB['type'] ?? '';
      final targetA = dataA['target_date'] as Timestamp?;
      final targetB = dataB['target_date'] as Timestamp?;
      final createdAtA = dataA['created_at'] as Timestamp?;
      final createdAtB = dataB['created_at'] as Timestamp?;

      const sortTypes = ['Assignment', 'CAT', 'Class Confirmation'];
      if (sortTypes.contains(typeA) && sortTypes.contains(typeB)) {
        if (targetA != null && targetB != null) {
          return targetA.toDate().compareTo(targetB.toDate());
        }
      }
      if (createdAtB != null && createdAtA != null) {
        return createdAtB.compareTo(createdAtA);
      }
      return 0;
    });

    return filtered;
  }

  Widget _buildCalendarModule(
    ThemeData theme,
    ColorScheme colorScheme,
    Map<String, List<Color>> eventMap,
  ) {
    final int daysInMonth = DateTime(
      _focusedCalendarMonth.year,
      _focusedCalendarMonth.month + 1,
      0,
    ).day;
    final int weekdayOffset =
        DateTime(
          _focusedCalendarMonth.year,
          _focusedCalendarMonth.month,
          1,
        ).weekday -
        1;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_focusedCalendarMonth),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 22),
                    onPressed: () => setState(
                      () => _focusedCalendarMonth = DateTime(
                        _focusedCalendarMonth.year,
                        _focusedCalendarMonth.month - 1,
                        1,
                      ),
                    ),
                  ),
                  if (_selectedCalendarDay != null &&
                      _selectedFilter != 'Calendar')
                    TextButton(
                      onPressed: () =>
                          setState(() => _selectedCalendarDay = null),
                      child: Text(
                        'Clear Filter',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 22),
                    onPressed: () => setState(
                      () => _focusedCalendarMonth = DateTime(
                        _focusedCalendarMonth.year,
                        _focusedCalendarMonth.month + 1,
                        1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const Divider(height: 12, thickness: 0.5),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemCount: daysInMonth + weekdayOffset,
            itemBuilder: (context, index) {
              if (index < weekdayOffset) return const SizedBox();
              final int dayNumber = index - weekdayOffset + 1;
              final DateTime day = DateTime(
                _focusedCalendarMonth.year,
                _focusedCalendarMonth.month,
                dayNumber,
              );
              final String dayKey = DateFormat('yyyy-MM-dd').format(day);
              final bool isSelected =
                  _selectedCalendarDay != null &&
                  _selectedCalendarDay!.year == day.year &&
                  _selectedCalendarDay!.month == day.month &&
                  _selectedCalendarDay!.day == day.day;
              final List<Color> dayColors = eventMap[dayKey] ?? [];

              return GestureDetector(
                onTap: () => setState(() => _selectedCalendarDay = day),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer
                        : theme.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (dayColors.isNotEmpty)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: CustomPaint(
                              painter: CalendarDayPiePainter(
                                eventColors: dayColors,
                              ),
                            ),
                          ),
                        ),
                      Text(
                        '$dayNumber',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
            final typeColor = (filter == 'All' || filter == 'Calendar')
                ? colorScheme.primary
                : _getColorForType(context, filter);
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? colorScheme.onPrimary : typeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) => setState(() {
                  _selectedFilter = filter;
                  _selectedCalendarDay = (filter == 'Calendar')
                      ? DateTime.now()
                      : null;
                }),
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

  Widget _buildAnnouncementCard(
    BuildContext context,
    String documentId,
    Map<String, dynamic> item,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final type = item['type'] ?? 'General';
    final color = _getColorForType(context, type);
    final String description = item['description'] ?? '';
    final String? optionalNotes = item['general_notes'];
    final bool hasPicture = item['has_picture'] ?? false;
    final String? imageUrl = item['attachment_url'];

    final Timestamp? dateStamp =
        (item['target_date'] as Timestamp?) ??
        (item['created_at'] as Timestamp?);
    final String cardTopDisplayDate = dateStamp != null
        ? DateFormat('MMM d').format(dateStamp.toDate())
        : '--';
    final String timelineSubtitleDate = dateStamp != null
        ? DateFormat('EEE, MMM d @ h:mm a').format(dateStamp.toDate())
        : '--';

    return GestureDetector(
      onLongPress: _canPost
          ? () => _showAdministrativeOptions(context, documentId, item)
          : null,
      child: Card(
        color: theme.cardColor,
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.4)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 5,
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildTypeBadge(type, color, theme),
                          Text(
                            cardTopDisplayDate,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item['title'] ?? 'No Title',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                            color: colorScheme.onSurface.withOpacity(0.85),
                          ),
                          children: _parseTextWithClickableLinks(
                            description,
                            colorScheme,
                          ),
                        ),
                      ),
                      if (type == 'General' &&
                          hasPicture &&
                          imageUrl != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            cacheHeight: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(),
                          ),
                        ),
                      ],
                      if (type == 'General' &&
                          optionalNotes != null &&
                          optionalNotes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withOpacity(0.2)),
                          ),
                          child: Text(
                            optionalNotes,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                      if (item['target_date'] != null ||
                          type == 'Notes' ||
                          type == 'Past Paper') ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(
                              type == 'Notes' || type == 'Past Paper'
                                  ? Icons.history_toggle_off_rounded
                                  : Icons.event_available_rounded,
                              size: 16,
                              color: color,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              type == 'Notes' || type == 'Past Paper'
                                  ? "Uploaded: $timelineSubtitleDate"
                                  : "Due Date: $timelineSubtitleDate",
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(_getIconForType(type), size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            type.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off_rounded,
            size: 48,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 14),
          Text(
            _selectedFilter == 'Calendar'
                ? "No schedule milestones found for this date."
                : "No announcements found.",
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: cardColor.withOpacity(0.5),
        highlightColor: cardColor.withOpacity(0.2),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(width: 4, height: 80, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 80, height: 16, color: Colors.white),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 6),
                    Container(width: 150, height: 14, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalendarDayPiePainter extends CustomPainter {
  final List<Color> eventColors;
  CalendarDayPiePainter({required this.eventColors});

  @override
  void paint(Canvas canvas, Size size) {
    if (eventColors.isEmpty) return;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final double sweepAngle = (2 * 3.141592653589793) / eventColors.length;

    for (int i = 0; i < eventColors.length; i++) {
      paint.color = eventColors[i];
      canvas.drawArc(
        rect,
        (i * sweepAngle) - (3.141592653589793 / 2),
        sweepAngle * 0.82,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CalendarDayPiePainter oldDelegate) =>
      oldDelegate.eventColors != eventColors;
}
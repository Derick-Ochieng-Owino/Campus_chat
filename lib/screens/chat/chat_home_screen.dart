import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/loading_widget.dart';
import '../chat/user_selection_screen.dart';
import 'chat_screen.dart';

// Key for SharedPreferences caching
const String _CACHE_KEY = 'cached_chat_list';
const String _STATUS_VIEWS_KEY = 'status_views_cache';

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> with AutomaticKeepAliveClientMixin<ChatHomeScreen> {
  @override
  bool get wantKeepAlive => true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentUserId;
  String? _currentUserRole;
  String? _currentUserName;

  // State to hold live stream data
  Stream<QuerySnapshot>? _chatStream;
  Stream<QuerySnapshot>? _statusStream;

  // State to hold cached map data while waiting for the stream
  List<Map<String, dynamic>>? _cachedChatMaps;

  // State for status stories
  Map<String, int> _statusViewCounts = {};
  Map<String, bool> _statusViewedByUser = {};

  // State to hold specific groups the user belongs to (Subdivided chats)
  List<Map<String, dynamic>> _userSpecificGroups = [];
  Map<String, String> _userNameCache = {};
  bool _userNameCachePreloaded = false;

  // Timer for status refresh
  Timer? _statusRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadUserProfileAndCache();
    //_setupStatusRefreshTimer();
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    super.dispose();
  }

  void _setupStatusRefreshTimer() {
    // Refresh status every 5 minutes
    _statusRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) {
        _checkStatusAvailability();
      }
    });
  }

  // Add this method to see what's happening
  void _debugStatusInfo(AsyncSnapshot<QuerySnapshot> statusSnap) {
    debugPrint('=== STATUS DEBUG INFO ===');
    debugPrint('Connection state: ${statusSnap.connectionState}');
    debugPrint('Has data: ${statusSnap.hasData}');
    debugPrint('Has error: ${statusSnap.hasError}');
    if (statusSnap.hasError) {
      debugPrint('Error: ${statusSnap.error}');
    }
    if (statusSnap.hasData) {
      debugPrint('Number of documents: ${statusSnap.data!.docs.length}');
      for (var doc in statusSnap.data!.docs) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('Status ${doc.id}: ${data['content']}');
        debugPrint('  - expiresAt: ${data['expiresAt']}');
        debugPrint('  - reachLimit: ${data['reachLimit']}');
        debugPrint('  - type: ${data['type']}');
      }
    }
    debugPrint('=== END DEBUG INFO ===');
  }

  // --- CACHING & DATA LOADING ---
  Future<void> _loadUserProfileAndCache() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('No user logged in');
      return;
    }

    _currentUserId = user.uid;
    debugPrint('Loading profile for user: $_currentUserId');

    try {
      // 1. Load User Data
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        debugPrint('User document does not exist');
        return;
      }

      final data = doc.data();
      if (data == null) {
        debugPrint('User data is null');
        return;
      }

      final userData = data as Map<String, dynamic>;

      setState(() {
        _currentUserRole = userData['role'] as String?;
        _currentUserName = userData['name'] as String?;
      });

      debugPrint('User role: $_currentUserRole, name: $_currentUserName');

      // 2. Load Cache Immediately
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_CACHE_KEY);
      if (cachedJson != null) {
        try {
          final List<dynamic> list = jsonDecode(cachedJson);
          setState(() {
            _cachedChatMaps = list.cast<Map<String, dynamic>>();
          });
          debugPrint('Loaded ${_cachedChatMaps!.length} cached chats');
        } catch (e) {
          debugPrint("Error loading chat cache: $e");
        }
      }

      // 3. Setup General Chat, Load Groups, and Initialize Live Stream
      await _ensureGeneralCourseChat(userData);
      await _loadUserSpecificGroups(userData['groupId'] as String?, userData['subdivision'] as String?);

      // 4. Setup streams
      _setupStream(); // For chats
      _setupStatusStream(); // For statuses

      // 5. Setup timer
      _setupStatusRefreshTimer();

      // 6. Load status view counts from cache
      await _loadStatusViewCounts();

    } catch (e) {
      debugPrint("Error in _loadUserProfileAndCache: $e");
    }
  }

  // FIXED: Renamed from _setupChatStream to _setupStream
  void _setupStream() {
    final isAdmin = _currentUserRole == 'admin';
    Query query = _firestore.collection('chats');

    if (isAdmin) {
      query = query.where('type', whereIn: ['group', 'general']).orderBy('lastMessageAt', descending: true);
    } else {
      query = query.where('participants', arrayContains: _currentUserId).orderBy('lastMessageAt', descending: true);
    }

    setState(() {
      _chatStream = query.snapshots().map((snapshot) {
        // Asynchronously save the fresh data to cache
        _saveCache(snapshot.docs);
        return snapshot;
      });
    });
  }

  void _setupStatusStream() {
    debugPrint('Setting up status stream...');

    if (_currentUserId == null) {
      debugPrint('Cannot setup status stream: currentUserId is null');
      return;
    }

    try {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      debugPrint('Current time: $now');
      debugPrint('Looking for statuses expiring after: $now');

      // Simple query to get all active statuses
      Query query = _firestore
          .collection('statuses')
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('expiresAt', descending: true);

      setState(() {
        _statusStream = query.snapshots().handleError((error) {
          debugPrint('Error in status stream: $error');
        });
      });

      debugPrint('Status stream setup complete');

      // Test the query
      query.get().then((snapshot) {
        debugPrint('Test query found ${snapshot.docs.length} statuses');
        for (var doc in snapshot.docs) {
          // debugPrint('- ${doc.id}: ${doc.data()['content']}');
        }
      }).catchError((error) {
        debugPrint('Test query error: $error');
      });

    } catch (e) {
      debugPrint('Error setting up status stream: $e');
    }
  }

  Future<void> _loadStatusViewCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final viewsJson = prefs.getString(_STATUS_VIEWS_KEY);

    if (viewsJson != null) {
      try {
        final Map<String, dynamic> viewsMap = jsonDecode(viewsJson);
        setState(() {
          _statusViewedByUser = Map<String, bool>.from(viewsMap);
        });
      } catch (e) {
        debugPrint("Error loading status views cache: $e");
      }
    }
  }

  Future<void> _saveStatusViewsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_STATUS_VIEWS_KEY, jsonEncode(_statusViewedByUser));
  }

  Future<void> _incrementStatusView(String statusId, String userId) async {
    // Check if user already viewed this status
    if (_statusViewedByUser.containsKey('${statusId}_$userId')) {
      return;
    }

    final statusRef = _firestore.collection('statuses').doc(statusId);
    final viewersRef = statusRef.collection('viewers');

    // Create a transaction to safely increment count
    await _firestore.runTransaction((transaction) async {
      // Get current count
      final countDoc = await transaction.get(viewersRef.doc('count'));
      final currentCount = countDoc.data()?['count'] as int? ?? 0;

      // Update count
      transaction.set(
        viewersRef.doc('count'),
        {'count': currentCount + 1},
        SetOptions(merge: true),
      );

      // Add user to viewers list
      transaction.set(
        viewersRef.doc(userId),
        {'viewedAt': FieldValue.serverTimestamp()},
      );
    });

    // Update cache
    _statusViewedByUser['${statusId}_$userId'] = true;
    await _saveStatusViewsCache();

    // Update local count
    final currentCount = _statusViewCounts[statusId] ?? 0;
    _statusViewCounts[statusId] = currentCount + 1;
  }

  Future<void> _checkStatusAvailability() async {
    if (_statusStream == null) return;

    // This will trigger the stream to re-evaluate reach limits
    _setupStatusStream();
  }

  Future<void> _saveCache(List<QueryDocumentSnapshot> docs) async {
    final prefs = await SharedPreferences.getInstance();

    final serializableList = docs.map((doc) {
      final dataMap = doc.data() as Map<String, dynamic>? ?? {};

      // Convert all Timestamp fields to ISO strings
      final cleanedMap = dataMap.map((key, value) {
        if (value is Timestamp) {
          return MapEntry(key, value.toDate().toIso8601String());
        }
        return MapEntry(key, value);
      });

      return {'id': doc.id, ...cleanedMap};
    }).toList();

    await prefs.setString(_CACHE_KEY, jsonEncode(serializableList));
  }

  // --- GROUP LOGIC (Unchanged for functional logic) ---

  Future<void> _ensureGeneralCourseChat(Map<String, dynamic> user) async {
    final course = user['course'] ?? 'default';
    final year = user['year_key'] ?? 'year1';
    final semester = user['semester_key'] ?? 'semester1';

    final chatId = 'course_${course}_${year}_${semester}';

    final ref = _firestore.collection('chats').doc(chatId);
    final doc = await ref.get();

    if (!doc.exists) {
      await ref.set({
        'name': 'General Course Chat',
        'type': 'general',
        'participants': [_currentUserId],
        'lastMessage': "Welcome to the course chat!",
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } else {
      if (!(doc.data()?['participants'] ?? []).contains(_currentUserId)) {
        await ref.update({
          'participants': FieldValue.arrayUnion([_currentUserId])
        });
      }
    }
  }

  void _preloadUserNames(List<Map<String, dynamic>> chatDataList) {
    final unknownUids = <String>{};

    for (var chat in chatDataList) {
      final type = chat['type'] ?? 'dm';
      if (type != 'dm') continue;

      final participants = (chat['participants'] ?? []).cast<String>();
      final otherUid = participants.firstWhere((id) => id != _currentUserId, orElse: () => '');
      if (otherUid.isNotEmpty && !_userNameCache.containsKey(otherUid)) {
        unknownUids.add(otherUid);
      }
    }

    if (unknownUids.isEmpty) return;

    for (var uid in unknownUids) {
      _firestore.collection('users').doc(uid).get().then((doc) {
        if (doc.exists) {
          final name = (doc.data()?['nickname'] ?? doc.data()?['name'] ?? uid) as String;
          _userNameCache[uid] = name;
          if (mounted) setState(() {}); // rebuild once the name is fetched
        }
      });
    }
  }

  Future<void> _loadUserSpecificGroups(String? groupId, String? subdivision) async {
    if (groupId == null) {
      setState(() => _userSpecificGroups = []);
      return;
    }

    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final groupName = groupDoc.data()?['name'] ?? 'Group';

      final List<Map<String, dynamic>> chats = [];
      final Map<String, dynamic>? groupData = groupDoc.data();

      if (groupData == null) {
        setState(() => _userSpecificGroups = []);
        return;
      }

      // --- SAFE EXTRACTION OF UIDs ---
      // Safely get list A or an empty list, then extract UIDs and cast.
      final List<Map<String, dynamic>> membersA =
          (groupData['A'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      final List<Map<String, dynamic>> membersB =
          (groupData['B'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      final List<String> uidsA = membersA.map((m) => m['uid'] as String).toList();
      final List<String> uidsB = membersB.map((m) => m['uid'] as String).toList();

      // 🎯 FIX: Use the null-aware spread operator on the list itself.
      final List<String> allGroupUids = [
        ...uidsA,
        ...uidsB,
      ];
      // -------------------------------

      // 1. Group General Chat
      chats.add({
        'name': '$groupName (General)',
        'type': 'group',
        'chatId': '${groupId}_general',
        'participants': allGroupUids, // Already a List<String>
      });

      // 2. Subdivision A Chat (if user is in A or is admin)
      if (subdivision == 'A' || _currentUserRole == 'admin') {
        chats.add({
          'name': '$groupName (A)',
          'type': 'group',
          'chatId': '${groupId}_A',
          'subdivision': 'A',
          'participants': uidsA, // Use the extracted List<String>
        });
      }

      // 3. Subdivision B Chat (if user is in B or is admin)
      if (subdivision == 'B' || _currentUserRole == 'admin') {
        chats.add({
          'name': '$groupName (B)',
          'type': 'group',
          'chatId': '${groupId}_B',
          'subdivision': 'B',
          'participants': uidsB, // Use the extracted List<String>
        });
      }

      setState(() {
        _userSpecificGroups = chats;
      });

    } catch (e) {
      debugPrint("Error loading specific groups: $e");
      setState(() => _userSpecificGroups = []);
    }
  }

  // --- STATUS/STORY FUNCTIONS ---

  void _viewStatus(BuildContext context, Map<String, dynamic> status) async {
    final statusId = status['id'];
    final content = status['content'] ?? '';
    final mediaUrl = status['mediaUrl'] as String?;
    final reachLimit = status['reachLimit'] as int?;
    final currentViews = _statusViewCounts[statusId] ?? 0;

    // Check if reached limit
    if (reachLimit != null && currentViews >= reachLimit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('This ad has reached its maximum views'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Show status viewer
    showDialog(
      context: context,
      builder: (context) => _StatusViewerDialog( // FIXED: Changed from StatusViewerDialog to _StatusViewerDialog
        status: status,
        mediaUrl: mediaUrl,
        content: content,
        isAdmin: _currentUserRole == 'admin',
        viewCount: currentViews,
        reachLimit: reachLimit,
        onViewComplete: () async {
          // Mark as viewed and increment count
          if (_currentUserId != null) {
            await _incrementStatusView(statusId, _currentUserId!);
            if (mounted) setState(() {});
          }
        },
      ),
    );
  }

  Widget _buildStatusItem(BuildContext context, Map<String, dynamic> status) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusId = status['id'];
    final content = status['content'] ?? '';
    final mediaUrl = status['mediaUrl'] as String?;
    final reachLimit = status['reachLimit'] as int?;
    final currentViews = _statusViewCounts[statusId] ?? 0;
    final hasViewed = _statusViewedByUser.containsKey('${statusId}_$_currentUserId');
    final isExpired = (status['expiresAt'] as Timestamp?)?.toDate().isBefore(DateTime.now()) ?? false;

    // Don't show expired statuses
    if (isExpired) return const SizedBox();

    // Don't show if reach limit exceeded
    if (reachLimit != null && currentViews >= reachLimit) return const SizedBox();

    return GestureDetector(
      onTap: () => _viewStatus(context, status),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            // Status circle
            Stack(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasViewed
                        ? LinearGradient(
                      colors: [Colors.grey.shade400, Colors.grey.shade600],
                    )
                        : LinearGradient(
                      colors: [colorScheme.primary, colorScheme.secondary],
                    ),
                    border: Border.all(
                      color: hasViewed ? Colors.grey : colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: mediaUrl != null
                      ? ClipOval(
                    child: Image.network(
                      mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image,
                          color: hasViewed ? Colors.grey : colorScheme.onPrimary,
                          size: 30,
                        );
                      },
                    ),
                  )
                      : Icon(
                    Icons.campaign,
                    color: hasViewed ? Colors.grey : colorScheme.onPrimary,
                    size: 30,
                  ),
                ),
                if (reachLimit != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${reachLimit - currentViews}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              content.length > 15 ? '${content.substring(0, 15)}...' : content,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall!.copyWith(
                color: hasViewed ? Colors.grey : colorScheme.onSurface,
                fontWeight: hasViewed ? FontWeight.normal : FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_currentUserId == null || _chatStream == null) {
      return Center(child: AppLogoLoadingWidget(size: 80));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Alma Mater Chats"),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          if (_currentUserRole == 'admin')
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Create Status/Ad',
              onPressed: () => _showCreateStatusDialog(context),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatStream,
        builder: (context, snap) {
          // Determine the data source: Live docs if available, otherwise cached maps
          List<Map<String, dynamic>> chatDataList;

          if (snap.hasData) {
            // Live data: Convert docs to maps for consistency
            chatDataList = snap.data!.docs.map((doc) {
              return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
            }).toList();
          } else if (_cachedChatMaps != null) {
            // Cache fallback
            chatDataList = _cachedChatMaps!;
          } else {
            // Initial loading without cache
            chatDataList = [];
          }

          if (chatDataList.isNotEmpty && !_userNameCachePreloaded) {
            _userNameCachePreloaded = true;
            _preloadUserNames(chatDataList);
          }

          return Column(
            children: [
              // Status/Stories Section
              StreamBuilder<QuerySnapshot>(
                stream: _statusStream,
                builder: (context, statusSnap) {
                  _debugStatusInfo(statusSnap);
                  if (statusSnap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 100);
                  }

                  if (statusSnap.hasData && statusSnap.data!.docs.isNotEmpty) {
                    // Fetch view counts for each status
                    final statuses = statusSnap.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return {'id': doc.id, ...data};
                    }).toList();

                    return Container(
                      height: 120,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Text(
                                  "Status & Ads",
                                  style: theme.textTheme.titleMedium!.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "${statuses.length} active",
                                    style: theme.textTheme.bodySmall!.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: statuses.length,
                              itemBuilder: (context, index) {
                                return _buildStatusItem(context, statuses[index]);
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return const SizedBox(height: 16);
                },
              ),

              Divider(color: theme.dividerColor, height: 1),

              // Chats List
              Expanded(
                child: (snap.connectionState == ConnectionState.waiting && chatDataList.isEmpty)
                    ? Center(child: AppLogoLoadingWidget(size: 80))
                    : (chatDataList.isEmpty && _userSpecificGroups.isEmpty)
                    ? Center(child: Text("No chats available", style: theme.textTheme.bodyMedium))
                    : ListView(
                  children: [
                    // 1. General/DM Chats
                    _buildSectionHeader(context, "Direct Messages & Course Chat", colorScheme.primary),
                    ...chatDataList.map((chatMap) => _buildChatEntry(context, chatMap)).toList(),

                    // 2. Specific Group Subdivisions
                    if (_userSpecificGroups.isNotEmpty) ...[
                      Divider(color: theme.dividerColor, height: 20),
                      _buildSectionHeader(context, "Your Group Subdivisions", colorScheme.secondary),
                      ..._userSpecificGroups.map((groupData) => _buildSpecificGroupTile(context, groupData)).toList(),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'chatDmButton',
        backgroundColor: colorScheme.primary,
        onPressed: () => _startNewDm(context),
        child: Icon(Icons.message_rounded, color: colorScheme.onPrimary),
      ),
    );
  }

  void _showCreateStatusDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String content = '';
    String mediaUrl = '';
    int? reachLimit;
    int durationHours = 24;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Status/Ad'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Content/Message',
                  hintText: 'Enter your ad message here...',
                ),
                onChanged: (value) => content = value,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Media URL (optional)',
                  hintText: 'https://example.com/image.jpg',
                ),
                onChanged: (value) => mediaUrl = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Reach Limit (optional)',
                  hintText: 'e.g., 300 for first 300 users',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    reachLimit = int.tryParse(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Duration: ', style: theme.textTheme.bodyMedium),
                  Expanded(
                    child: Slider(
                      value: durationHours.toDouble(),
                      min: 1,
                      max: 168, // 7 days
                      divisions: 167,
                      label: '$durationHours hours',
                      onChanged: (value) {
                        durationHours = value.toInt();
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                  Text('${durationHours}h', style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              if (reachLimit != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Ad will be shown to first $reachLimit users only',
                    style: theme.textTheme.bodySmall!.copyWith(color: Colors.orange),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (content.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter content')),
                );
                return;
              }

              final expiresAt = DateTime.now().add(Duration(hours: durationHours));

              await _firestore.collection('statuses').add({
                'content': content,
                'mediaUrl': mediaUrl.isNotEmpty ? mediaUrl : null,
                'reachLimit': reachLimit,
                'createdBy': _currentUserId,
                'createdByName': _currentUserName,
                'createdAt': FieldValue.serverTimestamp(),
                'expiresAt': Timestamp.fromDate(expiresAt),
                'type': 'ad',
              });

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Status/Ad created successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
            ),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium!.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Builds a tile for chats fetched directly from the 'chats' stream/cache
  Widget _buildChatEntry(BuildContext context, Map<String, dynamic> chat) {
    final chatId = chat['id'] as String? ?? 'tempId';
    final type = chat['type'] ?? 'dm';
    final participants = (chat['participants'] ?? []).cast<String>();
    final subtitle = chat['lastMessage'] ?? "No messages";

    if (type == 'dm') {
      final otherUid = participants.firstWhere((id) => id != _currentUserId, orElse: () => '');
      if (otherUid.isEmpty) return const SizedBox();

      final title = _userNameCache[otherUid] ?? otherUid; // Use cache or fallback UID

      return _chatTile(
        context,
        chatId: chatId,
        title: title,
        subtitle: subtitle,
        type: type,
        otherUserId: otherUid,
      );
    }

    // Group/General Chat
    final name = chat['name'] ?? "Chat";
    return _chatTile(
      context,
      chatId: chatId,
      title: name,
      subtitle: subtitle,
      type: type,
    );
  }

  // Builds a tile for the specific A/B/General chats from the custom loaded list
  Widget _buildSpecificGroupTile(BuildContext context, Map<String, dynamic> groupData) {
    final theme = Theme.of(context);

    // Note: Since these chats are constructed locally, they won't have live 'lastMessage'

    return _chatTile(
      context,
      chatId: groupData['chatId'] as String,
      title: groupData['name'] as String,
      subtitle: "Tap to chat in ${groupData['subdivision'] ?? 'General'} subdivision.",
      type: 'group',
    );
  }

  // --- Base Chat Tile UI (Themed) ---
  Widget _chatTile(
      BuildContext context, {
        required String chatId,
        required String title,
        required String subtitle,
        required String type,
        String? otherUserId,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = _getIconForChatType(type);
    final isGroup = type != 'dm';

    return Card(
      color: theme.cardColor,
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isGroup ? colorScheme.secondary.withOpacity(0.8) : colorScheme.primary.withOpacity(0.7),
          child: Icon(icon, color: colorScheme.onPrimary),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chatId,
                chatName: title,
                otherUserId: otherUserId,
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getIconForChatType(String type) {
    switch (type) {
      case 'group':
        return Icons.group_rounded;
      case 'general':
        return Icons.public_rounded;
      case 'dm':
      default:
        return Icons.person_rounded;
    }
  }

  String _dmId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  void _startNewDm(BuildContext context) {
    if (_currentUserId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
    ).then((uid) async {
      final otherUid = uid as String?;
      if (otherUid == null || otherUid == _currentUserId) return;

      final chatId = _dmId(_currentUserId!, otherUid);
      final ref = _firestore.collection('chats').doc(chatId);

      final doc = await ref.get();
      if (!doc.exists) {
        await ref.set({
          'type': 'dm',
          'participants': [_currentUserId, otherUid],
          'lastMessage': "Chat created by $_currentUserName",
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserId: otherUid,
          ),
        ),
      );
    });
  }
}

// FIXED: Made this a private class (prefixed with underscore)
// and removed the abstract class instantiation issue
class _StatusViewerDialog extends StatefulWidget {
  final Map<String, dynamic> status;
  final String? mediaUrl;
  final String content;
  final bool isAdmin;
  final int viewCount;
  final int? reachLimit;
  final VoidCallback onViewComplete;

  const _StatusViewerDialog({
    required this.status,
    required this.mediaUrl,
    required this.content,
    required this.isAdmin,
    required this.viewCount,
    required this.reachLimit,
    required this.onViewComplete,
  });

  @override
  State<_StatusViewerDialog> createState() => __StatusViewerDialogState();
}

class __StatusViewerDialogState extends State<_StatusViewerDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _viewCompleted = false;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..forward().whenComplete(() {
      if (!_viewCompleted) {
        _viewCompleted = true;
        widget.onViewComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final createdAt = (widget.status['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final createdByName = widget.status['createdByName'] as String? ?? 'Admin';

    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.9),
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          // Background content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar
              LinearProgressIndicator(
                value: _controller.value,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),

              // Media or icon
              Expanded(
                child: Center(
                  child: widget.mediaUrl != null && widget.mediaUrl!.isNotEmpty
                      ? Image.network(
                    widget.mediaUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.broken_image,
                        size: 100,
                        color: colorScheme.onSurface,
                      );
                    },
                  )
                      : Icon(
                    Icons.campaign,
                    size: 100,
                    color: colorScheme.primary,
                  ),
                ),
              ),

              // Content
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colorScheme.primary,
                          child: Text(
                            createdByName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                createdByName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.reachLimit != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Text(
                              '${widget.viewCount}/${widget.reachLimit} views',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),

                    if (_showDetails && widget.isAdmin)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ad Analytics:',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Views: ${widget.viewCount}',
                              style: TextStyle(color: Colors.grey[300]),
                            ),
                            if (widget.reachLimit != null)
                              Text(
                                'Remaining views: ${widget.reachLimit! - widget.viewCount}',
                                style: TextStyle(color: Colors.grey[300]),
                              ),
                            Text(
                              'Created: ${createdAt.day}/${createdAt.month}/${createdAt.year}',
                              style: TextStyle(color: Colors.grey[300]),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Close button
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),

          // Details toggle for admin
          if (widget.isAdmin)
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                onPressed: () => setState(() => _showDetails = !_showDetails),
                icon: Icon(
                  _showDetails ? Icons.info : Icons.info_outline,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
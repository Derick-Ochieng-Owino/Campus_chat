import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/loading_widget.dart';
import '../chat/user_selection_screen.dart';
import 'chat_screen.dart';

// Key for SharedPreferences caching
const String _CACHE_KEY = 'cached_chat_list';

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

  // State to hold cached map data while waiting for the stream
  List<Map<String, dynamic>>? _cachedChatMaps;

  // State to hold specific groups the user belongs to (Subdivided chats)
  List<Map<String, dynamic>> _userSpecificGroups = [];
  Map<String, String> _userNameCache = {};
  bool _userNameCachePreloaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfileAndCache();
  }

  // --- CACHING & DATA LOADING ---
  Future<void> _loadUserProfileAndCache() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _currentUserId = user.uid;

    // 1. Load User Data
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();

    if (data == null) return;

    // 🎯 FIX: Explicitly cast data to Map<String, dynamic> and use correctly
    final userData = data as Map<String, dynamic>;

    setState(() {
      _currentUserRole = userData['role'] as String?;
      _currentUserName = userData['name'] as String?;
    });

    // 2. Load Cache Immediately
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_CACHE_KEY);
    if (cachedJson != null) {
      try {
        final List<dynamic> list = jsonDecode(cachedJson);
        setState(() {
          // Store raw Maps directly
          _cachedChatMaps = list.cast<Map<String, dynamic>>();
        });
      } catch (e) {
        debugPrint("Error loading chat cache: $e");
      }
    }

    // 3. Setup General Chat, Load Groups, and Initialize Live Stream
    await _ensureGeneralCourseChat(userData);
    await _loadUserSpecificGroups(userData['groupId'] as String?, userData['subdivision'] as String?);
    _setupChatStream();
  }

  // Set up the Firestore stream and listener to update the cache
  void _setupChatStream() {
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


  // --- UI BUILDING & THEME CONSISTENCY ---

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
        title: const Text("Campus Chats"),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
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

          if (snap.connectionState == ConnectionState.waiting && chatDataList.isEmpty) {
            return Center(child: AppLogoLoadingWidget(size: 80));
          }

          if (chatDataList.isEmpty && _userSpecificGroups.isEmpty) {
            return Center(child: Text("No chats available", style: theme.textTheme.bodyMedium));
          }

          return ListView(
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
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/loading_widget.dart';
import '../chat/user_selection_screen.dart';
import 'chat_screen.dart';

// Cache keys
const String _CHAT_CACHE_KEY = 'cached_chats_v2';

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen>
    with AutomaticKeepAliveClientMixin<ChatHomeScreen>, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserCourse;
  late String _currentYear;
  String? _currentSemester;

  // Chat data
  List<ChatItem> _allChats = [];
  List<ChatItem> _filteredChats = [];
  StreamSubscription? _chatSubscription;

  // Search
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<ChatItem> _searchResults = [];

  // User cache
  Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshChats();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _loadUserData();
    await _loadCachedChats();
    _setupChatStream();
    _createOrJoinRequiredGroups();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _currentUserId = user.uid;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _currentUserName = data['name'] ?? data['nickname'] ?? 'User';
        _currentUserCourse = data['course'];
        _currentYear= data['year'];
        _currentSemester = data['semester'];
      });
    }
  }

  Future<void> _loadCachedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_CHAT_CACHE_KEY);

    if (cachedJson != null) {
      try {
        final List<dynamic> list = jsonDecode(cachedJson);
        final cachedChats = list.map((item) => ChatItem.fromJson(item)).toList();
        setState(() {
          _allChats = cachedChats;
          _filteredChats = _sortAndFilterChats(cachedChats);
        });
      } catch (e) {
        debugPrint('Error loading cached chats: $e');
      }
    }
  }

  Future<void> _saveChatsToCache(List<ChatItem> chats) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = chats.map((chat) => chat.toJson()).toList();
    await prefs.setString(_CHAT_CACHE_KEY, jsonEncode(jsonList));
  }

  void _setupChatStream() {
    if (_currentUserId == null) return;

    _chatSubscription?.cancel();

    // Query for chats where user is a participant
    final query = _firestore.collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('lastMessageTime', descending: true);

    _chatSubscription = query.snapshots().listen((snapshot) {
      _processChatUpdates(snapshot.docs);
    }, onError: (error) {
      debugPrint('Chat stream error: $error');
    });
  }

  void _processChatUpdates(List<QueryDocumentSnapshot> docs) {
    final updatedChats = <ChatItem>[];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final chat = ChatItem.fromFirestore(doc.id, data);
      updatedChats.add(chat);

      // Update user cache for DMs
      if (chat.type == ChatType.dm) {
        final otherUserId = chat.participants
            .firstWhere((id) => id != _currentUserId, orElse: () => '');
        if (otherUserId.isNotEmpty && !_userNameCache.containsKey(otherUserId)) {
          _fetchUserName(otherUserId);
        }
      }
    }

    // Merge with existing chats (for pinned chats that might not be in stream)
    final existingChatIds = updatedChats.map((c) => c.id).toSet();
    final preservedChats = _allChats.where((c) => !existingChatIds.contains(c.id)).toList();

    setState(() {
      _allChats = [...updatedChats, ...preservedChats];
      _filteredChats = _sortAndFilterChats(_allChats);
    });

    _saveChatsToCache(_allChats);
  }

  Future<void> _fetchUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) return;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final name = data['nickname'] ?? data['name'] ?? 'Unknown';
        setState(() {
          _userNameCache[userId] = name;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
    }
  }

  Future<void> _createOrJoinRequiredGroups() async {
    if (_currentUserId == null || _currentUserCourse == null) return;

    // 1. General System Chat (for all users)
    await _ensureGroupChat(
      id: 'general_system_chat',
      name: '🌟 Campus Announcements',
      description: 'General announcements for all users',
      type: ChatType.system,
      isPinned: true,
    );

    // 2. Year & Semester Chat (for users in same year/semester)
    if (_currentYear != null && _currentSemester != null && _currentUserCourse != null) {
      // Format: BIT 2.1 or Bsc IT 2.1
      final courseDisplay = _currentUserCourse!;
      final yearSemDisplay = '$courseDisplay ${_currentYear}.${_currentSemester}';

      await _ensureGroupChat(
        id: 'year_${_currentYear}_sem_${_currentSemester}_chat',
        name: '📚 $yearSemDisplay',
        description: 'Group for $yearSemDisplay students',
        type: ChatType.yearGroup,
        isPinned: true,
        filters: {
          'year': _currentYear,
          'semester': _currentSemester,
          'course': _currentUserCourse,
        },
      );
    }


    // 3. Course Chat (for users in same course)
    await _ensureGroupChat(
      id: 'course_${_currentUserCourse}_chat',
      name: '🎓 $_currentUserCourse Course',
      description: 'Group for $_currentUserCourse students',
      type: ChatType.courseGroup,
      filters: {
        'course': _currentUserCourse,
      },
    );
  }

  Future<void> _ensureGroupChat({
    required String id,
    required String name,
    required String description,
    required ChatType type,
    bool isPinned = false,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final chatRef = _firestore.collection('chats').doc(id);
      final doc = await chatRef.get();

      if (!doc.exists) {
        // Create new group chat
        await chatRef.set({
          'name': name,
          'description': description,
          'type': type.name,
          'participants': [_currentUserId],
          'lastMessage': 'Welcome to $name!',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'filters': filters,
          'isPinned': isPinned,
        });
      } else {
        // Add user to existing chat if not already a participant
        final participants = List<String>.from(doc.data()?['participants'] ?? []);
        if (!participants.contains(_currentUserId)) {
          await chatRef.update({
            'participants': FieldValue.arrayUnion([_currentUserId]),
          });
        }

        // Ensure pin status
        if (isPinned && (doc.data()?['isPinned'] != true)) {
          await chatRef.update({'isPinned': true});
        }
      }
    } catch (e) {
      debugPrint('Error ensuring group chat: $e');
    }
  }

  List<ChatItem> _sortAndFilterChats(List<ChatItem> chats) {
    // Separate pinned and unpinned chats
    final pinned = chats.where((c) => c.isPinned).toList();
    final unpinned = chats.where((c) => !c.isPinned).toList();

    // Sort by last message time (newest first)
    pinned.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    unpinned.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    return [...pinned, ...unpinned];
  }

  void _refreshChats() {
    _setupChatStream();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchResults.clear();
      }
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    final results = _allChats.where((chat) {
      final searchText = query.toLowerCase();

      // Search in chat name
      if (chat.name.toLowerCase().contains(searchText)) return true;

      // Search in last message
      if (chat.lastMessage.toLowerCase().contains(searchText)) return true;

      // For DMs, search in cached user names
      if (chat.type == ChatType.dm) {
        final otherUserId = chat.participants
            .firstWhere((id) => id != _currentUserId, orElse: () => '');
        final cachedName = _userNameCache[otherUserId]?.toLowerCase() ?? '';
        return cachedName.contains(searchText);
      }

      return false;
    }).toList();

    setState(() {
      _searchResults = results;
    });
  }

  void _togglePinChat(ChatItem chat) {
    setState(() {
      final index = _allChats.indexWhere((c) => c.id == chat.id);
      if (index != -1) {
        _allChats[index] = chat.copyWith(isPinned: !chat.isPinned);
        _filteredChats = _sortAndFilterChats(_allChats);

        // Update in Firestore
        _firestore.collection('chats').doc(chat.id).update({
          'isPinned': !chat.isPinned,
        });

        _saveChatsToCache(_allChats);
      }
    });
  }

  Future<void> _startNewChat(BuildContext context) async {
    if (_currentUserId == null || _currentUserCourse == null) return;

    // Only allow chatting with students in same course
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserSelectionScreen(
        ),
      ),
    ).then((selectedUserId) async {
      if (selectedUserId == null || selectedUserId.isEmpty) return;

      // Create DM chat
      final participants = [_currentUserId!, selectedUserId]..sort();
      final chatId = participants.join('_');

      final chatRef = _firestore.collection('chats').doc(chatId);
      final doc = await chatRef.get();

      if (!doc.exists) {
        await chatRef.set({
          'type': ChatType.dm.name,
          'participants': participants,
          'lastMessage': 'Chat started',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'isPinned': false,
        });
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserId: selectedUserId,
          ),
        ),
      );
    });
  }

  Widget _buildChatListItem(ChatItem chat) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String displayName = chat.name;
    String? subtitle = chat.lastMessage;
    int? unreadCount = chat.unreadCount;

    // For DMs, get the other user's name
    if (chat.type == ChatType.dm) {
      final otherUserId = chat.participants
          .firstWhere((id) => id != _currentUserId, orElse: () => '');
      displayName = _userNameCache[otherUserId] ?? 'Unknown User';
    }

    return Dismissible(
      key: Key(chat.id),
      direction: DismissDirection.horizontal,
      background: Container(
        color: colorScheme.primary.withOpacity(0.1),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(
          chat.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
          color: colorScheme.primary,
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red.withOpacity(0.1),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          _togglePinChat(chat);
        } else {
          // Archive/delete chat (implement as needed)
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: chat.id,
                  otherUserId: chat.type == ChatType.dm
                      ? chat.participants.firstWhere((id) => id != _currentUserId, orElse: () => '')
                      : null,
                ),
              ),
            );
          },
          onLongPress: () {
            _showChatOptions(context, chat);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                _buildChatAvatar(chat, colorScheme),
                const SizedBox(width: 16),

                // Chat info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (chat.isPinned)
                            Icon(Icons.push_pin, size: 14, color: theme.disabledColor),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(chat.lastMessageTime),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.disabledColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount != null && unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatAvatar(ChatItem chat, ColorScheme colorScheme) {
    final isGroup = chat.type != ChatType.dm;

    if (isGroup) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: _getChatColor(chat.type).withOpacity(0.1),
        child: Icon(
          _getChatIcon(chat.type),
          color: _getChatColor(chat.type),
          size: 24,
        ),
      );
    } else {
      // For DMs, show user avatar
      final otherUserId = chat.participants
          .firstWhere((id) => id != _currentUserId, orElse: () => '');
      final userName = _userNameCache[otherUserId] ?? '';
      final initials = userName.isNotEmpty
          ? userName.substring(0, 1).toUpperCase()
          : '?';

      return CircleAvatar(
        radius: 24,
        backgroundColor: colorScheme.primary.withOpacity(0.1),
        child: Text(
          initials,
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    }
  }

  Color _getChatColor(ChatType type) {
    final theme = Theme.of(context);
    switch (type) {
      case ChatType.system:
        return Colors.amber;
      case ChatType.yearGroup:
        return Colors.green;
      case ChatType.courseGroup:
        return Colors.blue;
      case ChatType.group:
        return Colors.purple;
      case ChatType.dm:
        return theme.colorScheme.primary;
    }
  }

  IconData _getChatIcon(ChatType type) {
    switch (type) {
      case ChatType.system:
        return Icons.campaign;
      case ChatType.yearGroup:
        return Icons.school;
      case ChatType.courseGroup:
        return Icons.group;
      case ChatType.group:
        return Icons.forum;
      case ChatType.dm:
        return Icons.person;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(time).inDays < 7) {
      return _getWeekday(time.weekday);
    } else {
      return '${time.day}/${time.month}/${time.year.toString().substring(2)}';
    }
  }

  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  void _showChatOptions(BuildContext context, ChatItem chat) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  chat.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  chat.isPinned ? 'Unpin chat' : 'Pin chat',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _togglePinChat(chat);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_none, color: Colors.grey),
                title: Text(
                  'Mute notifications',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Implement mute functionality
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined, color: Colors.grey),
                title: Text(
                  'Archive chat',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Implement archive functionality
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  'Delete chat',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Implement delete functionality
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isSearching) {
      return AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _toggleSearch,
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search chats...',
            border: InputBorder.none,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: theme.disabledColor,
            ),
          ),
          style: theme.textTheme.bodyLarge,
          onChanged: _performSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
            ),
        ],
      );
    }

    return AppBar(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      title: Text(
        'Chats',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _toggleSearch,
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            _showSettingsMenu();
          },
        ),
      ],
    );
  }

  void _showSettingsMenu() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.light_mode),
                title: const Text('Theme'),
                trailing: DropdownButton<ThemeMode>(
                  value: Theme.of(context).brightness == Brightness.dark
                      ? ThemeMode.dark
                      : ThemeMode.light,
                  onChanged: (newMode) {
                    // This would need to be connected to your ThemeManager
                    Navigator.pop(context);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                  underline: Container(),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Notifications'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to notifications settings
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help'),
                onTap: () {
                  Navigator.pop(context);
                  // Show help
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_currentUserId == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: AppLogoLoadingWidget(size: 80)),
      );
    }

    final displayChats = _isSearching ? _searchResults : _filteredChats;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Chats list
          Expanded(
            child: displayChats.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: theme.disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSearching
                        ? 'No chats found'
                        : 'No chats yet',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
                  if (!_isSearching)
                    TextButton(
                      onPressed: () => _startNewChat(context),
                      child: const Text('Start a new chat'),
                    ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: displayChats.length,
              itemBuilder: (context, index) {
                return _buildChatListItem(displayChats[index]);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'chat_screen_fab',
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        onPressed: () => _startNewChat(context),
        child: const Icon(Icons.chat),
      ),
    );
  }
}

// Chat data models
enum ChatType {
  dm,
  group,
  courseGroup,
  yearGroup,
  system;

  String get name => toString().split('.').last;
}

class ChatItem {
  final String id;
  final ChatType type;
  final String name;
  final String lastMessage;
  final DateTime lastMessageTime;
  final List<String> participants;
  final int? unreadCount;
  final bool isPinned;
  final Map<String, dynamic>? metadata;

  ChatItem({
    required this.id,
    required this.type,
    required this.name,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.participants,
    this.unreadCount,
    this.isPinned = false,
    this.metadata,
  });

  factory ChatItem.fromFirestore(String id, Map<String, dynamic> data) {
    return ChatItem(
      id: id,
      type: ChatType.values.firstWhere(
            (e) => e.name == (data['type'] ?? 'dm'),
        orElse: () => ChatType.dm,
      ),
      name: data['name'] ?? 'Chat',
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participants: List<String>.from(data['participants'] ?? []),
      unreadCount: data['unreadCount'] as int?,
      isPinned: data['isPinned'] ?? false,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'participants': participants,
      'unreadCount': unreadCount,
      'isPinned': isPinned,
      'metadata': metadata,
    };
  }

  factory ChatItem.fromJson(Map<String, dynamic> json) {
    return ChatItem(
      id: json['id'],
      type: ChatType.values.firstWhere(
            (e) => e.name == json['type'],
        orElse: () => ChatType.dm,
      ),
      name: json['name'],
      lastMessage: json['lastMessage'],
      lastMessageTime: DateTime.parse(json['lastMessageTime']),
      participants: List<String>.from(json['participants']),
      unreadCount: json['unreadCount'],
      isPinned: json['isPinned'] ?? false,
      metadata: json['metadata'],
    );
  }

  ChatItem copyWith({
    String? id,
    ChatType? type,
    String? name,
    String? lastMessage,
    DateTime? lastMessageTime,
    List<String>? participants,
    int? unreadCount,
    bool? isPinned,
    Map<String, dynamic>? metadata,
  }) {
    return ChatItem(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      participants: participants ?? this.participants,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      metadata: metadata ?? this.metadata,
    );
  }
}
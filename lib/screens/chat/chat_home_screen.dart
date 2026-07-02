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

  List<ChatItem> _allChats = [];
  List<ChatItem> _filteredChats = [];
  StreamSubscription? _chatSubscription;

  // Search
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<ChatItem> _searchResults = [];

  // User cache
  final Map<String, String> _userNameCache = {};
  final Map<String, String> _userPhotoCache = {};

  // Tab selection
  int _selectedTab = 0; // 0: Chats, 1: Groups

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

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _currentUserName = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
          if (_currentUserName!.isEmpty) _currentUserName = 'User';
          _currentUserCourse = data['course'];
          _currentYear = data['year'];
          _currentSemester = data['semester'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching user session metadata: $e");
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

      if (chat.type == ChatType.dm) {
        final otherUserId = chat.participants
            .firstWhere((id) => id != _currentUserId, orElse: () => '');
        if (otherUserId.isNotEmpty && !_userNameCache.containsKey(otherUserId)) {
          _fetchUserData(otherUserId);
        }
      }
    }

    final existingChatIds = updatedChats.map((c) => c.id).toSet();
    final preservedChats = _allChats.where((c) => !existingChatIds.contains(c.id)).toList();

    setState(() {
      _allChats = [...updatedChats, ...preservedChats];
      _filteredChats = _sortAndFilterChats(_allChats);
    });

    _saveChatsToCache(_allChats);
  }

  Future<void> _fetchUserData(String userId) async {
    if (_userNameCache.containsKey(userId)) return;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final name = data['first_name'] ?? data['name'] ?? 'Unknown';
        final photo = data['profile_photo_url'] ?? '';
        setState(() {
          _userNameCache[userId] = name;
          if (photo.isNotEmpty) _userPhotoCache[userId] = photo;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  Future<void> _createOrJoinRequiredGroups() async {
    if (_currentUserId == null || _currentUserCourse == null) return;

    await _ensureGroupChat(
      id: 'general_system_chat',
      name: '🌟 Campus Announcements',
      description: 'General announcements for all users',
      type: ChatType.system,
      isPinned: true,
    );

    if (_currentSemester != null && _currentUserCourse != null) {
      final courseDisplay = _currentUserCourse!;
      final yearSemDisplay = '$courseDisplay $_currentYear.$_currentSemester';
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

    await _ensureGroupChat(
      id: 'course_${_currentUserCourse}_chat',
      name: '🎓 $_currentUserCourse Course',
      description: 'Group for $_currentUserCourse students',
      type: ChatType.courseGroup,
      filters: {'course': _currentUserCourse},
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
        final participants = List<String>.from(doc.data()?['participants'] ?? []);
        if (!participants.contains(_currentUserId)) {
          await chatRef.update({
            'participants': FieldValue.arrayUnion([_currentUserId]),
          });
        }
        if (isPinned && (doc.data()?['isPinned'] != true)) {
          await chatRef.update({'isPinned': true});
        }
      }
    } catch (e) {
      debugPrint('Error ensuring group chat: $e');
    }
  }

  List<ChatItem> _sortAndFilterChats(List<ChatItem> chats) {
    final pinned = chats.where((c) => c.isPinned).toList();
    final unpinned = chats.where((c) => !c.isPinned).toList();
    pinned.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    unpinned.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return [...pinned, ...unpinned];
  }

  void _refreshChats() => _setupChatStream();

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
      setState(() => _searchResults.clear());
      return;
    }

    final results = _allChats.where((chat) {
      final searchText = query.toLowerCase();
      if (chat.name.toLowerCase().contains(searchText)) return true;
      if (chat.lastMessage.toLowerCase().contains(searchText)) return true;

      if (chat.type == ChatType.dm) {
        final otherUserId = chat.participants
            .firstWhere((id) => id != _currentUserId, orElse: () => '');
        final cachedName = _userNameCache[otherUserId]?.toLowerCase() ?? '';
        return cachedName.contains(searchText);
      }
      return false;
    }).toList();

    setState(() => _searchResults = results);
  }

  void _togglePinChat(ChatItem chat) {
    setState(() {
      final index = _allChats.indexWhere((c) => c.id == chat.id);
      if (index != -1) {
        _allChats[index] = chat.copyWith(isPinned: !chat.isPinned);
        _filteredChats = _sortAndFilterChats(_allChats);
        _firestore.collection('chats').doc(chat.id).update({
          'isPinned': !chat.isPinned,
        });
        _saveChatsToCache(_allChats);
      }
    });
  }

  Future<void> _startNewChat(BuildContext context) async {
    if (_currentUserId == null || _currentUserCourse == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
    ).then((selectedUserId) async {
      if (selectedUserId == null || selectedUserId.isEmpty) return;

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

  // ✅ WHATSAPP-STYLE BUILD
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_currentUserId == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: AppLogoLoadingWidget(size: 80)),
      );
    }

    final displayChats = _isSearching ? _searchResults : _filteredChats;

    // Filter by tab
    final filteredByTab = displayChats.where((chat) {
      if (_selectedTab == 0) return chat.type != ChatType.system && chat.type != ChatType.yearGroup && chat.type != ChatType.courseGroup;
      return chat.type == ChatType.system || chat.type == ChatType.yearGroup || chat.type == ChatType.courseGroup;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildWhatsAppAppBar(theme, colorScheme),
      body: Column(
        children: [
          // WhatsApp-style tabs
          _buildWhatsAppTabs(theme, colorScheme),
          // Chats list
          Expanded(
            child: filteredByTab.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
              itemCount: filteredByTab.length,
              itemBuilder: (context, index) {
                return _buildWhatsAppChatItem(filteredByTab[index], theme, colorScheme);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildWhatsAppFAB(theme, colorScheme),
    );
  }

  // ✅ WHATSAPP-STYLE APP BAR
  PreferredSizeWidget _buildWhatsAppAppBar(ThemeData theme, ColorScheme colorScheme) {
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
            hintStyle: theme.textTheme.bodyLarge?.copyWith(color: theme.disabledColor),
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
      elevation: 0.5,
      title: Text(
        'Chats',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _toggleSearch,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'new_group') {
              // Navigate to new group creation
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'new_group', child: Text('New group')),
            const PopupMenuItem(value: 'settings', child: Text('Settings')),
          ],
        ),
      ],
    );
  }

  // ✅ WHATSAPP-STYLE TABS
  Widget _buildWhatsAppTabs(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildTabItem(
            context: context,
            label: 'Chats',
            index: 0,
            count: _allChats.where((c) => c.type != ChatType.system && c.type != ChatType.yearGroup && c.type != ChatType.courseGroup).length,
            theme: theme,
            colorScheme: colorScheme,
          ),
          _buildTabItem(
            context: context,
            label: 'Groups',
            index: 1,
            count: _allChats.where((c) => c.type == ChatType.system || c.type == ChatType.yearGroup || c.type == ChatType.courseGroup).length,
            theme: theme,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required BuildContext context,
    required String label,
    required int index,
    required int count,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _selectedTab == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ✅ WHATSAPP-STYLE CHAT ITEM
  Widget _buildWhatsAppChatItem(ChatItem chat, ThemeData theme, ColorScheme colorScheme) {
    String displayName = chat.name;
    String? subtitle = chat.lastMessage;
    int? unreadCount = chat.unreadCount;
    bool isOnline = false; // You can implement online status

    if (chat.type == ChatType.dm) {
      final otherUserId = chat.participants
          .firstWhere((id) => id != _currentUserId, orElse: () => '');
      displayName = _userNameCache[otherUserId] ?? 'Unknown User';
    }

    return InkWell(
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
      onLongPress: () => _showChatOptions(chat, theme, colorScheme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withOpacity(0.2),
              width: 0.3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            _buildWhatsAppAvatar(chat, theme, colorScheme),
            const SizedBox(width: 12),
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
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(chat.lastMessageTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.disabledColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (chat.isPinned)
                        Icon(Icons.push_pin, size: 12, color: theme.disabledColor),
                      if (chat.isPinned) const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: unreadCount != null && unreadCount > 0
                                ? colorScheme.onSurface
                                : theme.disabledColor,
                            fontWeight: unreadCount != null && unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount != null && unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
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
                              fontSize: 11,
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
    );
  }

  // ✅ WHATSAPP-STYLE AVATAR
  Widget _buildWhatsAppAvatar(ChatItem chat, ThemeData theme, ColorScheme colorScheme) {
    final isGroup = chat.type != ChatType.dm;

    if (isGroup) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: _getChatColor(chat.type).withOpacity(0.15),
        child: Icon(
          _getChatIcon(chat.type),
          color: _getChatColor(chat.type),
          size: 28,
        ),
      );
    }

    final otherUserId = chat.participants
        .firstWhere((id) => id != _currentUserId, orElse: () => '');
    final userName = _userNameCache[otherUserId] ?? '';
    final photoUrl = _userPhotoCache[otherUserId];
    final initials = userName.isNotEmpty
        ? userName.substring(0, 1).toUpperCase()
        : '?';

    return CircleAvatar(
      radius: 24,
      backgroundColor: colorScheme.primary.withOpacity(0.1),
      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
          ? NetworkImage(photoUrl)
          : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? Text(
        initials,
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      )
          : null,
    );
  }

  // ✅ WHATSAPP-STYLE FAB
  Widget _buildWhatsAppFAB(ThemeData theme, ColorScheme colorScheme) {
    return FloatingActionButton(
      heroTag: 'chat_screen_fab',
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      onPressed: () => _startNewChat(context),
      child: const Icon(Icons.chat),
    );
  }

  // ✅ EMPTY STATE
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedTab == 0 ? Icons.chat_bubble_outline : Icons.group_outlined,
            size: 64,
            color: theme.disabledColor,
          ),
          const SizedBox(height: 12),
          Text(
            _selectedTab == 0 ? 'No chats yet' : 'No groups yet',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.disabledColor,
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedTab == 0)
            TextButton(
              onPressed: () => _startNewChat(context),
              child: const Text('Start a new chat'),
            ),
        ],
      ),
    );
  }

  // ✅ CHAT OPTIONS BOTTOM SHEET
  void _showChatOptions(ChatItem chat, ThemeData theme, ColorScheme colorScheme) {
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
                  color: colorScheme.primary,
                ),
                title: Text(chat.isPinned ? 'Unpin chat' : 'Pin chat'),
                onTap: () {
                  Navigator.pop(context);
                  _togglePinChat(chat);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_none, color: Colors.grey),
                title: const Text('Mute notifications'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined, color: Colors.grey),
                title: const Text('Archive chat'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete chat'),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ✅ UTILITY METHODS
  Color _getChatColor(ChatType type) {
    switch (type) {
      case ChatType.system: return Colors.amber;
      case ChatType.yearGroup: return Colors.green;
      case ChatType.courseGroup: return Colors.blue;
      case ChatType.group: return Colors.purple;
      case ChatType.dm: return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _getChatIcon(ChatType type) {
    switch (type) {
      case ChatType.system: return Icons.campaign;
      case ChatType.yearGroup: return Icons.school;
      case ChatType.courseGroup: return Icons.group;
      case ChatType.group: return Icons.forum;
      case ChatType.dm: return Icons.person;
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
}

// ✅ CHAT DATA MODELS (Minimal)
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
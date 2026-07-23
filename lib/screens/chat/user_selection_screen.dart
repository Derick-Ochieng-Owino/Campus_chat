import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Map<String, dynamic>? _currentUserData;
  String _searchQuery = '';
  List<DocumentSnapshot> _userDocs = [];
  bool _isLoading = true;
  bool _hasMore = true;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    final doc = await _firestore.collection('users').doc(_currentUserId).get();
    if (mounted && doc.exists) {
      _currentUserData = doc.data();
    }
    await _fetchUsers(isRefresh: true);
  }

  Future<void> _fetchUsers({bool isRefresh = false}) async {
    if ((!_hasMore && !isRefresh) || _currentUserData == null) return;

    setState(() => _isLoading = true);

    if (isRefresh) {
      _userDocs.clear();
      _hasMore = true;
    }

    Query query = _firestore.collection('users');

    if (_searchQuery.isNotEmpty) {
      query = query
          .orderBy('first_name')
          .startAt([_searchQuery])
          .endAt(['$_searchQuery\uf8ff'])
          .limit(_pageSize);
    } else {
      final String course = _currentUserData?['course'] ?? '';
      final String year = _currentUserData?['year'] ?? '';

      query = query
          .where('course', isEqualTo: course)
          .where('year', isEqualTo: year)
          .orderBy('first_name')
          .limit(_pageSize);
    }

    if (!isRefresh && _userDocs.isNotEmpty) {
      query = query.startAfterDocument(_userDocs.last);
    }

    final snapshot = await query.get();

    if (mounted) {
      setState(() {
        _isLoading = false;
        final newDocs = snapshot.docs.where((doc) => doc.id != _currentUserId).toList();
        _userDocs.addAll(newDocs);

        if (snapshot.docs.length < _pageSize) {
          _hasMore = false;
        }
      });
    }
  }

  // --- NEW: DIRECT CHAT CREATION & NAVIGATION ---
  Future<void> _openChat(BuildContext context, String targetUserId, String targetName) async {
    // Show a quick loading indicator while establishing the connection
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Deterministic chat ID based on participant UIDs
      final participants = [_currentUserId, targetUserId]..sort();
      final String chatId = participants.join('_');

      final chatRef = _firestore.collection('chats').doc(chatId);
      final doc = await chatRef.get();

      // If this is the first time talking, create the thread
      if (!doc.exists) {
        await chatRef.set({
          'type': 'dm',
          'participants': participants,
          'name': targetName,
          'lastMessage': 'Chat started',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'isGroup': false,
          'unreadCount': {
            _currentUserId: 0,
            targetUserId: 0,
          }
        });
      }

      if (mounted) {
        Navigator.pop(context); // Remove loading dialog
        Navigator.pushReplacement( // Replaces selection screen with the chat screen
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              chatName: targetName,
              otherUserId: targetUserId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Remove loading dialog on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting chat: $e')),
        );
      }
    }
  }

  Widget _buildRoundedSquareAvatar(String photoUrl, String name, ThemeData theme) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl.isNotEmpty
          ? Image.network(photoUrl, fit: BoxFit.cover)
          : Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildSelfTile(ThemeData theme) {
    final name = '${_currentUserData?['first_name'] ?? ''} ${_currentUserData?['last_name'] ?? ''}'.trim();
    final photoUrl = _currentUserData?['profile_photo_url'] ?? '';

    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3), width: 1.5),
        ),
        color: theme.colorScheme.primary.withOpacity(0.05),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: Stack(
            alignment: Alignment.bottomRight,
            children: [
              _buildRoundedSquareAvatar(photoUrl, name, theme),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bookmark, size: 14, color: theme.colorScheme.primary),
              ),
            ],
          ),
          title: Text(
            '$name (You)',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Message yourself',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
          ),
          onTap: () => _openChat(context, _currentUserId, '$name (You)'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    int itemCount = _userDocs.length;
    final bool showSelfTile = _searchQuery.isEmpty && _currentUserData != null;

    if (showSelfTile) itemCount += 1;
    if (_isLoading && _currentUserData == null) {
      itemCount = 1;
    } else if (_isLoading) {
      itemCount += 1;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: const Text(
          'Select contact',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search names or courses...',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
                prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                _searchQuery = val.trim();
                _fetchUsers(isRefresh: true);
              },
            ),
          ),
        ),
      ),
      body: _currentUserData == null && _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
            _fetchUsers();
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            int dataIndex = index;

            if (showSelfTile) {
              if (index == 0) return _buildSelfTile(theme);
              dataIndex -= 1;
            }

            if (dataIndex == _userDocs.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }

            final data = _userDocs[dataIndex].data() as Map<String, dynamic>;
            final userId = _userDocs[dataIndex].id;
            final name = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
            final photoUrl = data['profile_photo_url'] ?? '';
            final userCourse = data['course'] ?? 'Student';
            final userYear = data['year'] ?? '';

            // --- NEW: CARD UI FOR PEERS ---
            return RepaintBoundary(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 1, // Subtle drop shadow
                shadowColor: Colors.black.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openChat(context, userId, name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: _buildRoundedSquareAvatar(photoUrl, name, theme),
                      title: Text(
                        name.isNotEmpty ? name : 'Unknown User',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.school_outlined, size: 14, color: theme.disabledColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '$userCourse • $userYear',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.disabledColor,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Icon(
                        Icons.chat_bubble_outline,
                        color: colorScheme.primary.withOpacity(0.6),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
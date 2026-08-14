import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'user_selection_screen.dart';

class ChatHomeScreen extends StatefulWidget {
  final Function(String chatId, String chatName, String? otherUserId)? onChatSelected;

  const ChatHomeScreen({this.onChatSelected, super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentUserId;
  String? _currentUserPhotoUrl;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (mounted && doc.exists) {
          setState(() {
            _currentUserPhotoUrl = doc.data()?['profile_photo_url'];
          });
        }
      } catch (e) {
        debugPrint("Error loading user profile: $e");
      }
    }
  }

  // --- APP STORE MANDATE: BLOCK/REPORT FROM INBOX ---
  void _showChatOptions(String chatId, String? targetUserId, String chatName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(context).colorScheme;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.push_pin_outlined, color: colorScheme.primary),
                title: const Text('Pin chat'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: colorScheme.error),
                title: Text('Delete chat', style: TextStyle(color: colorScheme.error)),
                onTap: () => Navigator.pop(ctx),
              ),
              const Divider(),
              // Mandatory Compliance Actions
              ListTile(
                leading: Icon(Icons.flag_outlined, color: colorScheme.error),
                title: Text('Report $chatName', style: TextStyle(color: colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  // Trigger your report logic here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted for review.')),
                  );
                },
              ),
              if (targetUserId != null)
                ListTile(
                  leading: Icon(Icons.block, color: colorScheme.error),
                  title: Text('Block User', style: TextStyle(color: colorScheme.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _firestore.collection('users').doc(_currentUserId).update({
                      'blockedUsers': FieldValue.arrayUnion([targetUserId]),
                    });
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary.withOpacity(0.6),
        foregroundColor: colorScheme.onPrimary,
        elevation: 1,
        title: const Text(
          'Alma Mater',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 22),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          // CURRENT USER PROFILE PHOTO IMPLEMENTATION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: GestureDetector(
              onTap: () {
                // Navigate to settings or profile view
              },
              child: CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.onPrimary.withOpacity(0.2),
                backgroundImage: _currentUserPhotoUrl != null && _currentUserPhotoUrl!.isNotEmpty
                    ? NetworkImage(_currentUserPhotoUrl!)
                    : null,
                child: _currentUserPhotoUrl == null || _currentUserPhotoUrl!.isEmpty
                    ? Icon(Icons.person, size: 20, color: colorScheme.onPrimary)
                    : null,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.onPrimary,
          indicatorWeight: 3,
          labelColor: colorScheme.onPrimary,
          unselectedLabelColor: colorScheme.onPrimary.withOpacity(0.6),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: 'CHATS'),
            Tab(text: 'GROUPS'),
          ],
        ),
      ),
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _tabController,
        children: [
          _buildChatList(theme, isGroup: false),
          _buildChatList(theme, isGroup: true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
          );
        },
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildChatList(ThemeData theme, {required bool isGroup}) {
    if (_currentUserId == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return StreamBuilder<QuerySnapshot>(
      // Firestore Query optimized for pagination and indexing
      stream: _firestore
          .collection('chats')
          .where('participants', arrayContains: _currentUserId)
          .where('isGroup', isEqualTo: isGroup)
          .orderBy('lastMessageTime', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: theme.textTheme.bodyMedium));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Text(
              isGroup ? 'No groups yet.' : 'No chats yet. Start messaging!',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.disabledColor),
            ),
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(left: 76.0, right: 16.0),
            child: Divider(height: 0.5, thickness: 0.5, color: theme.dividerColor.withOpacity(0.5)),
          ),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final chatId = docs[index].id;

            // Extract UI data safely
            final chatName = data['name'] ?? 'Unknown';
            final lastMessage = data['lastMessage'] ?? '';
            final photoUrl = data['photoUrl'] ?? '';
            final unreadCount = data['unreadCount']?[_currentUserId] ?? 0;

            // Get other user ID if it's a DM
            String? targetUserId;
            if (!isGroup) {
              final participants = List<String>.from(data['participants'] ?? []);
              targetUserId = participants.firstWhere((id) => id != _currentUserId, orElse: () => '');
            }

            // REPAINT BOUNDARY: Isolates this list tile to prevent whole-screen redraws
            return RepaintBoundary(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? Icon(isGroup ? Icons.group : Icons.person, color: theme.colorScheme.onPrimaryContainer)
                      : null,
                ),
                title: Text(
                  chatName,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    lastMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: unreadCount > 0 ? theme.colorScheme.onSurface : theme.disabledColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '12:45 PM', // Replace with parsed lastMessageTime logic
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: unreadCount > 0 ? theme.colorScheme.primary : theme.disabledColor,
                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chatId,
                        chatName: chatName,
                        otherUserId: targetUserId,
                      ),
                    ),
                  );
                },
                onLongPress: () => _showChatOptions(chatId, targetUserId, chatName),
              ),
            );
          },
        );
      },
    );
  }
}
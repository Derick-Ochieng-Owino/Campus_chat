import 'package:campus_app/screens/chat/user_selection_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:campus_app/core/constants/colors.dart';
import 'package:campus_app/screens/chat/chat_screen.dart';

// ------------------- ChatHomeScreen (The Main Focus) -------------------

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // Fetch current user details (UID and Role)
  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    _currentUserId = user.uid;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        _currentUserRole = data['role'] as String?;
      });
      // Optionally create the general Course/Year/Semester chat here
      _ensureGeneralCourseChat(data);
    }
  }

  // Ensures a general chat exists for the user's course/year/semester
  Future<void> _ensureGeneralCourseChat(Map<String, dynamic> userData) async {
    final course = userData['course'] ?? 'default_course';
    final yearKey = userData['year_key'] ?? 'year1';
    final semesterKey = userData['semester_key'] ?? 'semester1';

    // Create a deterministic Chat ID for this course/year/semester
    final chatId = 'course_${course}_${yearKey}_${semesterKey}';

    // Check if the chat document exists
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      await _firestore.collection('chats').doc(chatId).set({
        'name': 'General Chat: ${course.toUpperCase()} - ${yearKey.toUpperCase()}',
        'type': 'general',
        'participants': [_currentUserId], // Start with current user
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } else if (!chatDoc.data()?['participants']?.contains(_currentUserId) ?? true) {
      // If it exists but user isn't a participant (new user), add them
      await _firestore.collection('chats').doc(chatId).update({
        'participants': FieldValue.arrayUnion([_currentUserId])
      });
    }
  }

  // Gets the appropriate icon for the chat type
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

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Admins see ALL chats. Regular users see only chats they participate in.
    final isAdmin = _currentUserRole == 'admin';

    Query query;
    if (isAdmin) {
      // Admin sees ALL group and general chats (but not all DMs)
      query = _firestore.collection('chats')
          .where('type', whereIn: ['group', 'general'])
          .orderBy('lastMessageAt', descending: true);
    } else {
      // Regular user sees only chats where their UID is in the participants array
      query = _firestore.collection('chats')
          .where('participants', arrayContains: _currentUserId)
          .orderBy('lastMessageAt', descending: true);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No active chats. Join a group or start a DM.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final chats = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chatData = chats[index].data() as Map<String, dynamic>;
              final chatId = chats[index].id;
              final chatType = chatData['type'] ?? 'dm';
              final participants = chatData['participants'] as List<dynamic>? ?? [];
              final lastMessage = chatData['lastMessage'] ?? 'No messages yet';

              // Determine display name and otherUserId for DMs
              String displayName = chatData['name'] ?? 'Unknown Chat';
              String? otherUserId;

              if (chatType == 'dm') {
                // Find the UID that is NOT the current user
                final otherUid = participants.firstWhere(
                      (uid) => uid != _currentUserId,
                  orElse: () => null,
                );
                otherUserId = otherUid as String?;

                // For DMs, we need to fetch the other user's name
                // To keep the UI snappy, we'll use a FutureBuilder here to fetch the name
                return FutureBuilder<DocumentSnapshot>(
                  future: otherUserId != null ? _firestore.collection('users').doc(otherUserId).get() : null,
                  builder: (context, userSnap) {
                    String dmName = otherUserId ?? 'Unknown User';
                    if (userSnap.hasData && userSnap.data?.data() != null) {
                      dmName = (userSnap.data!.data() as Map<String, dynamic>)['name'] ?? dmName;
                    }
                    return _buildChatTile(
                      context,
                      chatId: chatId,
                      chatName: dmName,
                      subtitle: lastMessage,
                      type: chatType,
                      otherUserId: otherUserId,
                    );
                  },
                );
              }

              // For Group/General chats, use the name stored in the chat document
              return _buildChatTile(
                context,
                chatId: chatId,
                chatName: displayName,
                subtitle: lastMessage,
                type: chatType,
              );
            },
          );
        },
      ),

      // Floating Action Button to start a new DM
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _startNewDm(context),
        child: const Icon(Icons.message_rounded, color: Colors.white),
      ),
    );
  }

  // --- Helper Widget for Chat List Item ---
  Widget _buildChatTile(
      BuildContext context, {
        required String chatId,
        required String chatName,
        required String subtitle,
        required String type,
        String? otherUserId, // Used for navigation/DM identification
      }) {

    final icon = _getIconForChatType(type);
    final isGroup = type != 'dm';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: isGroup ? AppColors.secondary.withOpacity(0.8) : AppColors.primary.withOpacity(0.7),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        title: Text(
            chatName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chatId,
                chatName: chatName,
                otherUserId: otherUserId,
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Function to Start a new DM ---
  // Inside the _ChatHomeScreenState class:

// Function to create a deterministic Chat ID for DMs
  String _getDeterministicDmChatId(String uid1, String uid2) {
    // Sort UIDs alphabetically to ensure the ID is the same regardless of who starts the chat
    final sortedUids = [uid1, uid2]..sort();
    return '${sortedUids[0]}_${sortedUids[1]}';
  }


  void _startNewDm(BuildContext context) {
    // You must ensure _currentUserId is loaded before this runs
    if (_currentUserId == null) return;

    // Remove the temporary SnackBar and navigate to the UserSelectionScreen
    Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserSelectionScreen())
    ).then((selectedUid) async {
      final otherUserId = selectedUid as String?;

      if (otherUserId != null && _currentUserId != otherUserId) {

        final chatId = _getDeterministicDmChatId(_currentUserId!, otherUserId);
        final chatRef = _firestore.collection('chats').doc(chatId);

        // 1. Check if the DM chat already exists
        final chatDoc = await chatRef.get();

        if (!chatDoc.exists) {
          // 2. If it doesn't exist, create a new DM chat document
          final currentUserData = await _firestore.collection('users').doc(_currentUserId!).get();
          final currentUserName = currentUserData.data()?['name'] ?? 'User';

          await chatRef.set({
            'type': 'dm',
            'participants': [_currentUserId!, otherUserId],
            'lastMessage': '$currentUserName started the chat.',
            'lastMessageAt': FieldValue.serverTimestamp(),
            // Note: No 'name' field needed for DMs, the UI handles the name display
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New chat created!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Existing chat loaded.')),
          );
        }

        // 3. Navigate to the ChatScreen
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: chatId,
                  otherUserId: otherUserId,
                )
            )
        );
      }
    });
  }
}
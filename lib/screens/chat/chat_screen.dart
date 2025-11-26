import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Needed for real current user ID

// Assuming these are defined in your project
import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../models/chat_model.dart';
import '../../providers/chat_provider.dart';

// --- Helper Functions to Get Real User Data (Integration) ---
// Note: In a real app, you'd get this from a dedicated AuthProvider
String _getCurrentUserId() {
  return FirebaseAuth.instance.currentUser?.uid ?? 'DEFAULT_USER_ID';
}
String _getCurrentUserName() {
  // Ideally, fetch this from your User document stored in state/provider
  return FirebaseAuth.instance.currentUser?.displayName ?? 'You';
}
// -----------------------------------------------------------


class ChatScreen extends StatefulWidget {
  // chatId is now MANDATORY for the unified stream logic
  final String chatId;
  final String? chatName;
  final String? otherUserId;

  // Make chatId required for the simplified provider structure
  const ChatScreen({required this.chatId, this.chatName, this.otherUserId, super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late TextEditingController textController;
  final ScrollController _scrollController = ScrollController();

  // Use the helper functions to get the actual user data
  late final String currentUserId;
  late final String currentUserName;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController();

    // Initialize user details
    currentUserId = _getCurrentUserId();
    currentUserName = _getCurrentUserName();
  }

  @override
  void dispose() {
    textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Scrolls to the latest message after sending
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- Unified Send Message Function ---
  // Inside _ChatScreenState

  void _sendMessage(ChatProvider chatProvider) {
    final text = textController.text.trim();
    if (text.isEmpty) return;
    // Safety check is now implicit due to required nature of widget.chatId

    // All logic is now simplified into one call to the unified sendMessage:
    chatProvider.sendMessage(
      chatId: widget.chatId, // Mandatory
      text: text,
      senderName: currentUserName,
      senderId: currentUserId,
      // Passes the receiverId only if it exists (for DMs)
      receiverId: widget.otherUserId,
    );

    textController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Ensure you are reading the ChatProvider here
    final chatProvider = Provider.of<ChatProvider>(context);

    // Determine chat title
    final title = widget.chatName ?? (widget.otherUserId == null ? 'Group Chat' : 'Direct Message');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              // FIX: Use the unified chatStream and pass the mandatory chatId
              stream: chatProvider.chatStream(widget.chatId),
              builder: (context, snapshot) {
                // If the user's internet is slow or the index is still building, show loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  // Show the error clearly (useful for debugging the index/Firestore rules)
                  return Center(child: Text('Error loading messages: ${snapshot.error}', style: TextStyle(color: AppColors.darkGrey)));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Text('Start the conversation in ${widget.chatName ?? 'this chat'}!', style: TextStyle(color: AppColors.darkGrey)),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUserId;
                    return _ChatBubble(
                      message: msg,
                      isMe: isMe,
                      // Show name only if it's a group chat AND not the current user
                      showSenderName: widget.otherUserId == null && !isMe,
                    );
                  },
                );
              },
            ),
          ),

          // 2. Floating Input Bar
          _buildFloatingInputBar(chatProvider),
        ],
      ),
    );
  }

  // ... (The _buildFloatingInputBar and _ChatBubble widgets remain the same)
  // ... (The code for those widgets is omitted here for brevity but remains valid)

  Widget _buildFloatingInputBar(ChatProvider chatProvider) {
    // ... (Your existing _buildFloatingInputBar implementation) ...
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      // Glass/Floating effect container
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Attachment Button (New Feature UI)
          SizedBox(
            width: 40,
            height: 40,
            child: FloatingActionButton(
              mini: true,
              heroTag: null,
              backgroundColor: AppColors.lightGrey,
              onPressed: () {
                // Implement file/photo picker here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attachment Picker Tapped')),
                );
              },
              child: Icon(Icons.attach_file, color: AppColors.darkGrey, size: 20),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 8),

          // Text Input Field (Slightly cleaner)
          Expanded(
            child: TextField(
              controller: textController,
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: 5, // Allows for multiline input
              decoration: InputDecoration(
                hintText: 'Message...',
                fillColor: AppColors.lightGrey,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onTap: _scrollToBottom, // Scroll down if keyboard opens
            ),
          ),
          const SizedBox(width: 8),

          // Send Button
          FloatingActionButton(
            mini: true,
            heroTag: 'chatSendButton',
            backgroundColor: AppColors.secondary,
            onPressed: () => _sendMessage(chatProvider),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            elevation: 2,
          ),
        ],
      ),
    );
  }
}

// ------------------- Enhanced Chat Bubble (Kept the same) -------------------
// (This widget remains functionally identical to the version you provided)
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showSenderName;

  const _ChatBubble({
    required this.message,
    required this.isMe,
    this.showSenderName = false,
  });

  @override
  Widget build(BuildContext context) {
    // --- Dynamic Styling ---
    final Color bubbleColor = isMe ? AppColors.primary : Colors.white;
    final Color textColor = isMe ? Colors.white : Colors.black87;
    final double radius = 18.0;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        constraints:
        BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),

        decoration: BoxDecoration(
          color: bubbleColor,
          // --- Asymmetrical and sharper border style ---
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(radius),
            topRight: Radius.circular(radius),
            bottomLeft: Radius.circular(isMe ? radius : 4),
            bottomRight: Radius.circular(isMe ? 4 : radius),
          ),
          // --- Softer elevation/shadow ---
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender Name
            if (showSenderName)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                      fontSize: 13),
                ),
              ),

            // Message Text
            Text(message.text, style: AppTextStyles.chatMessage.copyWith(color: textColor)),

            // Timestamp (Subtle)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                child: Text(
                  '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : AppColors.darkGrey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
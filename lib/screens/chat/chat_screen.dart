import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Assuming these are defined in your project
// import '../../core/constants/colors.dart'; // NO LONGER NEEDED
// import '../../core/constants/text_styles.dart'; // NO LONGER NEEDED
import '../../models/chat_model.dart';
import '../../providers/chat_provider.dart';

// --- Helper Functions to Get Real User Data (Integration) ---
String _getCurrentUserId() {
  return FirebaseAuth.instance.currentUser?.uid ?? 'DEFAULT_USER_ID';
}
String _getCurrentUserName() {
  return FirebaseAuth.instance.currentUser?.displayName ?? 'You';
}
// -----------------------------------------------------------


class ChatScreen extends StatefulWidget {
  final String chatId;
  final String? chatName;
  final String? otherUserId;

  const ChatScreen({required this.chatId, this.chatName, this.otherUserId, super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late TextEditingController textController;
  final ScrollController _scrollController = ScrollController();

  late final String currentUserId;
  late final String currentUserName;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController();
    currentUserId = _getCurrentUserId();
    currentUserName = _getCurrentUserName();
  }

  @override
  void dispose() {
    textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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

  void _sendMessage(ChatProvider chatProvider) {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    chatProvider.sendMessage(
      chatId: widget.chatId,
      text: text,
      senderName: currentUserName,
      senderId: currentUserId,
      receiverId: widget.otherUserId,
    );

    textController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chatProvider = Provider.of<ChatProvider>(context);

    // Determine chat title
    final title = widget.chatName ?? (widget.otherUserId == null ? 'Group Chat' : 'Direct Message');

    return Scaffold(
      // Use dynamic background color
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        // FIX: Remove extra comma and use dynamic surface color
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        title: Text(title, style: theme.textTheme.titleLarge), // Use themed text style
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: chatProvider.chatStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: colorScheme.secondary));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading messages: ${snapshot.error}', style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.error)));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    // Use themed text style and color
                    child: Text('Start the conversation in ${widget.chatName ?? 'this chat'}!', style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
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

  Widget _buildFloatingInputBar(ChatProvider chatProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface, // Use theme surface color
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Attachment Button
          SizedBox(
            width: 40,
            height: 40,
            child: FloatingActionButton(
              mini: true,
              heroTag: null,
              backgroundColor: colorScheme.primaryContainer, // Use subtle primary color for light BG
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attachment Picker Tapped')),
                );
              },
              child: Icon(Icons.attach_file, color: colorScheme.onSurface.withOpacity(0.7), size: 20),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 8),

          // Text Input Field (Rely on InputDecorationTheme for border/fill color)
          Expanded(
            child: TextField(
              controller: textController,
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Message...',
                // Fill color and borders now come from InputDecorationTheme
              ),
              onTap: _scrollToBottom,
            ),
          ),
          const SizedBox(width: 8),

          // Send Button
          FloatingActionButton(
            mini: true,
            heroTag: 'chatSendButton',
            // Colors are applied via FloatingActionButtonTheme in theme_manager
            onPressed: () => _sendMessage(chatProvider),
            child: Icon(Icons.send_rounded, color: colorScheme.onSecondary, size: 20),
            elevation: 2,
          ),
        ],
      ),
    );
  }
}

// ------------------- Enhanced Chat Bubble -------------------

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // --- Dynamic Styling ---
    // FIX: Ensure text color is derived correctly based on bubble background
    final Color bubbleColor = isMe ? colorScheme.primary : theme.cardColor;
    final Color textColor = isMe ? colorScheme.onPrimary : colorScheme.onSurface;
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
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(radius),
            topRight: Radius.circular(radius),
            bottomLeft: Radius.circular(isMe ? radius : 4),
            bottomRight: Radius.circular(isMe ? 4 : radius),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.onSurface.withOpacity(0.08),
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
                  style: theme.textTheme.bodySmall!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.secondary, // Use dynamic secondary accent
                      fontSize: 13),
                ),
              ),

            // Message Text
            Text(message.text, style: theme.textTheme.bodyMedium!.copyWith(color: textColor)),

            // Timestamp (Subtle)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                child: Text(
                  '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodySmall!.copyWith(
                    fontSize: 10,
                    // Subdued color based on background
                    color: isMe ? colorScheme.onPrimary.withOpacity(0.7) : colorScheme.onSurface.withOpacity(0.5),
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
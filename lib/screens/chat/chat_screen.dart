import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for Block/Report functionality
import '../../models/chat_model.dart';
import '../../providers/chat_provider.dart';

// Helper Functions for User Data
String _getCurrentUserId() {
  return FirebaseAuth.instance.currentUser?.uid ?? 'DEFAULT_USER_ID';
}

String _getCurrentUserName() {
  return FirebaseAuth.instance.currentUser?.displayName ?? 'You';
}

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String? chatName;
  final String? otherUserId;
  final bool isCompactMode;

  const ChatScreen({
    required this.chatId,
    this.chatName,
    this.otherUserId,
    this.isCompactMode = false,
    super.key,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late TextEditingController textController;
  final ScrollController _scrollController = ScrollController();
  late FocusNode _textFieldFocusNode;

  late final String currentUserId;
  late final String currentUserName;
  final double _desktopMinWidth = 600;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController();
    _textFieldFocusNode = FocusNode();
    currentUserId = _getCurrentUserId();
    currentUserName = _getCurrentUserName();
  }

  @override
  void dispose() {
    textController.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
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

  // --- APP STORE MANDATE 1: REPORT USER ---
  void _showReportDialog() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Content'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please describe why you are reporting this chat:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Spam, Abuse, Harassment',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              if (reasonController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('reports').add({
                  'reportedBy': currentUserId,
                  'targetUserId': widget.otherUserId,
                  'chatId': widget.chatId,
                  'reason': reasonController.text.trim(),
                  'timestamp': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted. We will review it shortly.')),
                  );
                }
              }
            },
            child: const Text('Submit Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- APP STORE MANDATE 2: BLOCK USER ---
  void _blockUser() async {
    if (widget.otherUserId == null) return;

    await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
      'blockedUsers': FieldValue.arrayUnion([widget.otherUserId]),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User blocked successfully.')),
      );
      Navigator.of(context).pop(); // Exit chat screen after blocking
    }
  }

  bool get _isDesktopLayout {
    return kIsWeb && MediaQuery.of(context).size.width > _desktopMinWidth;
  }

  EdgeInsets get _horizontalPadding {
    if (_isDesktopLayout) {
      return const EdgeInsets.symmetric(horizontal: 80.0);
    }
    return EdgeInsets.zero;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chatProvider = Provider.of<ChatProvider>(context);
    final bool isDesktop = _isDesktopLayout;
    final bool showAppBar = !widget.isCompactMode;

    final title = widget.chatName ??
        (widget.otherUserId == null ? 'Group Chat' : 'Direct Message');

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: showAppBar
          ? AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            if (isDesktop) const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: colorScheme.secondary,
              radius: 20,
              child: Text(
                title.isNotEmpty ? title.substring(0, 1).toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {},
          ),
          // ADDED: App Store Compliance Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'report') _showReportDialog();
              if (val == 'block') _blockUser();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'report',
                child: Text('Report Chat'),
              ),
              if (widget.otherUserId != null)
                PopupMenuItem(
                  value: 'block',
                  child: Text('Block User', style: TextStyle(color: colorScheme.error)),
                ),
            ],
          ),
          if (isDesktop) const SizedBox(width: 16),
        ],
      )
          : null,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: _horizontalPadding,
              child: StreamBuilder<List<ChatMessage>>(
                stream: chatProvider.chatStream(widget.chatId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading messages: ${snapshot.error}',
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    );
                  }

                  final messages = snapshot.data ?? [];

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: colorScheme.primary.withOpacity(0.1),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 40,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Start the conversation!',
                            style: theme.textTheme.titleMedium!.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Send your first message',
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Native message anchoring
                    padding: const EdgeInsets.only(bottom: 8, top: 8),
                    itemCount: messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        final firstMessage = messages.last;
                        return _DateHeader(date: firstMessage.timestamp);
                      }

                      final msg = messages[messages.length - 1 - index];
                      final isMe = msg.senderId == currentUserId;

                      bool showDateHeader = false;
                      if (index < messages.length - 1) {
                        final nextMsg = messages[messages.length - 2 - index];
                        final currentDate = DateTime(
                          msg.timestamp.year,
                          msg.timestamp.month,
                          msg.timestamp.day,
                        );
                        final nextDate = DateTime(
                          nextMsg.timestamp.year,
                          nextMsg.timestamp.month,
                          nextMsg.timestamp.day,
                        );
                        showDateHeader = currentDate != nextDate;
                      }

                      // ADDED: RepaintBoundary isolates render repaints to prevent lag
                      return RepaintBoundary(
                        child: Column(
                          children: [
                            if (showDateHeader) _DateHeader(date: msg.timestamp),
                            _MessageBubble(
                              message: msg,
                              isMe: isMe,
                              showSenderName: widget.otherUserId == null && !isMe,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // Input Bar
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
              left: _horizontalPadding.left,
              right: _horizontalPadding.right,
            ),
            color: theme.scaffoldBackgroundColor,
            child: _InputBar(
              textController: textController,
              focusNode: _textFieldFocusNode,
              onSend: () => _sendMessage(chatProvider),
              onTextFieldTap: _scrollToBottom,
            ),
          ),
        ],
      ),
    );
  }
}

// Date Header (Optimized layout)
class _DateHeader extends StatelessWidget {
  final DateTime date;

  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String dateText;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = '${_getMonth(date.month)} ${date.day}, ${date.year}';
    }

    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        dateText,
        style: theme.textTheme.bodySmall!.copyWith(
          color: colorScheme.onSurface.withOpacity(0.6),
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _getMonth(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

// Message Bubble (No changes needed, structurally sound)
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showSenderName;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showSenderName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            child: Column(
              crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSenderName)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 2),
                    child: Text(
                      message.senderName,
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 12 : 0),
                      topRight: Radius.circular(isMe ? 0 : 12),
                      bottomLeft: const Radius.circular(12),
                      bottomRight: const Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(message.timestamp),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.done_all,
                              size: 12,
                              color: colorScheme.primary,
                            ),
                          ],
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

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// Input Bar
class _InputBar extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onTextFieldTap;

  const _InputBar({
    required this.textController,
    required this.focusNode,
    required this.onSend,
    required this.onTextFieldTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: theme.scaffoldBackgroundColor,
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.emoji_emotions_outlined,
              color: colorScheme.onSurface.withOpacity(0.6),
              size: 24,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.attach_file,
              color: colorScheme.onSurface.withOpacity(0.6),
              size: 24,
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.onSurface.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: TextField(
                controller: textController,
                focusNode: focusNode,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Type a message',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onTap: onTextFieldTap,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // ADDED: RepaintBoundary around the button to isolate animation frames when typing
          RepaintBoundary(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: textController,
              builder: (context, value, child) {
                final hasText = value.text.trim().isNotEmpty;

                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasText ? colorScheme.primary : colorScheme.primary.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: hasText ? onSend : null,
                    icon: Icon(
                      hasText ? Icons.send : Icons.mic,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
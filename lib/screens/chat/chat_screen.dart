// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// // Assuming these are defined in your project
// // import '../../core/constants/colors.dart'; // NO LONGER NEEDED
// // import '../../core/constants/text_styles.dart'; // NO LONGER NEEDED
// import '../../models/chat_model.dart';
// import '../../providers/chat_provider.dart';
//
// // --- Helper Functions to Get Real User Data (Integration) ---
// String _getCurrentUserId() {
//   return FirebaseAuth.instance.currentUser?.uid ?? 'DEFAULT_USER_ID';
// }
// String _getCurrentUserName() {
//   return FirebaseAuth.instance.currentUser?.displayName ?? 'You';
// }
// // -----------------------------------------------------------
//
//
// class ChatScreen extends StatefulWidget {
//   final String chatId;
//   final String? chatName;
//   final String? otherUserId;
//
//   const ChatScreen({required this.chatId, this.chatName, this.otherUserId, super.key});
//
//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }
//
// class _ChatScreenState extends State<ChatScreen> {
//   late TextEditingController textController;
//   final ScrollController _scrollController = ScrollController();
//
//   late final String currentUserId;
//   late final String currentUserName;
//
//   @override
//   void initState() {
//     super.initState();
//     textController = TextEditingController();
//     currentUserId = _getCurrentUserId();
//     currentUserName = _getCurrentUserName();
//   }
//
//   @override
//   void dispose() {
//     textController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }
//
//   void _scrollToBottom() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           0.0,
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }
//
//   void _sendMessage(ChatProvider chatProvider) {
//     final text = textController.text.trim();
//     if (text.isEmpty) return;
//
//     chatProvider.sendMessage(
//       chatId: widget.chatId,
//       text: text,
//       senderName: currentUserName,
//       senderId: currentUserId,
//       receiverId: widget.otherUserId,
//     );
//
//     textController.clear();
//     _scrollToBottom();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//     final chatProvider = Provider.of<ChatProvider>(context);
//
//     // Determine chat title
//     final title = widget.chatName ?? (widget.otherUserId == null ? 'Group Chat' : 'Direct Message');
//
//     return Scaffold(
//       // Use dynamic background color
//       backgroundColor: theme.scaffoldBackgroundColor,
//       appBar: AppBar(
//         // FIX: Remove extra comma and use dynamic surface color
//         backgroundColor: colorScheme.surface,
//         foregroundColor: colorScheme.onSurface,
//         title: Text(title, style: theme.textTheme.titleLarge), // Use themed text style
//         elevation: 0,
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: StreamBuilder<List<ChatMessage>>(
//               stream: chatProvider.chatStream(widget.chatId),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return Center(child: CircularProgressIndicator(color: colorScheme.secondary));
//                 }
//                 if (snapshot.hasError) {
//                   return Center(child: Text('Error loading messages: ${snapshot.error}', style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.error)));
//                 }
//
//                 final messages = snapshot.data ?? [];
//
//                 if (messages.isEmpty) {
//                   return Center(
//                     // Use themed text style and color
//                     child: Text('Start the conversation in ${widget.chatName ?? 'this chat'}!', style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
//                   );
//                 }
//
//                 return ListView.builder(
//                   controller: _scrollController,
//                   reverse: true,
//                   itemCount: messages.length,
//                   itemBuilder: (context, index) {
//                     final msg = messages[index];
//                     final isMe = msg.senderId == currentUserId;
//                     return _ChatBubble(
//                       message: msg,
//                       isMe: isMe,
//                       showSenderName: widget.otherUserId == null && !isMe,
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//
//           // 2. Floating Input Bar
//           _buildFloatingInputBar(chatProvider),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFloatingInputBar(ChatProvider chatProvider) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: colorScheme.surface, // Use theme surface color
//         boxShadow: [
//           BoxShadow(
//             color: colorScheme.onSurface.withOpacity(0.08),
//             blurRadius: 10,
//             spreadRadius: 2,
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           // Attachment Button
//           SizedBox(
//             width: 40,
//             height: 40,
//             child: FloatingActionButton(
//               mini: true,
//               heroTag: null,
//               backgroundColor: colorScheme.primaryContainer, // Use subtle primary color for light BG
//               onPressed: () {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Attachment Picker Tapped')),
//                 );
//               },
//               child: Icon(Icons.attach_file, color: colorScheme.onSurface.withOpacity(0.7), size: 20),
//               elevation: 0,
//             ),
//           ),
//           const SizedBox(width: 8),
//
//           // Text Input Field (Rely on InputDecorationTheme for border/fill color)
//           Expanded(
//             child: TextField(
//               controller: textController,
//               keyboardType: TextInputType.multiline,
//               minLines: 1,
//               maxLines: 5,
//               decoration: InputDecoration(
//                 hintText: 'Message...',
//                 // Fill color and borders now come from InputDecorationTheme
//               ),
//               onTap: _scrollToBottom,
//             ),
//           ),
//           const SizedBox(width: 8),
//
//           // Send Button
//           FloatingActionButton(
//             mini: true,
//             heroTag: 'chatSendButton',
//             // Colors are applied via FloatingActionButtonTheme in theme_manager
//             onPressed: () => _sendMessage(chatProvider),
//             child: Icon(Icons.send_rounded, color: colorScheme.onSecondary, size: 20),
//             elevation: 2,
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ------------------- Enhanced Chat Bubble -------------------
//
// class _ChatBubble extends StatelessWidget {
//   final ChatMessage message;
//   final bool isMe;
//   final bool showSenderName;
//
//   const _ChatBubble({
//     required this.message,
//     required this.isMe,
//     this.showSenderName = false,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//
//     // --- Dynamic Styling ---
//     // FIX: Ensure text color is derived correctly based on bubble background
//     final Color bubbleColor = isMe ? colorScheme.primary : theme.cardColor;
//     final Color textColor = isMe ? colorScheme.onPrimary : colorScheme.onSurface;
//     final double radius = 18.0;
//
//     return Align(
//       alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
//         padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
//         constraints:
//         BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
//
//         decoration: BoxDecoration(
//           color: bubbleColor,
//           borderRadius: BorderRadius.only(
//             topLeft: Radius.circular(radius),
//             topRight: Radius.circular(radius),
//             bottomLeft: Radius.circular(isMe ? radius : 4),
//             bottomRight: Radius.circular(isMe ? 4 : radius),
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: colorScheme.onSurface.withOpacity(0.08),
//               blurRadius: 3,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Sender Name
//             if (showSenderName)
//               Padding(
//                 padding: const EdgeInsets.only(bottom: 6),
//                 child: Text(
//                   message.senderName,
//                   style: theme.textTheme.bodySmall!.copyWith(
//                       fontWeight: FontWeight.w600,
//                       color: colorScheme.secondary, // Use dynamic secondary accent
//                       fontSize: 13),
//                 ),
//               ),
//
//             // Message Text
//             Text(message.text, style: theme.textTheme.bodyMedium!.copyWith(color: textColor)),
//
//             // Timestamp (Subtle)
//             Align(
//               alignment: Alignment.bottomRight,
//               child: Padding(
//                 padding: const EdgeInsets.only(top: 4.0, left: 8.0),
//                 child: Text(
//                   '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
//                   style: theme.textTheme.bodySmall!.copyWith(
//                     fontSize: 10,
//                     // Subdued color based on background
//                     color: isMe ? colorScheme.onPrimary.withOpacity(0.7) : colorScheme.onSurface.withOpacity(0.5),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  void _onTextFieldTap() {
    _textFieldFocusNode.requestFocus();
    _scrollToBottom();
  }

  // Determine if we should use desktop layout
  bool get _isDesktopLayout {
    return kIsWeb && MediaQuery.of(context).size.width > _desktopMinWidth;
  }

  // Get appropriate padding based on layout
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

    // Determine chat title
    final title = widget.chatName ??
        (widget.otherUserId == null ? 'Group Chat' : 'Direct Message');

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: showAppBar
          ? AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            if (isDesktop) const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: colorScheme.secondary,
              child: Text(
                title.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white),
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
                    'last seen today at 12:30',
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
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
          if (isDesktop) const SizedBox(width: 16),
        ],
      )
          : null,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/dark.png'), // Add your own background image
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
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
                      reverse: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: messages.length + 1, // +1 for date header
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          // Date header for the first message
                          final firstMessage = messages.last;
                          return _DateHeader(
                            date: firstMessage.timestamp,
                            isDesktop: isDesktop,
                          );
                        }

                        final msg = messages[messages.length - 1 - index];
                        final isMe = msg.senderId == currentUserId;

                        // Check if we need a date separator
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

                        return Column(
                          children: [
                            if (showDateHeader)
                              _DateHeader(
                                date: msg.timestamp,
                                isDesktop: isDesktop,
                              ),
                            _WhatsAppBubble(
                              message: msg,
                              isMe: isMe,
                              showSenderName: widget.otherUserId == null && !isMe,
                              isDesktop: isDesktop,
                            ),
                          ],
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
              child: _WhatsAppInputBar(
                textController: textController,
                focusNode: _textFieldFocusNode,
                onSend: () => _sendMessage(chatProvider),
                onTextFieldTap: _onTextFieldTap,
                isDesktop: isDesktop,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// WhatsApp-style Date Header
class _DateHeader extends StatelessWidget {
  final DateTime date;
  final bool isDesktop;

  const _DateHeader({required this.date, required this.isDesktop});

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
      dateText = 'TODAY';
    } else if (messageDate == yesterday) {
      dateText = 'YESTERDAY';
    } else {
      dateText = '${_getMonth(date.month)} ${date.day}, ${date.year}';
    }

    return Container(
      alignment: Alignment.center,
      margin: EdgeInsets.symmetric(
        vertical: 8,
        horizontal: isDesktop ? 100 : 16,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        dateText,
        style: theme.textTheme.bodySmall!.copyWith(
          color: colorScheme.onSurface.withOpacity(0.7),
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _getMonth(int month) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return months[month - 1];
  }
}

// WhatsApp-style Chat Bubble
class _WhatsAppBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showSenderName;
  final bool isDesktop;

  const _WhatsAppBubble({
    required this.message,
    required this.isMe,
    required this.showSenderName,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxWidth = MediaQuery.of(context).size.width * (isDesktop ? 0.6 : 0.75);

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: 2,
        horizontal: isDesktop ? 12 : 8,
      ),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 8 : 0),
                      topRight: Radius.circular(isMe ? 0 : 8),
                      bottomLeft: const Radius.circular(8),
                      bottomRight: const Radius.circular(8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                            style: theme.textTheme.bodySmall!.copyWith(
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
}

// WhatsApp-style Input Bar
class _WhatsAppInputBar extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onTextFieldTap;
  final bool isDesktop;

  const _WhatsAppInputBar({
    required this.textController,
    required this.focusNode,
    required this.onSend,
    required this.onTextFieldTap,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: theme.scaffoldBackgroundColor,
      child: Row(
        children: [
          // Emoji Button
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.emoji_emotions_outlined,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),

          // Attachment Button
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.attach_file,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),

          // Camera Button
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.camera_alt,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),

          // Text Field
          Expanded(
            child: Container(
              constraints: BoxConstraints(maxHeight: 100),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: textController,
                focusNode: focusNode,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onTap: onTextFieldTap,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Voice Message / Send Button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: textController,
            builder: (context, value, child) {
              final hasText = value.text.trim().isNotEmpty;

              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hasText ? colorScheme.primary : Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: hasText ? onSend : () {},
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

          if (isDesktop) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// Main Layout Widget for Desktop (to be used in your main layout)
class WhatsAppDesktopLayout extends StatelessWidget {
  final Widget navigationPanel;
  final Widget chatScreen;
  final double navigationWidth = 350;

  const WhatsAppDesktopLayout({
    required this.navigationPanel,
    required this.chatScreen,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Navigation Panel (Contacts/Channels)
          Container(
            width: navigationWidth,
            color: Colors.white,
            child: navigationPanel,
          ),

          // Vertical Divider
          Container(
            width: 1,
            color: Colors.grey[300],
          ),

          // Chat Screen (Takes remaining space)
          Expanded(
            child: chatScreen,
          ),
        ],
      ),
    );
  }
}

// Example navigation panel widget
class WhatsAppNavigationPanel extends StatelessWidget {
  const WhatsAppNavigationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: const Color(0xFF008069),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Color(0xFF008069)),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.group, color: Colors.white),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.message, color: Colors.white),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search or start new chat',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),

        // Chat List
        Expanded(
          child: ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF008069),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: const Text('Contact Name'),
                subtitle: const Text('Last message preview...'),
                trailing: const Text('12:30'),
                onTap: () {
                  // Handle chat selection
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
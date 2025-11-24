import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../models/chat_model.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final String? otherUserId; // null = group chat
  const ChatScreen({this.otherUserId, super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late TextEditingController textController;

  // Replace these with real auth
  final String currentUserId = 'current_user';
  final String currentUserName = 'You';

  @override
  void initState() {
    super.initState();
    textController = TextEditingController();
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(widget.otherUserId == null ? 'Group Chat' : 'Inbox Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: widget.otherUserId == null
                  ? chatProvider.groupChatStream()
                  : chatProvider.privateChatStream(currentUserId, widget.otherUserId!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUserId;
                    return _ChatBubble(message: msg, isMe: isMe);
                  },
                );
              },
            ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      fillColor: AppColors.lightGrey,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: AppColors.secondary,
                  onPressed: () {
                    if (textController.text.trim().isEmpty) return;
                    if (widget.otherUserId == null) {
                      chatProvider.sendGroupMessage(
                        textController.text.trim(),
                        currentUserName,
                        currentUserId,
                      );
                    } else {
                      chatProvider.sendPrivateMessage(
                        textController.text.trim(),
                        currentUserName,
                        currentUserId,
                        widget.otherUserId!,
                      );
                    }
                    textController.clear();
                  },
                  child: const Icon(Icons.send, color: Colors.white),
                  elevation: 0,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        padding: const EdgeInsets.all(12),
        constraints:
        BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.chatBubble : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 12 : 0),
            topRight: const Radius.circular(12),
            bottomLeft: const Radius.circular(12),
            bottomRight: Radius.circular(isMe ? 0 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                      fontSize: 12),
                ),
              ),
            Text(message.text, style: AppTextStyles.chatMessage),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                child: Text(
                  '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10, color: AppColors.darkGrey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

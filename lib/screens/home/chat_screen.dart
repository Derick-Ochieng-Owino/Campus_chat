import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_app/core/constants/colors.dart';
import 'package:campus_app/core/constants/text_styles.dart';
import 'package:campus_app/models/chat_model.dart';
import 'package:campus_app/providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>{
  late final TextEditingController textController;

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

    // Simulate current user ID (for isMe check)
    const String currentUserId = 'current_user';
    const String currentUserName = 'You';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // 1. Chat Message List
          Expanded(
            child: ListView.builder(
              reverse: true, // Show newest messages at the bottom
              itemCount: chatProvider.messages.length,
              itemBuilder: (context, index) {
                final message = chatProvider.messages.reversed.toList()[index];
                final isMe = message.senderId == currentUserId;

                return _ChatBubble(message: message, isMe: isMe);
              },
            ),
          ),

          // 2. Input Bar (WhatsApp Style)
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      fillColor: AppColors.lightGrey,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: () {
                    if (textController.text.isNotEmpty) {
                      chatProvider.sendMessage(
                          textController.text,
                          currentUserName,
                          currentUserId
                      );
                      textController.clear();
                    }
                  },
                  backgroundColor: AppColors.secondary,
                  mini: true,
                  elevation: 0,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
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
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
            // Sender Name (only for incoming messages)
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                    fontSize: 12,
                  ),
                ),
              ),

            // Message Text
            Text(
              message.text,
              style: AppTextStyles.chatMessage,
            ),

            // Timestamp
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
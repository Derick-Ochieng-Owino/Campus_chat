import 'package:flutter/material.dart';

class ChatTile extends StatelessWidget {
  final String title;
  final String lastMessage;
  final VoidCallback onTap;

  const ChatTile({
    required this.title,
    required this.lastMessage,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(title, maxLines: 1),
      subtitle: Text(lastMessage, maxLines: 1),
      onTap: onTap,
    );
  }
}

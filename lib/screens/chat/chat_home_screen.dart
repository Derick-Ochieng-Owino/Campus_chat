import 'package:flutter/material.dart';
import 'package:campus_app/core/constants/colors.dart';
import 'package:campus_app/screens/chat/chat_screen.dart';

class ChatHomeScreen extends StatelessWidget {
  // Dummy data for users, replace with Firestore users in real app
  final List<Map<String, String>> users = [
    {'uid': 'user1', 'name': 'Alice'},
    {'uid': 'user2', 'name': 'Bob'},
    {'uid': 'user3', 'name': 'Charlie'},
  ];

  ChatHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 1. Group Chat option
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.secondary,
              child: Icon(Icons.group, color: Colors.white),
            ),
            title: const Text('Group Chat', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Chat with everyone in your course'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChatScreen(), // Group chat has no otherUserId
                ),
              );
            },
          ),
          const Divider(),

          // 2. Individual chats
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Text(
                      user['name']!.substring(0, 1),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(user['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Tap to chat privately'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(otherUserId: user['uid']),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

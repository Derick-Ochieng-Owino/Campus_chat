import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
final Color AppColorsPrimary = Colors.blue.shade700;

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select User for DM'),
        backgroundColor: AppColorsPrimary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch all documents from the 'users' collection
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading users: ${snapshot.error}'));
          }

          final users = snapshot.data!.docs
          // Filter out the current user
              .where((doc) => doc.id != currentUserId)
              .toList();

          if (users.isEmpty) {
            return const Center(
              child: Text('No other users found.', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;
              final userName = userData['name'] ?? 'User ${userId.substring(0, 4)}';
              final userRole = userData['role'] ?? 'Student';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColorsPrimary.withOpacity(0.7),
                  child: Text(userName.substring(0, 1), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(userRole),
                onTap: () {
                  // Return the selected user's ID to the previous screen (ChatHomeScreen)
                  Navigator.pop(context, userId);
                },
              );
            },
          );
        },
      ),
    );
  }
}
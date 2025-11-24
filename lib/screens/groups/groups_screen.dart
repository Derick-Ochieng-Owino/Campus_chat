import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../core/services/firestore_service.dart';
import '../../providers/user_provider.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final userProvider = Provider.of<UserProvider>(context);
    final myUid = userProvider.uid;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: fs.groups.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text("No groups created yet."));
          }

          final docs = snap.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final members = List<String>.from(data['members'] ?? []);
              final groupName = data['name'] ?? 'Group ${i + 1}';
              final isMember = myUid != null && members.contains(myUid);

              return ListTile(
                title: Text(groupName),
                subtitle: Text("${members.length} members"),
                trailing: isMember ? const Icon(Icons.chat) : null,
                onTap: isMember
                    ? () {
                  // TODO: navigate to group chat screen when implemented.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Open chat for $groupName (todo)")),
                  );
                }
                    : () {
                  // show members only
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(groupName),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView(
                          shrinkWrap: true,
                          children: members
                              .map((m) => ListTile(title: Text(m)))
                              .toList(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Close"),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

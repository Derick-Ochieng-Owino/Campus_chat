import 'package:flutter/material.dart';
import '../../core/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourseUnitsScreen extends StatelessWidget {
  CourseUnitsScreen({super.key});

  final _fs = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Semester Units")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fs.getSemesterUnits(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text("No units found for this semester."));
          }

          final docs = snap.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unit';
              final code = data['code'] ?? '';
              final semester = data['semester'] ?? 1;

              return ListTile(
                title: Text(name),
                subtitle: Text("$code • Semester $semester"),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Later: open unit details & list files for that unit
                },
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:campus_app/core/constants/colors.dart';
import 'package:campus_app/core/constants/text_styles.dart';
// Note: In a real app, you would fetch Unit and Note data from Firestore here

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  final List<Map<String, String>> sampleNotes = const [
    {'unit': 'CS 201', 'title': 'Intro to AI (PDF)', 'format': 'PDF', 'uploader': 'Jane Doe'},
    {'unit': 'CS 202', 'title': 'DBMS Notes (PPT)', 'format': 'PPT', 'uploader': 'Class Rep'},
    {'unit': 'MA 204', 'title': 'Calculus II Summary (TXT)', 'format': 'TXT', 'uploader': 'Dr. Kimani'},
    {'unit': 'CS 201', 'title': 'Neural Nets Overview (Word)', 'format': 'DOCX', 'uploader': 'Jane Doe'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Notes & Units'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: sampleNotes.length,
        itemBuilder: (context, index) {
          final note = sampleNotes[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: ListTile(
              leading: Icon(_getIconForFormat(note['format']!), color: AppColors.primary),
              title: Text(note['title']!, style: AppTextStyles.chatTitle),
              subtitle: Text('${note['unit']} • Format: ${note['format']}\nUploaded by: ${note['uploader']}'),
              trailing: IconButton(
                icon: const Icon(Icons.file_download, color: AppColors.accent),
                onPressed: () {
                  _downloadFile(context, note['title']!);
                },
              ),
              onTap: () {
                _downloadFile(context, note['title']!);
              },
            ),
          );
        },
      ),
    );
  }

  IconData _getIconForFormat(String format) {
    switch (format.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'PPT':
        return Icons.slideshow;
      case 'DOCX':
      case 'WORD':
        return Icons.description;
      case 'TXT':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _downloadFile(BuildContext context, String fileName) {
    // In a real application, this is where you would use a package
    // like `dio` and `path_provider` to fetch the file URL from Firestore
    // and save it to the user's device.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Simulating download of $fileName...')),
    );
  }
}
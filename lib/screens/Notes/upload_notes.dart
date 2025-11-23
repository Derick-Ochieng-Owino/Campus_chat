import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../core/constants/campus_data.dart';// make sure this points to your CampusData file

class AdminUploadNotesPage extends StatefulWidget {
  const AdminUploadNotesPage({super.key});

  @override
  State<AdminUploadNotesPage> createState() => _AdminUploadNotesPageState();
}

class _AdminUploadNotesPageState extends State<AdminUploadNotesPage> {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? _userRole;
  String? _userName;
  String? _userId;

  List<String> _units = [];
  String? _selectedUnit;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initUserAndLoadUnits();
  }

  bool get _canUpload {
    final r = (_userRole ?? '').toLowerCase();
    return r == 'admin' || r == 'class_rep' || r == 'assistant' || r == 'classrep';
  }

  Future<void> _initUserAndLoadUnits() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    _userId = user.uid;

    // load user profile
    final doc = await _fs.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};

    _userRole = data['role'] ?? 'student';
    _userName = data['name'] ?? user.displayName ?? 'Unknown';

    final course = data['course'];
    final year = data['year_of_study'];
    final semester = data['semester'];

    if (course == null || year == null || semester == null) {
      setState(() => _loading = false);
      return;
    }

    // pull units dynamically from CampusData
    _units = CampusData.getUnits(course, year, semester).toList();

    setState(() => _loading = false);
  }

  Future<void> _pickAndUploadFile() async {
    if (!_canUpload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to upload.')),
      );
      return;
    }

    if (_selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit first.')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );

    if (result == null) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    final file = File(filePath);
    final originalName = result.files.single.name;
    final ext = path.extension(originalName).replaceFirst('.', '').toUpperCase();

    // Ask for custom title
    final title = await _askForTitle(initial: originalName);
    if (title == null) return;

    await _uploadFile(file, title, ext);
  }

  Future<String?> _askForTitle({required String initial}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Note Title"),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: "Enter title"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text("OK")),
        ],
      ),
    );
  }

  Future<void> _uploadFile(File file, String title, String ext) async {
    final unitId = _selectedUnit!;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
    final ref = _storage.ref().child('notes/$unitId/$fileName');

    double progress = 0.0;
    final uploadTask = ref.putFile(file);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) {
          uploadTask.snapshotEvents.listen((snapshot) {
            if (snapshot.totalBytes > 0) {
              setS(() => progress = snapshot.bytesTransferred / snapshot.totalBytes);
            }
          });

          return AlertDialog(
            title: const Text("Uploading..."),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 12),
                Text("${(progress * 100).toStringAsFixed(0)}%"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await uploadTask.cancel();
                  if (mounted) Navigator.pop(ctx2);
                },
                child: const Text("Cancel"),
              )
            ],
          );
        },
      ),
    );

    try {
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();

      // Save note to Firestore
      await _fs.collection('units').doc(unitId).collection('notes').add({
        "title": title,
        "url": url,
        "uploaderId": _userId,
        "uploaderName": _userName ?? '',
        "format": ext,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upload successful")),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Upload Notes")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_canUpload)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellow[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text("You do not have upload permissions."),
              ),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Unit",
                border: OutlineInputBorder(),
              ),
              items: _units
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              value: _selectedUnit,
              onChanged: (v) => setState(() => _selectedUnit = v),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text("Upload File"),
              onPressed: _canUpload ? _pickAndUploadFile : null,
            ),
          ],
        ),
      ),
    );
  }
}

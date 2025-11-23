import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'upload_notes.dart';

class UploadNotesButton extends StatefulWidget {
  const UploadNotesButton({super.key});

  @override
  State<UploadNotesButton> createState() => _UploadNotesButtonState();
}

class _UploadNotesButtonState extends State<UploadNotesButton> {
  bool _checking = true;
  bool _canUpload = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _checking = false;
        _canUpload = false;
      });
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final role = snap.data()?['role']?.toString().toLowerCase() ?? '';

    // allowed roles
    final allowed = ['admin', 'class_rep', 'assistant', 'classrep'];

    setState(() {
      _canUpload = allowed.contains(role);
      _checking = false;
    });
  }

  void _openUploadPage(BuildContext context) {
    if (!_canUpload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Permission denied. You can't upload notes."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminUploadNotesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const SizedBox(
        height: 40,
        width: 40,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return FloatingActionButton(
      backgroundColor: _canUpload ? Colors.blue : Colors.grey,
      onPressed: () => _openUploadPage(context),
      child: const Icon(Icons.upload),
    );
  }
}

// lib/screens/notes_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:campus_app/screens/Notes/upload_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/campus_data.dart';

// Replace with your app constants, or keep these minimal
class AppColors {
  static const Color primary = Colors.blue;
  static const Color accent = Colors.teal;
  static const Color background = Color(0xFFF6F6F6);
  static const Color lightGrey = Color(0xFFF0F0F0);
  static const Color chatBubble = Color(0xFFDDEEFF);
  static const Color secondary = Colors.deepPurple;
  static const Color darkGrey = Colors.grey;
}

// Minimal text styles
class AppTextStyles {
  static const TextStyle chatTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  static const TextStyle chatMessage = TextStyle(fontSize: 14);
}

// ---------------- Models ----------------

class Unit {
  final String id;
  final String name;
  final int year;
  final int semester;

  Unit({required this.id, required this.name, required this.year, required this.semester});

  factory Unit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Unit(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Unit',
      year: (data['year'] ?? 1) as int,
      semester: (data['semester'] ?? 1) as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'year': year,
    'semester': semester,
  };

  static Unit fromJsonMap(Map<String, dynamic> m) {
    return Unit(
      id: m['id'] as String,
      name: m['name'] as String,
      year: m['year'] as int,
      semester: m['semester'] as int,
    );
  }

  static String encodeList(List<Unit> units) => jsonEncode(units.map((u) => u.toJson()).toList());
  static List<Unit> decodeList(String encoded) {
    final list = jsonDecode(encoded) as List<dynamic>;
    return list.map((e) => Unit.fromJsonMap(e as Map<String, dynamic>)).toList();
  }
}

class Note {
  final String id;
  final String title;
  final String url;
  final String uploaderId;
  final String uploaderName;
  final String format;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    required this.url,
    required this.uploaderId,
    required this.uploaderName,
    required this.format,
    required this.createdAt,
  });

  factory Note.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Note(
      id: doc.id,
      title: d['title'] ?? 'Untitled',
      url: d['url'] ?? '',
      uploaderId: d['uploaderId'] ?? '',
      uploaderName: d['uploaderName'] ?? '',
      format: d['format'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ---------------- NotesScreen ----------------

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late Future<List<Unit>> futureUnits;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Dio _dio = Dio();
  final Map<String, double> _downloadProgress = {}; // noteId -> 0..1
  String? _currentUserRole;
  String? _currentUserName;
  String? _currentUserId;

  static const String _cacheKey = 'cachedUnits_v1';
  static const Duration _cacheMaxAge = Duration(hours: 24);

  @override
  void initState() {
    super.initState();
    futureUnits = _loadUnitsOnce();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    _currentUserId = user.uid;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        _currentUserRole = data['role'] as String?;
        _currentUserName = data['name'] as String? ?? user.displayName ?? 'Unknown';
      });
    }
  }

  Future<List<Unit>> _loadUnitsOnce() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return [];

    final data = doc.data()!;
    final String course = data['course'];
    final year = data['year_of_study'];
    final semester = data['semester'];

    // Pull units from CampusData
    final unitNames = CampusData.getUnits(course, year, semester);

    // Convert into your Unit model
    final units = unitNames.map((name) {
      return Unit(
        id: name,        // use name as ID
        name: name,
        year: year,
        semester: semester,
      );
    }).toList();

    return units;
  }


  bool _canUpload() {
    final r = _currentUserRole ?? '';
    return r == 'admin' || r == 'class_rep' || r == 'assistant';
  }

  IconData _getIconForFormat(String format) {
    switch (format.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'PPT':
      case 'PPTX':
        return Icons.slideshow;
      case 'DOCX':
      case 'DOC':
      case 'WORD':
        return Icons.description;
      case 'TXT':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _downloadNoteWithProgress(Note note) async {
    try {
      setState(() {
        _downloadProgress[note.id] = 0.0;
      });

      final dir = await getApplicationDocumentsDirectory();
      final ext = note.format.isNotEmpty ? '.${note.format.toLowerCase()}' : '';
      final safeTitle = note.title.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final savePath = '${dir.path}/$safeTitle$ext';

      await _dio.download(
        note.url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            setState(() {
              _downloadProgress[note.id] = progress;
            });
          }
        },
        options: Options(followRedirects: true, responseType: ResponseType.bytes),
      );

      setState(() {
        _downloadProgress.remove(note.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded "${note.title}" to $savePath')),
      );
    } catch (e) {
      setState(() {
        _downloadProgress.remove(note.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _uploadNoteToUnit(Unit unit) async {
    // Only allow if user can upload
    if (!_canUpload()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload permission denied')));
      return;
    }

    // Pick file
    final res = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (res == null || res.files.isEmpty) return;

    final file = File(res.files.single.path!);
    final originalName = res.files.single.name;
    final ext = originalName.split('.').length > 1 ? originalName.split('.').last : '';

    final titleController = TextEditingController(text: originalName);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            Text('Uploading to ${unit.name}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Upload')),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not logged in')));
      return;
    }

    final uploaderName = _currentUserName ?? user.displayName ?? 'Uploader';

    // Upload to Firebase Storage
    final storageRef = FirebaseStorage.instance.ref().child('notes/${unit.id}/${DateTime.now().millisecondsSinceEpoch}_${originalName}');
    final uploadTask = storageRef.putFile(file);

    // show upload progress dialog
    double progress = 0.0;
    final dialogKey = GlobalKey<State>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // listen in background
        uploadTask.snapshotEvents.listen((snap) {
          if (snap.totalBytes != 0) {
            progress = snap.bytesTransferred / snap.totalBytes;
            // rebuild via setState on the dialog by using StatefulBuilder
            // but easier: use Navigator.of(ctx).pop then reopen? Simpler approach: use StatefulBuilder below
          }
        });
        return StatefulBuilder(
          builder: (context, setS) {
            uploadTask.snapshotEvents.listen((snap) {
              if (snap.totalBytes != 0) {
                setS(() {
                  progress = snap.bytesTransferred / snap.totalBytes;
                });
              }
            });
            return AlertDialog(
              title: const Text('Uploading...'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 12),
                Text('${(progress * 100).toStringAsFixed(0)}%'),
              ]),
              actions: [
                TextButton(
                    onPressed: () {
                      // Cancel upload
                      uploadTask.cancel();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel')),
              ],
            );
          },
        );
      },
    );

    try {
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Create note document in Firestore under unit
      final noteDoc = _firestore.collection('units').doc(unit.id).collection('notes').doc();
      await noteDoc.set({
        'title': titleController.text,
        'url': downloadUrl,
        'uploaderId': user.uid,
        'uploaderName': uploaderName,
        'format': ext.toUpperCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // close upload dialog
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploaded successfully')));
    } catch (e) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${e.toString()}')));
    }
  }

  Widget _buildUnitTile(Unit unit) {
    // Each tile contains a real-time stream of notes for the unit
    final notesStream = _firestore.collection('units').doc(unit.id).collection('notes').orderBy('createdAt', descending: true).snapshots();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: ExpansionTile(
        title: Text(unit.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Year ${unit.year} • Semester ${unit.semester}'),
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: notesStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('No notes uploaded yet.'),
                );
              }

              return Column(
                children: docs.map((d) {
                  final note = Note.fromFirestore(d);
                  final progress = _downloadProgress[note.id];
                  return ListTile(
                    leading: Icon(_getIconForFormat(note.format)),
                    title: Text(note.title, style: AppTextStyles.chatTitle),
                    subtitle: Text('Uploaded by: ${note.uploaderName}\n${note.createdAt.toLocal()}'.split('.').first),
                    trailing: progress != null
                        ? SizedBox(
                      width: 64,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 6),
                          Text('${(progress * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                    )
                        : IconButton(
                      icon: const Icon(Icons.file_download, color: Colors.green),
                      onPressed: () => _downloadNoteWithProgress(note),
                    ),
                    onTap: () => _downloadNoteWithProgress(note),
                  );
                }).toList(),
              );
            },
          ),
          if (_canUpload())
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload note for this unit'),
                onPressed: () => _uploadNoteToUnit(unit),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Course Notes & Units'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // force refresh by clearing cache and reloading
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_cacheKey);
              await prefs.remove('${_cacheKey}_ts');
              setState(() {
                futureUnits = _loadUnitsOnce();
              });
            },
            tooltip: 'Force refresh',
          ),
        ],
      ),
      floatingActionButton: const UploadNotesButton(),
      body: FutureBuilder<List<Unit>>(
        future: futureUnits,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final units = snap.data ?? [];
          if (units.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'No units found for your year/semester.\nIf you think this is wrong, check your profile or contact admin.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.chatMessage,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: units.length,
            itemBuilder: (context, index) => _buildUnitTile(units[index]),
          );
        },
      ),
    );
  }
}

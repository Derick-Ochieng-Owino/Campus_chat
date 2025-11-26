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
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../models/note_model.dart';
import '../../models/unit_model.dart';
import '../Profile/complete_profile.dart';

// ------------------- NotesScreen -------------------
class NotesScreen extends StatefulWidget {
  final CampusData campusData; // Pass loaded CampusData

  const NotesScreen({super.key, required this.campusData});

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

  static const String _cacheKey = 'cachedUnits_v2';
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

  Future<List<Unit>> _loadUnitsOnce({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final tsStr = prefs.getString('${_cacheKey}_ts');
      if (tsStr != null) {
        final ts = DateTime.tryParse(tsStr);
        if (ts != null && DateTime.now().difference(ts) < _cacheMaxAge) {
          final cached = prefs.getString(_cacheKey);
          if (cached != null) return Unit.decodeList(cached);
        }
      }
    }

    final user = _auth.currentUser;
    if (user == null) return [];

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return [];

    final data = userDoc.data()!;
    final String? campus = data['campus'];
    final String? college = data['college'];
    final String? school = data['school'];
    final String? department = data['department'];
    final String? course = data['course'];
    final String? year = data['year_of_study'];
    final String? semester = data['semester'];

    if (campus == null || college == null || course == null || year == null || semester == null) return [];

    final unitsData = widget.campusData
        .campuses['campuses']?[campus]?['colleges']?[college]?['schools']?[school]?['departments']?[department]?['courses']?[course]?['years']?[year]?[semester];

    if (unitsData == null) return [];

    final units = (unitsData as List<dynamic>).map((u) {
      final map = u as Map<String, dynamic>;
      return Unit(
        id: map['code'] ?? map['title'],
        name: map['title'] ?? map['code'] ?? 'Untitled Unit',
        year: int.tryParse(year.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1,
        semester: int.tryParse(semester.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1,
      );
    }).toList();

    // Cache
    prefs.setString(_cacheKey, Unit.encodeList(units));
    prefs.setString('${_cacheKey}_ts', DateTime.now().toIso8601String());

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
      setState(() => _downloadProgress[note.id] = 0.0);

      final dir = await getApplicationDocumentsDirectory();
      final ext = note.format.isNotEmpty ? '.${note.format.toLowerCase()}' : '';
      final safeTitle = note.title.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final savePath = '${dir.path}/$safeTitle$ext';

      await _dio.download(
        note.url,
        savePath,
        onReceiveProgress: (rec, total) {
          if (total != -1) {
            setState(() => _downloadProgress[note.id] = rec / total);
          }
        },
        options: Options(followRedirects: true, responseType: ResponseType.bytes),
      );

      setState(() => _downloadProgress.remove(note.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded "${note.title}" to $savePath')),
      );
    } catch (e) {
      setState(() => _downloadProgress.remove(note.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Future<void> _uploadNoteToUnit(Unit unit) async {
    if (!_canUpload()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload permission denied')));
      return;
    }

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

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('notes/${unit.id}/${DateTime.now().millisecondsSinceEpoch}_$originalName');
    final uploadTask = storageRef.putFile(file);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setS) {
          uploadTask.snapshotEvents.listen((snap) {
            if (snap.totalBytes != 0) {
              setS(() {
                // progress 0..1
              });
            }
          });
          return AlertDialog(
            title: const Text('Uploading...'),
            content: StreamBuilder<TaskSnapshot>(
              stream: uploadTask.snapshotEvents,
              builder: (context, snapshot) {
                final prog = snapshot.data != null && snapshot.data!.totalBytes != 0
                    ? snapshot.data!.bytesTransferred / snapshot.data!.totalBytes
                    : 0.0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: prog),
                    const SizedBox(height: 12),
                    Text('${(prog * 100).toStringAsFixed(0)}%'),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    uploadTask.cancel();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel')),
            ],
          );
        },
      ),
    );

    try {
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final noteDoc = _firestore.collection('units').doc(unit.id).collection('notes').doc();
      await noteDoc.set({
        'title': titleController.text,
        'url': downloadUrl,
        'uploaderId': user.uid,
        'uploaderName': uploaderName,
        'format': ext.toUpperCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploaded successfully')));
    } catch (e) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Widget _buildUnitTile(Unit unit) {
    final notesStream = _firestore
        .collection('units')
        .doc(unit.id)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .snapshots();

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
                  final formattedDate = DateFormat.yMMMd().add_Hm().format(note.createdAt);
                  return ListTile(
                    leading: Icon(_getIconForFormat(note.format)),
                    title: Text(note.title, style: AppTextStyles.chatTitle),
                    subtitle: Text('Uploaded by: ${note.uploaderName}\n$formattedDate'),
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
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_cacheKey);
              await prefs.remove('${_cacheKey}_ts');
              setState(() {
                futureUnits = _loadUnitsOnce(forceRefresh: true);
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
                  'No units found for your profile.\nIf you think this is wrong, check your profile or contact admin.',
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

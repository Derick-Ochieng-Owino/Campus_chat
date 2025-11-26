import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

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

  // --- Color Mapping for File Types (UI Enhancement) ---
  Map<String, List<Color>> formatColors = {
    'PDF': [Colors.red.shade50, Colors.red.shade700],
    'PPT': [Colors.orange.shade50, Colors.orange.shade700],
    'PPTX': [Colors.orange.shade50, Colors.orange.shade700],
    'DOCX': [Colors.blue.shade50, Colors.blue.shade700],
    'DOC': [Colors.blue.shade50, Colors.blue.shade700],
    'TXT': [Colors.green.shade50, Colors.green.shade700],
  };

  @override
  void initState() {
    super.initState();
    futureUnits = _loadUnitsOnce();
    _loadUserProfile();
  }

  // --- Existing Logic (Unchanged) ---
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
    // [Existing SharedPreferences/Caching logic]
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

    // [Existing Firestore fetch logic]
    final user = _auth.currentUser;
    if (user == null) return [];

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return [];

    final data = doc.data()!;
    final List<dynamic> registeredUnits = data['registered_units'] ?? [];

    final yearKey = data['year_key'] ?? "year1";
    final semesterKey = data['semester_key'] ?? "semester1";

    final year = int.tryParse(yearKey.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final semester = int.tryParse(semesterKey.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

    return registeredUnits.map((u) {
      return Unit(
        id: u['code'],
        name: u['title'],
        year: year,
        semester: semester,
      );
    }).toList();
  }

  bool _canUpload() {
    final r = _currentUserRole ?? '';
    return r == 'admin' || r == 'class_rep' || r == 'assistant';
  }

  IconData _getIconForFormat(String format) {
    switch (format.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf_rounded;
      case 'PPT':
      case 'PPTX':
        return Icons.slideshow_rounded;
      case 'DOCX':
      case 'DOC':
      case 'WORD':
        return Icons.description_rounded;
      case 'TXT':
        return Icons.text_snippet_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
  // --- End Existing Logic ---

  Future<void> _downloadNoteWithProgress(Note note) async {
    // ... [Original _downloadNoteWithProgress logic] ...
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded "${note.title}" to $savePath')),
        );
      }
    } catch (e) {
      setState(() => _downloadProgress.remove(note.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Future<void> _downloadAndOpenNote(Note note) async {
    // ... [Original _downloadAndOpenNote logic] ...
    try {
      setState(() => _downloadProgress[note.id] = 0.0);

      if (kIsWeb) {
        // On web, just open the URL in a new tab
        if (!await launchUrl(Uri.parse(note.url), mode: LaunchMode.externalApplication)) {
          throw 'Could not open URL';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opened "${note.title}" in browser')),
          );
        }
      } else {
        // Mobile: download to device and open
        final dir = await getApplicationDocumentsDirectory();
        final ext = note.format.isNotEmpty ? '.${note.format.toLowerCase()}' : '';
        final safeTitle = note.title.replaceAll(RegExp(r'[^\w\s-]'), '_');
        final savePath = '${dir.path}/$safeTitle$ext';

        await Dio().download(
          note.url,
          savePath,
          onReceiveProgress: (rec, total) {
            if (total != -1) {
              setState(() => _downloadProgress[note.id] = rec / total);
            }
          },
        );

        setState(() => _downloadProgress.remove(note.id));

        await OpenFile.open(savePath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opened "${note.title}"')),
          );
        }
      }
    } catch (e) {
      setState(() => _downloadProgress.remove(note.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
      debugPrint("Error opening note: $e");
    }
  }


  Future<void> _uploadNoteToUnit(Unit unit) async {
    // ... [Original _uploadNoteToUnit logic, slightly cleaned up for modern flutter] ...
    final user = _auth.currentUser;
    if (user == null || !_canUpload()) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload permission denied or not logged in')));
      return;
    }

    final res = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (res == null || res.files.isEmpty) return;

    final file = kIsWeb ? res.files.single : File(res.files.single.path!);
    final originalName = res.files.single.name;

    final ext = originalName.contains('.') ? originalName.split('.').last : '';
    final titleController = TextEditingController(text: originalName.replaceAll(RegExp(r'\..*$'), '')); // Remove extension from default title

    // Show confirmation and title edit dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Upload'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unit: ${unit.name}'),
            Text('File Type: ${ext.toUpperCase()}'),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Note Title',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Upload'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed != true || titleController.text.trim().isEmpty) return;

    // --- Upload Logic ---
    try {
      final uploaderName = _currentUserName ?? user.displayName ?? 'Uploader';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('notes/${unit.id}/${DateTime.now().millisecondsSinceEpoch}_$originalName');

      final uploadTask = kIsWeb
          ? storageRef.putData(res.files.single.bytes!)
          : storageRef.putFile(file as File);

      // Show upload progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
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
                  LinearProgressIndicator(value: prog, color: Colors.blue.shade700),
                  const SizedBox(height: 12),
                  Text('${(prog * 100).toStringAsFixed(0)}% Uploaded'),
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
        ),
      );

      await uploadTask; // Wait for completion
      final downloadUrl = await storageRef.getDownloadURL();

      final noteDoc = _firestore.collection('units').doc(unit.id).collection('notes').doc();
      await noteDoc.set({
        'title': titleController.text.trim(),
        'url': downloadUrl,
        'uploaderId': user.uid,
        'uploaderName': uploaderName,
        'format': ext.toUpperCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note uploaded successfully!')));
      }
    } catch (e) {
      debugPrint('[DEBUG] Upload failed: $e');
      if (mounted) {
        // Pop any lingering dialogs
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: ${e.toString()}')));
      }
    }
  }


  // ------------------- UI Enhancement: Unit Tile -------------------
  Widget _buildUnitTile(Unit unit) {
    final notesStream = _firestore
        .collection('units')
        .doc(unit.id)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .snapshots();

    // Determine the color based on unit ID for consistent styling across units
    final hash = unit.id.length + unit.name.length;
    final colorIndex = hash % 4; // Use a small number of colors
    final unitColor = [Colors.indigo, Colors.teal, Colors.deepOrange, Colors.purple][colorIndex];


    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 4, // Lifted look
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: unitColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: unitColor.withOpacity(0.3)),
            ),
            child: Icon(Icons.menu_book_rounded, color: unitColor, size: 28),
          ),
          title: Text(unit.name, style: AppTextStyles.title.copyWith(color: Colors.black87)),
          subtitle: Text('${unit.id} | Year ${unit.year} • Sem ${unit.semester}', style: TextStyle(color: Colors.grey.shade600)),

          children: [
            const Divider(height: 1, thickness: 1),
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
                if (docs.isEmpty) return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No notes uploaded yet. Be the first to upload!', style: TextStyle(fontStyle: FontStyle.italic)),
                );

                return Column(
                  children: docs.map((d) => _buildNoteListItem(Note.fromFirestore(d))).toList(),
                );
              },
            ),

            // Upload Button
            if (_canUpload())
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                  label: const Text('Upload Note for this Unit', style: TextStyle(color: Colors.white)),
                  onPressed: () => _uploadNoteToUnit(unit),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: unitColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------- UI Enhancement: Note List Item -------------------
  Widget _buildNoteListItem(Note note) {
    final progress = _downloadProgress[note.id];
    final format = note.format.toUpperCase();

    // Get color scheme or fallback to a default grey/black
    final colors = formatColors[format] ?? [Colors.grey.shade100, Colors.black87];
    final icon = _getIconForFormat(format);

    return InkWell(
      onTap: () => _downloadAndOpenNote(note),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            // File Type Icon (Light BG/Dark Icon)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors[0],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: colors[1], size: 24),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${format} | By ${note.uploaderName}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            // Download/Progress Indicator
            SizedBox(
              width: 100,
              child: progress != null
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LinearProgressIndicator(value: progress, color: Colors.blue.shade500),
                  const SizedBox(height: 4),
                  Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10)),
                ],
              )
                  : IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.green),
                onPressed: () => _downloadAndOpenNote(note),
                tooltip: kIsWeb ? 'Open/View' : 'Download/Open',
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Use a very light grey background
      appBar: AppBar(
        title: const Text('Course Notes & Units', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary, // Dark primary color for AppBar
        foregroundColor: Colors.white,
        elevation: 0, // Flat app bar for modern look
        actions: [
          if (_canUpload())
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Chip(
                avatar: Icon(Icons.security, color: Colors.amber.shade900, size: 18),
                label: const Text('Uploader Role', style: TextStyle(fontSize: 12, color: Colors.black87)),
                backgroundColor: Colors.amber.shade100,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              // ... [Refresh Logic] ...
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_cacheKey);
              await prefs.remove('${_cacheKey}_ts');
              setState(() {
                futureUnits = _loadUnitsOnce(forceRefresh: true);
              });
            },
            tooltip: 'Force refresh units list',
          ),
        ],
      ),
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
                  style: AppTextStyles.title.copyWith(color: Colors.grey.shade700),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            itemCount: units.length,
            itemBuilder: (context, index) => _buildUnitTile(units[index]),
          );
        },
      ),
    );
  }
}

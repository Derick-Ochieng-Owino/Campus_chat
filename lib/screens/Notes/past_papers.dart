// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/note_model.dart';
import '../../models/unit_model.dart';
import '../Profile/complete_profile.dart';
import '../../widgets/loading_widget.dart';

class SampleScreen extends StatefulWidget {
  final UniversityData universityData; // Pass loaded CampusData

  const SampleScreen({super.key, required this.universityData});

  @override
  State<SampleScreen> createState() => _SampleScreenState();
}

class _SampleScreenState extends State<SampleScreen> with AutomaticKeepAliveClientMixin<SampleScreen>{
  @override
  bool get wantKeepAlive => true;

  late Future<List<Unit>> futureUnits;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, double> _downloadProgress = {}; // noteId -> 0..1
  String? _currentUserRole;
  String? _currentUserName;
  String? _currentUserId;
  static const String _cacheKey = 'cachedSamples_v2';
  static const Duration _cacheMaxAge = Duration(hours: 24);

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

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    _currentUserId = user.uid;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null && mounted) {
      setState(() {
        _currentUserRole = data['role'] as String?;
        _currentUserName =
            data['name'] as String? ?? user.displayName ?? 'Unknown';
      });
    }
  }

  Future<List<Unit>> _loadUnitsOnce({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final tsStr = prefs.getString('${_cacheKey}_ts');
      final cachedData = prefs.getString(_cacheKey);
      if (cachedData != null && tsStr != null) {
        final ts = DateTime.tryParse(tsStr);
        if (ts != null && DateTime.now().difference(ts) < _cacheMaxAge) {
          try {
            return Unit.decodeList(cachedData);
          } catch (_) {}
        }
      }
    }

    final user = _auth.currentUser;
    if (user == null) return [];

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return [];

    final data = doc.data()!;
    final List<dynamic> registeredUnits = data['registered_units'] ?? [];
    final year = data['year'] ?? "1";
    final semester = data['semester'] ?? "1";
    final currentyear = int.tryParse(year.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final currentsemester =
        int.tryParse(semester.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

    final units = registeredUnits
        .map((u) => Unit(
      id: u['code'],
      name: u['title'],
      year: currentyear,
      semester: currentsemester,
    ))
        .toList();

    await prefs.setString(_cacheKey, Unit.encodeList(units));
    await prefs.setString('${_cacheKey}_ts', DateTime.now().toIso8601String());

    return units;
  }

  bool _canUpload() {
    final r = _currentUserRole ?? '';
    return r == 'admin' || r == 'class_rep' || r == 'assistant';
  }

  bool _isAdmin() {
    return _currentUserRole == 'admin';
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

  Future<void> _downloadAndOpenNote(Note note) async {
    try {
      setState(() => _downloadProgress[note.id] = 0.0);

      if (kIsWeb) {
        if (!await launchUrl(Uri.parse(note.url),
            mode: LaunchMode.externalApplication)) {
          throw 'Could not open URL';
        }
      } else {
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

        await OpenFile.open(savePath);
      }

      if (mounted) setState(() => _downloadProgress.remove(note.id));
    } catch (e) {
      setState(() => _downloadProgress.remove(note.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
      }
    }
  }

  Future<bool> _checkDuplicateNote(String unitId, String title, String format) async {
    try {
      final querySnapshot = await _firestore
          .collection('units')
          .doc(unitId)
          .collection('notes')
          .where('title', isEqualTo: title.trim())
          .where('format', isEqualTo: format.toUpperCase())
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking duplicate: $e');
      return false;
    }
  }

  Future<void> _uploadNoteToUnit(Unit unit) async {
    final user = _auth.currentUser;
    if (user == null || !_canUpload()) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload permission denied')));
      }
      return;
    }

    final res = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (res == null || res.files.isEmpty) return;

    final file = kIsWeb ? res.files.single : File(res.files.single.path!);
    final originalName = res.files.single.name;
    final ext = originalName.contains('.') ? originalName.split('.').last : '';
    final titleController =
    TextEditingController(text: originalName.replaceAll(RegExp(r'\..*$'), ''));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Upload'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
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
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Upload'))
        ],
      ),
    );

    if (confirmed != true || titleController.text.trim().isEmpty) return;

    // Check for duplicate note
    final isDuplicate = await _checkDuplicateNote(
        unit.id,
        titleController.text.trim(),
        ext.toUpperCase()
    );

    if (isDuplicate && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Note "${titleController.text.trim()}" already exists in ${unit.name}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      final uploaderName = _currentUserName ?? user.displayName ?? 'Uploader';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('notes/${unit.id}/${DateTime.now().millisecondsSinceEpoch}_$originalName');

      final uploadTask = kIsWeb
          ? storageRef.putData(res.files.single.bytes!)
          : storageRef.putFile(file as File);

      await uploadTask;
      final downloadUrl = await storageRef.getDownloadURL();

      final noteDoc = _firestore
          .collection('units')
          .doc(unit.id)
          .collection('notes')
          .doc();
      await noteDoc.set({
        'title': titleController.text.trim(),
        'url': downloadUrl,
        'uploaderId': user.uid,
        'uploaderName': uploaderName,
        'format': ext.toUpperCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create new announcement for the uploaded note
      final announcementDoc = _firestore.collection('announcements').doc();
      await announcementDoc.set({
        'attachment_name': titleController.text.trim(),
        'attachment_url': downloadUrl,
        'author_id': user.uid,
        'author_name': uploaderName,
        'created_at': FieldValue.serverTimestamp(),
        'description': 'New study material uploaded for ${unit.name}',
        'title': 'New Note: ${titleController.text.trim()}',
        'type': 'Notes',
        'unit_id': unit.id,
        'unit_name': unit.name,
        'format': ext.toUpperCase(),
        'target_date': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note uploaded successfully!')),
      );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
      }
    }
  }

  Future<void> _deleteNote(Note note, String unitId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete from Firestore
      await _firestore
          .collection('units')
          .doc(unitId)
          .collection('notes')
          .doc(note.id)
          .delete();

      // Delete from Storage
      final ref = FirebaseStorage.instance.refFromURL(note.url);
      await ref.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note "${note.title}" deleted successfully')),
      );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
      }
    }
  }

  Widget _buildUnitTile(Unit unit) {
    final theme = Theme.of(context);
    final notesStream = _firestore
        .collection('units')
        .doc(unit.id)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .snapshots();

    final hash = unit.id.length + unit.name.length;
    final colorIndex = hash % 4;
    final unitColor = [
      theme.colorScheme.secondary,
      theme.colorScheme.primary,
      Colors.orange,
      Colors.indigo
    ][colorIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: theme.cardColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ExpansionTile(
          tilePadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: unitColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: unitColor.withOpacity(0.3)),
            ),
            child: Icon(Icons.menu_book_rounded, color: unitColor, size: 28),
          ),
          title: Text(unit.name,
              style: theme.textTheme.titleMedium!
                  .copyWith(fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${unit.id} | Year ${unit.year} • Sem ${unit.semester}',
              style: theme.textTheme.bodySmall),
          children: [
            _NotesCacheStreamManager(
              notesStream: notesStream,
              unitId: unit.id,
              buildNoteListItem: _buildNoteListItem,
              canUpload: _canUpload(),
              onUpload: () => _uploadNoteToUnit(unit),
              isAdmin: _isAdmin(),
              onDeleteNote: (note) => _deleteNote(note, unit.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteListItem(Note note, {required bool isAdmin, required VoidCallback onDelete}) {
    final theme = Theme.of(context);
    final progress = _downloadProgress[note.id];
    final format = note.format.toUpperCase();
    final colors = formatColors[format] ?? [Colors.grey.shade100, Colors.black87];
    final icon = _getIconForFormat(format);
    final accentBgColor =
    theme.brightness == Brightness.dark ? colors[1].withOpacity(0.15) : colors[0];
    final accentIconColor = theme.brightness == Brightness.dark ? colors[1] : colors[1];

    return InkWell(
      onTap: () => _downloadAndOpenNote(note),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accentIconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.title,
                      style: theme.textTheme.bodyMedium!
                          .copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${format} | By ${note.uploaderName}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (isAdmin) ...[
              IconButton(
                icon: Icon(Icons.delete_rounded, color: Colors.red.shade400),
                onPressed: () => onDelete(),
                tooltip: 'Delete Note',
              ),
              const SizedBox(width: 8),
            ],
            SizedBox(
              width: isAdmin ? 60 : 100,
              child: progress != null
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: 4),
                  Text('${(progress * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall!
                          .copyWith(fontSize: 10)),
                ],
              )
                  : IconButton(
                icon: Icon(Icons.download_rounded,
                    color: theme.colorScheme.secondary),
                onPressed: () => _downloadAndOpenNote(note),
                tooltip: 'Download',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Course Notes & Units', style: theme.appBarTheme.titleTextStyle),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: theme.appBarTheme.elevation,
        actions: [
          if (_canUpload())
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Chip(
                avatar: Icon(Icons.security,
                    color: theme.colorScheme.secondary, size: 18),
                label: Text('Uploader Role', style: theme.textTheme.bodySmall),
                backgroundColor: theme.colorScheme.secondaryContainer,
              ),
            ),
          if (_isAdmin())
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Chip(
                avatar: Icon(Icons.admin_panel_settings,
                    color: Colors.red.shade400, size: 18),
                label: Text('Admin', style: theme.textTheme.bodySmall),
                backgroundColor: Colors.red.shade50,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_cacheKey);
              await prefs.remove('${_cacheKey}_ts');
              setState(() {
                futureUnits = _loadUnitsOnce(forceRefresh: true);
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Unit>>(
        future: futureUnits,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: AppLogoLoadingWidget(size: 80));
          }
          final units = snap.data ?? [];
          if (units.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'No units found for your profile.\nCheck profile or contact admin.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium!
                      .copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
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

/// Stream & Cache manager for notes per unit
class _NotesCacheStreamManager extends StatefulWidget {
  final Stream<QuerySnapshot> notesStream;
  final String unitId;
  final Widget Function(Note note, {required bool isAdmin, required VoidCallback onDelete}) buildNoteListItem;
  final bool canUpload;
  final VoidCallback onUpload;
  final bool isAdmin;
  final Function(Note note) onDeleteNote;

  const _NotesCacheStreamManager({
    required this.notesStream,
    required this.unitId,
    required this.buildNoteListItem,
    required this.canUpload,
    required this.onUpload,
    required this.isAdmin,
    required this.onDeleteNote,
  });

  @override
  State<_NotesCacheStreamManager> createState() => __NotesCacheStreamManagerState();
}

class __NotesCacheStreamManagerState extends State<_NotesCacheStreamManager> {
  List<Note>? _cachedNotes;
  static const String _cacheNotesPrefix = 'cachedNotes_';

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_cacheNotesPrefix + widget.unitId);

    if (cachedData != null && mounted) {
      try {
        final List<dynamic> list = jsonDecode(cachedData);
        setState(() {
          _cachedNotes = list.map((e) => Note.fromJson(e)).toList();
        });
      } catch (e) {
        debugPrint('Error decoding notes cache: $e');
        _cachedNotes = null;
      }
    }
  }

  Future<void> _saveCache(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(notes.map((n) => n.toMap()).toList());
    await prefs.setString(_cacheNotesPrefix + widget.unitId, jsonString);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: widget.notesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              if (_cachedNotes != null) return _buildNoteList(_cachedNotes!);
              return buildNoteShimmer(context, count: 4);
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              _saveCache([]);
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('No notes uploaded yet.',
                    style: theme.textTheme.bodyMedium!.copyWith(
                        fontStyle: FontStyle.italic)),
              );
            }

            final liveNotes = docs.map((d) => Note.fromFirestore(d)).toList();
            _saveCache(liveNotes);
            return _buildNoteList(liveNotes);
          },
        ),
        if (widget.canUpload)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: widget.onUpload,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload Note'),
            ),
          ),
      ],
    );
  }

  Widget _buildNoteList(List<Note> notes) {
    return Column(
      children: notes.map((note) => widget.buildNoteListItem(
        note,
        isAdmin: widget.isAdmin,
        onDelete: () => widget.onDeleteNote(note),
      )).toList(),
    );
  }

  Widget buildNoteShimmer(BuildContext context, {int count = 3}) {
    return Column(
      children: List.generate(
        count,
            (index) => Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}
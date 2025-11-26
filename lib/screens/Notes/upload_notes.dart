import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class AdminUploadNotesPage extends StatefulWidget {
  final String campusJson;
  const AdminUploadNotesPage({super.key, required this.campusJson});

  @override
  State<AdminUploadNotesPage> createState() => _AdminUploadNotesPageState();
}

class _AdminUploadNotesPageState extends State<AdminUploadNotesPage> {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic> campusData = {};
  String? _selectedCampus, _selectedCollege, _selectedSchool, _selectedDept, _selectedCourse, _selectedYear, _selectedSem;
  List<Map<String, dynamic>> _units = [];
  Map<String, String?> _selectedUnitMap = {};

  bool _loading = true;
  String? _userRole;
  String? _userName;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    campusData = jsonDecode(widget.campusJson)['campuses'] ?? {};
    final user = _auth.currentUser;
    if (user != null) {
      _userId = user.uid;
      final doc = await _fs.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      _userRole = data['role'] ?? 'student';
      _userName = data['name'] ?? user.displayName ?? 'Unknown';
    }
    setState(() => _loading = false);
  }

  bool get _canUpload => (_userRole ?? '').toLowerCase().contains('admin') || (_userRole ?? '').toLowerCase().contains('rep');

  List<String> _getColleges() => campusData[_selectedCampus]?['colleges']?.keys.cast<String>().toList() ?? [];
  List<String> _getSchools() => campusData[_selectedCampus]?['colleges'][_selectedCollege]?['schools']?.keys.cast<String>().toList() ?? [];
  List<String> _getDepartments() => campusData[_selectedCampus]?['colleges'][_selectedCollege]?['schools'][_selectedSchool]?['departments']?.keys.cast<String>().toList() ?? [];
  List<String> _getCourses() => campusData[_selectedCampus]?['colleges'][_selectedCollege]?['schools'][_selectedSchool]?['departments'][_selectedDept]?['courses']?.keys.cast<String>().toList() ?? [];
  List<String> _getYears() => campusData[_selectedCampus]?['colleges'][_selectedCollege]?['schools'][_selectedSchool]?['departments'][_selectedDept]?['courses'][_selectedCourse]?['years']?.keys.cast<String>().toList() ?? [];
  List<String> _getSemesters() => campusData[_selectedCampus]?['colleges'][_selectedCollege]?['schools'][_selectedSchool]?['departments'][_selectedDept]?['courses'][_selectedCourse]?['years'][_selectedYear]?.keys.cast<String>().toList() ?? [];
  List<Map<String, dynamic>> _getUnits() => (campusData[_selectedCampus]?['colleges'][_selectedCollege]?['schools'][_selectedSchool]?['departments'][_selectedDept]?['courses'][_selectedCourse]?['years'][_selectedYear]?[_selectedSem] ?? []).cast<Map<String, dynamic>>();

  Future<void> _pickAndUploadNote() async {
    if (!_canUpload) return;
    if (_selectedUnitMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a unit first")));
      return;
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
    if (result == null) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;
    final file = File(filePath);
    final title = result.files.single.name;

    final bytes = await file.readAsBytes();
    final base64Content = base64Encode(bytes);
    final ext = path.extension(filePath).replaceFirst('.', '').toUpperCase();

    // Save to Firestore under the proper path
    final unitCode = _selectedUnitMap['code']!;
    final docRef = _fs
        .collection('campuses')
        .doc(_selectedCampus)
        .collection('colleges')
        .doc(_selectedCollege)
        .collection('schools')
        .doc(_selectedSchool)
        .collection('departments')
        .doc(_selectedDept)
        .collection('courses')
        .doc(_selectedCourse)
        .collection('years')
        .doc(_selectedYear)
        .collection('semesters')
        .doc(_selectedSem)
        .collection('units')
        .doc(unitCode)
        .collection('notes')
        .doc();

    await docRef.set({
      "title": title,
      "fileBase64": base64Content,
      "format": ext,
      "uploadedAt": FieldValue.serverTimestamp(),
      "uploadedById": _userId,
      "uploadedByName": _userName,
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Note uploaded to Firestore!")));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Upload Notes")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCampus,
              decoration: const InputDecoration(labelText: "Campus"),
              items: campusData.keys.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedCampus = v;
                  _selectedCollege = null;
                  _selectedSchool = null;
                  _selectedDept = null;
                  _selectedCourse = null;
                  _selectedYear = null;
                  _selectedSem = null;
                  _units = [];
                  _selectedUnitMap = {};
                });
              },
            ),
            DropdownButtonFormField<String>(
              value: _selectedCollege,
              decoration: const InputDecoration(labelText: "College"),
              items: _getColleges().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedCollege = v;
                  _selectedSchool = null;
                  _selectedDept = null;
                  _selectedCourse = null;
                  _selectedYear = null;
                  _selectedSem = null;
                  _units = [];
                  _selectedUnitMap = {};
                });
              },
            ),
            DropdownButtonFormField<String>(
              value: _selectedSchool,
              decoration: const InputDecoration(labelText: "School"),
              items: _getSchools().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedSchool = v;
                  _selectedDept = null;
                  _selectedCourse = null;
                  _selectedYear = null;
                  _selectedSem = null;
                  _units = [];
                  _selectedUnitMap = {};
                });
              },
            ),
            DropdownButtonFormField<String>(
              value: _selectedDept,
              decoration: const InputDecoration(labelText: "Department"),
              items: _getDepartments().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedDept = v;
                  _selectedCourse = null;
                  _selectedYear = null;
                  _selectedSem = null;
                  _units = [];
                  _selectedUnitMap = {};
                });
              },
            ),
            DropdownButtonFormField<String>(
              value: _selectedCourse,
              decoration: const InputDecoration(labelText: "Course"),
              items: _getCourses().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedCourse = v;
                  _selectedYear = null;
                  _selectedSem = null;
                  _units = [];
                  _selectedUnitMap = {};
                });
              },
            ),
            DropdownButtonFormField<String>(
              value: _selectedYear,
              decoration: const InputDecoration(labelText: "Year"),
              items: _getYears().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedYear = v;
                  _selectedSem = null;
                  _units = [];
                  _selectedUnitMap = {};
                });
              },
            ),
            DropdownButtonFormField<String>(
              value: _selectedSem,
              decoration: const InputDecoration(labelText: "Semester"),
              items: _getSemesters().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedSem = v;
                  _units = _getUnits();
                  if (_units.isNotEmpty) {
                    _selectedUnitMap = Map<String, String?>.from(_units.first);
                  }

                });
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _canUpload && _selectedUnitMap.isNotEmpty ? _pickAndUploadNote : null,
              child: const Text("Upload Note to Firestore"),
            ),
          ],
        ),
      ),
    );
  }
}

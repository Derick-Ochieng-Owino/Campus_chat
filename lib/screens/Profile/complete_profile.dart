// lib/screens/Profile/complete_profile.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import '../../core/constants/colors.dart'; // No longer needed
import '../home/home_screen.dart';

// [CampusData class remains unchanged]
class CampusData {
  final Map<String, dynamic> campuses;

  CampusData({required this.campuses});

  factory CampusData.fromJsonString(String jsonString) {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return CampusData(
        campuses: map['campuses'] as Map<String, dynamic>,
      );
    } catch (e) {
      return CampusData(campuses: {});
    }
  }

  List<String> getCampuses() {
    return campuses.keys.toList();
  }

  List<String> getColleges(String campus) {
    final c = campuses[campus]?['colleges'] as Map<String, dynamic>?;
    return c?.keys.toList() ?? [];
  }

  List<String> getSchools(String campus, String college) {
    final s = campuses[campus]?['colleges']?[college]?['schools'] as Map<String, dynamic>?;
    return s?.keys.toList() ?? [];
  }

  List<String> getDepartments(String campus, String college, String school) {
    final d = campuses[campus]?['colleges']?[college]?['schools']?[school]?['departments'] as Map<String, dynamic>?;
    return d?.keys.toList() ?? [];
  }

  List<String> getCourses(String campus, String college, String school, String dept) {
    final courses = campuses[campus]?['colleges']?[college]?['schools']?[school]?['departments']?[dept]?['courses'] as Map<String, dynamic>?;
    return courses?.keys.toList() ?? [];
  }

  List<String> getYears(String campus, String college, String school, String dept, String course) {
    final years = campuses[campus]?['colleges']?[college]?['schools']?[school]?['departments']?[dept]?['courses']?[course]?['years'] as Map<String, dynamic>?;
    return years?.keys.toList() ?? [];
  }

  List<String> getSemesters(String campus, String college, String school, String dept, String course, String yearKey) {
    final sems = campuses[campus]?['colleges']?[college]?['schools']?[school]?['departments']?[dept]?['courses']?[course]?['years']?[yearKey] as Map<String, dynamic>?;
    return sems?.keys.toList() ?? [];
  }

  List<Map<String, dynamic>> getUnits(String campus, String college, String school, String dept, String course, String yearKey, String semesterKey) {
    final items = campuses[campus]?['colleges']?[college]?['schools']?[school]?['departments']?[dept]?['courses']?[course]?['years']?[yearKey]?[semesterKey];
    if (items == null) return [];
    try {
      return List<Map<String, dynamic>>.from((items as List).map((e) => Map<String, dynamic>.from(e)));
    } catch (_) {
      return [];
    }
  }
}


/// CompleteProfilePage that uses the embedded JSON and writes the selected profile into Firestore
class CompleteProfilePage extends StatefulWidget {
  final CampusData campusData;
  const CompleteProfilePage({super.key, required this.campusData});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final CampusData _campusData;

  bool _isLoading = false;

  String? _selectedCampus;
  String? _selectedCollege;
  String? _selectedSchool;
  String? _selectedDept;
  String? _selectedCourse;
  String? _selectedYearKey; // e.g. "year1"
  String? _selectedSemesterKey; // e.g. "semester1"

  List<String> _colleges = [];
  List<String> _schools = [];
  List<String> _departments = [];
  List<String> _courses = [];
  List<String> _years = [];
  List<String> _semesters = [];


  @override
  void initState() {
    super.initState();
    _campusData = widget.campusData;
  }

  // --- Dropdown callbacks (unchanged) ---
  void _onCampusChanged(String? campus) {
    setState(() {
      _selectedCampus = campus;
      _selectedCollege = null;
      _selectedSchool = null;
      _selectedDept = null;
      _selectedCourse = null;
      _selectedYearKey = null;
      _selectedSemesterKey = null;

      _colleges = campus == null ? [] : _campusData.getColleges(campus);
      _schools = [];
      _departments = [];
      _courses = [];
      _years = [];
      _semesters = [];
    });
  }

  void _onCollegeChanged(String? college) {
    if (_selectedCampus == null) return;
    setState(() {
      _selectedCollege = college;
      _selectedSchool = null;
      _selectedDept = null;
      _selectedCourse = null;
      _selectedYearKey = null;
      _selectedSemesterKey = null;

      _schools = (college == null) ? [] : _campusData.getSchools(_selectedCampus!, college);
      _departments = [];
      _courses = [];
      _years = [];
      _semesters = [];
    });
  }

  void _onSchoolChanged(String? school) {
    if (_selectedCampus == null || _selectedCollege == null) return;
    setState(() {
      _selectedSchool = school;
      _selectedDept = null;
      _selectedCourse = null;
      _selectedYearKey = null;
      _selectedSemesterKey = null;

      _departments = (school == null) ? [] : _campusData.getDepartments(_selectedCampus!, _selectedCollege!, school);
      _courses = [];
      _years = [];
      _semesters = [];
    });
  }

  void _onDeptChanged(String? dept) {
    if (_selectedCampus == null || _selectedCollege == null || _selectedSchool == null) return;
    setState(() {
      _selectedDept = dept;
      _selectedCourse = null;
      _selectedYearKey = null;
      _selectedSemesterKey = null;

      _courses = (dept == null) ? [] : _campusData.getCourses(_selectedCampus!, _selectedCollege!, _selectedSchool!, dept);
      _years = [];
      _semesters = [];
    });
  }

  void _onCourseChanged(String? course) {
    if (_selectedCampus == null || _selectedCollege == null || _selectedSchool == null || _selectedDept == null) return;
    setState(() {
      _selectedCourse = course;
      _selectedYearKey = null;
      _selectedSemesterKey = null;

      _years = (course == null) ? [] : _campusData.getYears(_selectedCampus!, _selectedCollege!, _selectedSchool!, _selectedDept!, course);
      _semesters = [];
    });
  }

  void _onYearChanged(String? yearKey) {
    if (_selectedCampus == null || _selectedCollege == null || _selectedSchool == null || _selectedDept == null || _selectedCourse == null) return;
    setState(() {
      _selectedYearKey = yearKey;
      _selectedSemesterKey = null;

      _semesters = (yearKey == null) ? [] : _campusData.getSemesters(_selectedCampus!, _selectedCollege!, _selectedSchool!, _selectedDept!, _selectedCourse!, yearKey);
    });
  }

  /// Save profile: collects selected units and writes user doc
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_selectedCampus == null ||
        _selectedCollege == null ||
        _selectedSchool == null ||
        _selectedDept == null ||
        _selectedCourse == null ||
        _selectedYearKey == null ||
        _selectedSemesterKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Please complete all fields'), backgroundColor: colorScheme.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No logged in user');

      final units = _campusData.getUnits(
        _selectedCampus!,
        _selectedCollege!,
        _selectedSchool!,
        _selectedDept!,
        _selectedCourse!,
        _selectedYearKey!,
        _selectedSemesterKey!,
      );

      // Save user doc: store course/year/semester as the raw keys (you can map them in client)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'profile_completed': true,
        'campus': _selectedCampus,
        'college': _selectedCollege,
        'school': _selectedSchool,
        'department': _selectedDept,
        'course': _selectedCourse,
        'year_key': _selectedYearKey,
        'semester_key': _selectedSemesterKey,
        'registered_units': units, // list of {code, title, type}
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Profile updated'), backgroundColor: colorScheme.primary));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: colorScheme.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // UI helper: present friendly label for yearKey e.g. "year1" -> "Year 1"
  String _displayYear(String key) {
    final match = RegExp(r'\d+').firstMatch(key);
    return match != null ? 'Year ${match.group(0)}' : key;
  }

  // UI helper: "semester1" -> "Semester 1"
  String _displaySemester(String key) {
    final match = RegExp(r'\d+').firstMatch(key);
    return match != null ? 'Semester ${match.group(0)}' : key;
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    required IconData icon,
    String Function(String)? itemLabel,
  }) {
    // Define theme inside the helper widget
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use text theme for consistency
        Text(label, style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface.withOpacity(0.8))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(itemLabel?.call(e) ?? e, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: items.isEmpty ? null : onChanged,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: colorScheme.primary), // Dynamic Primary Icon Color
            // NOTE: The InputDecorationTheme (filled, fillColor, borders) handles the rest
          ),
          validator: (v) => v == null ? 'Required' : null,
          dropdownColor: theme.cardColor, // Use dynamic card color for dropdown background
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final selectedUnits = (_selectedCampus != null && _selectedCollege != null && _selectedSchool != null && _selectedDept != null && _selectedCourse != null && _selectedYearKey != null && _selectedSemesterKey != null)
        ? _campusData.getUnits(_selectedCampus!, _selectedCollege!, _selectedSchool!, _selectedDept!, _selectedCourse!, _selectedYearKey!, _selectedSemesterKey!)
        : [];

    final campuses = _campusData.getCampuses();

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Stack(
            children: [
              // --- Header Gradient ---
              Container(
                height: size.height * 0.4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight
                  ),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // --- Header Text ---
                      Text('Complete Profile', style: theme.textTheme.headlineSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(
                          'We need a few details to set up your portal',
                          style: theme.textTheme.bodyMedium!.copyWith(color: Colors.white70)
                      ),
                      const SizedBox(height: 30),
                      Card(
                        elevation: 8,
                        color: theme.cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Dropdowns
                                _buildDropdown(label: 'Campus', value: _selectedCampus ?? (campuses.isNotEmpty ? campuses.first : null), items: campuses, onChanged: (v) { _onCampusChanged(v); }, icon: Icons.location_city),
                                _buildDropdown(label: 'College', value: _selectedCollege, items: _colleges, onChanged: _onCollegeChanged, icon: Icons.account_balance),
                                _buildDropdown(label: 'School', value: _selectedSchool, items: _schools, onChanged: _onSchoolChanged, icon: Icons.business),
                                _buildDropdown(label: 'Department', value: _selectedDept, items: _departments, onChanged: _onDeptChanged, icon: Icons.category),
                                _buildDropdown(label: 'Course', value: _selectedCourse, items: _courses, onChanged: _onCourseChanged, icon: Icons.book),
                                Row(
                                  children: [
                                    Expanded(child: _buildDropdown(label: 'Year', value: _selectedYearKey, items: _years, onChanged: (v) => _onYearChanged(v), icon: Icons.calendar_today, itemLabel: _displayYear)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildDropdown(label: 'Semester', value: _selectedSemesterKey, items: _semesters, onChanged: (v) => setState(() => _selectedSemesterKey = v), icon: Icons.timeline, itemLabel: _displaySemester)),
                                  ],
                                ),

                                // Units Info Box
                                if (selectedUnits.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: colorScheme.primary.withOpacity(0.5))
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: colorScheme.primary),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(
                                            'Saving will register you for ${selectedUnits.length} units.',
                                            style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)
                                        )),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 32),

                                // Save Button
                                SizedBox(
                                  width: double.infinity,
                                  child: _isLoading
                                      ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                                      : ElevatedButton(
                                    onPressed: _saveProfile,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                    child: Text('FINISH & VIEW UNITS', style: theme.textTheme.labelLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onPrimary)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
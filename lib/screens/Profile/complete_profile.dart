import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'personal_details.dart';

class UniversityData {
  final Map<String, dynamic> universities;

  UniversityData({required this.universities});

  factory UniversityData.fromJsonString(String jsonString) {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return UniversityData(
        universities: map['universities'] as Map<String, dynamic>,
      );
    } catch (e) {
      return UniversityData(universities: {});
    }
  }

  List<String> getUniversities() {
    return universities.keys.toList();
  }

  List<String> getCampuses(String university) {
    final c = universities[university]?['campuses'] as Map<String, dynamic>?;
    return c?.keys.toList() ?? [];
  }

  List<String> getColleges(String university, String campus) {
    final c = universities[university]?['campuses']?[campus]?['colleges'] as Map<String, dynamic>?;
    return c?.keys.toList() ?? [];
  }

  List<String> getSchools(String university, String campus, String college) {
    final s = universities[university]?['campuses']?[campus]?['colleges']?[college]?['schools'] as Map<String, dynamic>?;
    return s?.keys.toList() ?? [];
  }

  List<String> getDepartments(String university, String campus, String college, String school) {
    final d = universities[university]?['campuses']?[campus]?['colleges']?[college]?['schools']?[school]?['departments'] as Map<String, dynamic>?;
    return d?.keys.toList() ?? [];
  }

  List<String> getCourses(String university, String campus, String college, String school, String dept) {
    final courses = universities[university]?['campuses']?[campus]?['colleges']?[college]?['schools']?[school]?['departments']?[dept]?['courses'] as Map<String, dynamic>?;
    return courses?.keys.toList() ?? [];
  }

  List<String> getYears(String university, String campus, String college, String school, String dept, String course) {
    final years = universities[university]?['campuses']?[campus]?['colleges']?[college]?['schools']?[school]?['departments']?[dept]?['courses']?[course]?['years'] as Map<String, dynamic>?;
    return years?.keys.toList() ?? [];
  }

  List<String> getSemesters(String university, String campus, String college, String school, String dept, String course, String yearKey) {
    final sems = universities[university]?['campuses']?[campus]?['colleges']?[college]?['schools']?[school]?['departments']?[dept]?['courses']?[course]?['years']?[yearKey] as Map<String, dynamic>?;
    return sems?.keys.toList() ?? [];
  }

  List<Map<String, dynamic>> getUnits(String university, String campus, String college, String school, String dept, String course, String yearKey, String semesterKey) {
    final items = universities[university]?['campuses']?[campus]?['colleges']?[college]?['schools']?[school]?['departments']?[dept]?['courses']?[course]?['years']?[yearKey]?[semesterKey];
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
  final UniversityData universityData;
  const CompleteProfilePage({super.key, required this.universityData});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final UniversityData _universityData;

  bool _isLoading = false;

  String? _selectedUniversity;
  String? _selectedCampus;
  String? _selectedCollege;
  String? _selectedSchool;
  String? _selectedDept;
  String? _selectedCourse;
  String? _selectedYearKey; // e.g. "year1"
  String? _selectedSemesterKey; // e.g. "semester1"

  List<String> _universities = [];
  List<String> _campuses = [];
  List<String> _colleges = [];
  List<String> _schools = [];
  List<String> _departments = [];
  List<String> _courses = [];
  List<String> _years = [];
  List<String> _semesters = [];


  @override
  void initState() {
    super.initState();
    _universityData = widget.universityData;
    _universities = _universityData.getUniversities();
  }

  Future<void> _navigateToPersonalDetails() async {
    if (!_formKey.currentState!.validate()) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_selectedUniversity == null ||
        _selectedCampus == null ||
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
      final units = _universityData.getUnits(
        _selectedUniversity!,
        _selectedCampus!,
        _selectedCollege!,
        _selectedSchool!,
        _selectedDept!,
        _selectedCourse!,
        _selectedYearKey!,
        _selectedSemesterKey!,
      );

      if (units.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Could not load units for selected profile. Please check selection.'), backgroundColor: colorScheme.error));
        return;
      }

      final academicData = AcademicProfileData(
        university: _selectedUniversity!,
        campus: _selectedCampus!,
        college: _selectedCollege!,
        school: _selectedSchool!,
        department: _selectedDept!,
        course: _selectedCourse!,
        yearKey: _selectedYearKey!,
        semesterKey: _selectedSemesterKey!,
        registeredUnits: units,
      );

      if (!mounted) return;
      // Navigate to the next step
      Navigator.push(context, MaterialPageRoute(builder: (_) => PersonalDetailsPage(academicData: academicData)));

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error preparing data: $e'), backgroundColor: colorScheme.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onUniversityChanged(String? university) {
    setState(() {
      _selectedUniversity = university;
      // Reset all subsequent selections
      _selectedCampus = null;
      _selectedCollege = null;
      _selectedSchool = null;
      _selectedDept = null;
      _selectedCourse = null;
      _selectedYearKey = null;
      _selectedSemesterKey = null;

      // Load the next level: Campuses
      _campuses = university == null ? [] : _universityData.getCampuses(university);

      // Clear all lower-level lists
      _colleges = [];
      _schools = [];
      _departments = [];
      _courses = [];
      _years = [];
      _semesters = [];
    });
  }

  void _onCampusChanged(String? campus) {
    if (_selectedUniversity == null) return;
    setState(() {
      _selectedCampus = campus;
      _selectedCollege = null;
      _selectedSchool = null;
      _selectedDept = null;
      _selectedCourse = null;
      _selectedYearKey = null;
      _selectedSemesterKey = null;

      _colleges = campus == null ? [] : _universityData.getColleges(_selectedUniversity!, campus);
      _departments = [];
      _courses = [];
      _years = [];
      _semesters = [];
    });
  }

  void _onCollegeChanged(String? college) {
    if (_selectedUniversity == null || _selectedCampus == null) return;
    setState(() {
      _selectedCollege = college;
      _selectedSchool = null;
      _selectedDept = null;
      _selectedCourse = null;
      _selectedYearKey = null;
      _selectedSemesterKey = null;

      _schools = (college == null) ? [] : _universityData.getSchools(_selectedUniversity!, _selectedCampus!, college);
      _departments = [];
      _courses = [];
      _years = [];
      _semesters = [];
    });
  }

  void _onSchoolChanged(String? school) {
    if (_selectedUniversity == null || _selectedCampus == null || _selectedCollege == null) return;
    setState(() {
      _selectedSchool = school;
      _selectedDept = null;
      _selectedCourse = null;
      _selectedYearKey = null;
      _selectedSemesterKey = null;

      _departments = (school == null) ? [] : _universityData.getDepartments(_selectedUniversity!, _selectedCampus!, _selectedCollege!, school);
      _courses = [];
      _years = [];
      _semesters = [];
    });
  }

  void _onDeptChanged(String? dept) {
    if (_selectedUniversity == null || _selectedCampus == null || _selectedCollege == null || _selectedSchool == null) return;
    setState(() {
      _selectedDept = dept;
      _selectedCourse = null;
      _selectedYearKey = null;
      _selectedSemesterKey = null;

      _courses = (dept == null) ? [] : _universityData.getCourses(_selectedUniversity!, _selectedCampus!, _selectedCollege!, _selectedSchool!, dept);
      _years = [];
      _semesters = [];
    });
  }

  void _onCourseChanged(String? course) {
    if (_selectedUniversity == null || _selectedCampus == null || _selectedCollege == null || _selectedSchool == null || _selectedDept == null) return;
    setState(() {
      _selectedCourse = course;
      _selectedYearKey = null;
      _selectedSemesterKey = null;

      _years = (course == null) ? [] : _universityData.getYears(_selectedUniversity!, _selectedCampus!, _selectedCollege!, _selectedSchool!, _selectedDept!, course);
      _semesters = [];
    });
  }

  void _onYearChanged(String? yearKey) {
    if (_selectedUniversity == null || _selectedCampus == null || _selectedCollege == null || _selectedSchool == null || _selectedDept == null || _selectedCourse == null) return;
    setState(() {
      _selectedYearKey = yearKey;
      _selectedSemesterKey = null;

      _semesters = (yearKey == null) ? [] : _universityData.getSemesters(_selectedUniversity!, _selectedCampus!, _selectedCollege!, _selectedSchool!, _selectedDept!, _selectedCourse!, yearKey);
    });
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

    final selectedUnits = (_selectedUniversity != null && _selectedCampus != null && _selectedCollege != null && _selectedSchool != null && _selectedDept != null && _selectedCourse != null && _selectedYearKey != null && _selectedSemesterKey != null)
        ? _universityData.getUnits(_selectedUniversity!, _selectedCampus!, _selectedCollege!, _selectedSchool!, _selectedDept!, _selectedCourse!, _selectedYearKey!, _selectedSemesterKey!)
        : [];

    // final universities = _universityData.getCampuses();

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
                                _buildDropdown(label: 'University', value: _selectedUniversity, items: _universities, onChanged: _onUniversityChanged, icon: Icons.school,),
                                _buildDropdown(label: 'Campus', value: _selectedCampus, items: _campuses, onChanged: _onCampusChanged, icon: Icons.location_city),
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
                                // SizedBox(
                                //   width: double.infinity,
                                //   child: _isLoading
                                //       ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                                //       : ElevatedButton(
                                //     onPressed: _saveProfile,
                                //     style: ElevatedButton.styleFrom(
                                //         backgroundColor: colorScheme.primary,
                                //         padding: const EdgeInsets.symmetric(vertical: 16),
                                //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                //     child: Text('FINISH & VIEW UNITS', style: theme.textTheme.labelLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onPrimary)),
                                //   ),
                                // ),
                                SizedBox(
                                  width: double.infinity,
                                  child: _isLoading
                                      ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                                      : ElevatedButton(
                                    onPressed: _navigateToPersonalDetails,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                    child: Text('NEXT: PERSONAL DETAILS', style: theme.textTheme.labelLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onPrimary)),
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
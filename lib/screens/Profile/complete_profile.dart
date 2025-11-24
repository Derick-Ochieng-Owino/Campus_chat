import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../home/home_screen.dart';

// ---------------------------
// HIERARCHY AND UNITS SETUP
// ---------------------------

class CourseStructure {
  /// Hierarchy: College -> School -> Department -> Course
  static final Map<String, Map<String, Map<String, List<String>>>> hierarchy = {
    'COANRE': {
      'School of Agriculture & Env. Sciences': {
        'Landscape & Environmental Sciences': [
          'BSc. Environmental Horticulture and Landscaping Technology',
          'BSc. Environmental Horticulture'
        ],
        'Horticulture & Food Security': [
          'BSc. Horticulture',
          'MSc. Plant Breeding',
          'MSc. Horticulture',
          'MSc. Plant Health Science & Management'
        ],
      },
    },
    'COPAS': {
      'School of Computing & IT': {
        'Computing': [
          'BSc. Computer Science',
          'BSc. Computer Technology',
        ],
      },
    },
  };

  /// Units per course per year/semester (unitCode as key)
  static final Map<String, Map<String, Map<String, List<String>>>> units = {
    'BSc. Computer Science': {
      '1': {
        '1': ['ICS2101', 'ICS2102', 'SMA2104'],
        '2': ['ICS2103', 'ICS2105', 'SMA2105'],
      },
      '2': {
        '1': ['ICS2201', 'ICS2202', 'SMA2204'],
        '2': ['ICS2203', 'ICS2205', 'SMA2205'],
      },
    },
    'BSc. Environmental Horticulture': {
      '1': {
        '1': ['AHS2101', 'AHS2102', 'SBC2101'],
        '2': ['AHS2103', 'AHS2104', 'SBC2102'],
      },
    },
  };

  /// Map of unitCode -> full name
  static final Map<String, String> unitCatalog = {
    'ICS2101': 'Programming Methodologies',
    'ICS2102': 'Distributed Systems',
    'ICS2103': 'Database Systems',
    'ICS2105': 'Artificial Intelligence Fundamentals',
    'SMA2104': 'Mathematics for Science',
    'SMA2105': 'Engineering Mathematics II',
    'AHS2101': 'Plant Physiology',
    'AHS2102': 'Principles of Genetics',
    'AHS2103': 'Soil Science',
    'AHS2104': 'Introduction to Botany',
    'SBC2101': 'Botany Basics',
    'SBC2102': 'Advanced Botany',
  };

  static List<String> getColleges() => hierarchy.keys.toList();

  static List<String> getSchools(String college) =>
      hierarchy[college]?.keys.toList() ?? [];

  static List<String> getDepartments(String college, String school) =>
      hierarchy[college]?[school]?.keys.toList() ?? [];

  static List<String> getCourses(String college, String school, String dept) =>
      hierarchy[college]?[school]?[dept] ?? [];

  static List<String> getUnitCodes(String course, String year, String semester) =>
      units[course]?[year]?[semester] ?? [];

  static List<String> getUnitNames(List<String> unitCodes) =>
      unitCodes.map((e) => unitCatalog[e] ?? e).toList();
}

// ---------------------------
// PROFILE PAGE
// ---------------------------

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String? _selectedCollege;
  String? _selectedSchool;
  String? _selectedDept;
  String? _selectedCourse;
  String? _selectedYear;
  String? _selectedSem;

  List<String> _schools = [];
  List<String> _depts = [];
  List<String> _courses = [];

  final List<String> _years = ['1', '2', '3', '4', '5'];
  final List<String> _semesters = ['1', '2'];

  void _onCollegeChanged(String? val) {
    setState(() {
      _selectedCollege = val;
      _schools = CourseStructure.getSchools(val!);
      _selectedSchool = null;
      _selectedDept = null;
      _selectedCourse = null;
      _depts = [];
      _courses = [];
    });
  }

  void _onSchoolChanged(String? val) {
    setState(() {
      _selectedSchool = val;
      _depts = CourseStructure.getDepartments(_selectedCollege!, val!);
      _selectedDept = null;
      _selectedCourse = null;
      _courses = [];
    });
  }

  void _onDeptChanged(String? val) {
    setState(() {
      _selectedDept = val;
      _courses = CourseStructure.getCourses(_selectedCollege!, _selectedSchool!, val!);
      _selectedCourse = null;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No user logged in");

      final courseKey = _selectedCourse!;
      final year = _selectedYear!;
      final sem = _selectedSem!;
      final unitCodes = CourseStructure.getUnitCodes(courseKey, year, sem);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'profile_completed': true,
        'college': _selectedCollege,
        'school': _selectedSchool,
        'department': _selectedDept,
        'course': courseKey,
        'year_of_study': year,
        'semester': sem,
        'registered_units': unitCodes,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile Updated! Setting up your units..."),
            backgroundColor: AppColors.primary,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.darkGrey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((item) =>
              DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: items.isEmpty ? null : onChanged,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.lightGrey,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) => v == null ? "Required" : null,
          dropdownColor: Colors.white,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final selectedUnits = (_selectedCourse != null && _selectedYear != null && _selectedSem != null)
        ? CourseStructure.getUnitCodes(_selectedCourse!, _selectedYear!, _selectedSem!)
        : [];

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          child: Stack(
            children: [
              Container(
                height: size.height * 0.4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40)),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Complete Profile',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Text(
                        'We need a few details to set up your portal',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 30),
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDropdown(
                                  label: "University",
                                  value: "JKUAT",
                                  items: ["JKUAT"],
                                  onChanged: (v) {},
                                  icon: Icons.school,
                                ),
                                _buildDropdown(
                                  label: "College",
                                  value: _selectedCollege,
                                  items: CourseStructure.getColleges(),
                                  onChanged: _onCollegeChanged,
                                  icon: Icons.account_balance,
                                ),
                                _buildDropdown(
                                  label: "School",
                                  value: _selectedSchool,
                                  items: _schools,
                                  onChanged: _onSchoolChanged,
                                  icon: Icons.business,
                                ),
                                _buildDropdown(
                                  label: "Department",
                                  value: _selectedDept,
                                  items: _depts,
                                  onChanged: _onDeptChanged,
                                  icon: Icons.category,
                                ),
                                _buildDropdown(
                                  label: "Course",
                                  value: _selectedCourse,
                                  items: _courses,
                                  onChanged: (v) => setState(() => _selectedCourse = v),
                                  icon: Icons.book,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdown(
                                        label: "Year",
                                        value: _selectedYear,
                                        items: _years,
                                        onChanged: (v) => setState(() => _selectedYear = v),
                                        icon: Icons.calendar_today,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildDropdown(
                                        label: "Semester",
                                        value: _selectedSem,
                                        items: _semesters,
                                        onChanged: (v) => setState(() => _selectedSem = v),
                                        icon: Icons.timeline,
                                      ),
                                    ),
                                  ],
                                ),
                                if (selectedUnits.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: AppColors.primary),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            "Saving will register you for ${selectedUnits.length} units.",
                                            style: const TextStyle(
                                                color: AppColors.primary, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  child: _isLoading
                                      ? const Center(
                                      child: CircularProgressIndicator(color: AppColors.primary))
                                      : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16)),
                                      elevation: 4,
                                    ),
                                    onPressed: _saveProfile,
                                    child: const Text(
                                      'FINISH & VIEW UNITS',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

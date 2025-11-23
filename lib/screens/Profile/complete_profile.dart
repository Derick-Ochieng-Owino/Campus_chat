import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/campus_data.dart';
import '../../core/constants/colors.dart';
import '../home/home_screen.dart';

// --- PASTE CAMPUS DATA CLASS HERE IF NOT IN SEPARATE FILE ---
// (I will assume the class CampusData from step 1 is available)

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Selected Values
  String? _selectedCollege;
  String? _selectedSchool;
  String? _selectedDept;
  String? _selectedCourse;
  String? _selectedYear;
  String? _selectedSem;

  // Lists for Dropdowns (Dependent on previous selection)
  List<String> _schools = [];
  List<String> _depts = [];
  List<String> _courses = [];

  // Static Lists
  final List<String> _years = ['1', '2', '3', '4', '5'];
  final List<String> _semesters = ['1', '2'];

  // --- Logic to handle dependency updates ---

  void _onCollegeChanged(String? val) {
    setState(() {
      _selectedCollege = val;
      _schools = CampusData.getSchools(val!);
      // Reset downstream
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
      _depts = CampusData.getDepartments(_selectedCollege!, val!);
      // Reset downstream
      _selectedDept = null;
      _selectedCourse = null;
      _courses = [];
    });
  }

  void _onDeptChanged(String? val) {
    setState(() {
      _selectedDept = val;
      _courses = CampusData.getCourses(_selectedCollege!, _selectedSchool!, val!);
      // Reset downstream
      _selectedCourse = null;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No user logged in");

      // 1. Generate the Units based on selection
      final units = CampusData.getUnits(_selectedCourse!, _selectedYear!, _selectedSem!);

      // 2. Save to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'profile_completed': true,
        'college': _selectedCollege,
        'school': _selectedSchool,
        'department': _selectedDept,
        'course': _selectedCourse,
        'year_of_study': _selectedYear,
        'semester': _selectedSem,
        'registered_units': units, // <--- SAVING UNITS HERE
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Merge so we don't lose email/role

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated! Setting up your units..."), backgroundColor: AppColors.primary),
        );

        // 3. Navigate to Home
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomePage()));
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

  // --- UI Helper for Dropdowns ---
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkGrey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: items.isEmpty ? null : onChanged, // Disable if no items
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.lightGrey,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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

    // PopScope prevents back button (Android) or swipe back (iOS)
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          child: Stack(
            children: [
              // Top Background
              Container(
                height: size.height * 0.4, // Taller background for this page
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

              // Main Form Card
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Complete Profile',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
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
                                // UNIVERSITY (Static for now, but context implies hierarchy starts here)
                                _buildDropdown(
                                  label: "University",
                                  value: "JKUAT",
                                  items: ["JKUAT"],
                                  onChanged: (v) {}, // Single option
                                  icon: Icons.school,
                                ),

                                // COLLEGE
                                _buildDropdown(
                                  label: "College",
                                  value: _selectedCollege,
                                  items: CampusData.getColleges(),
                                  onChanged: _onCollegeChanged,
                                  icon: Icons.account_balance,
                                ),

                                // SCHOOL (Dependent on College)
                                _buildDropdown(
                                  label: "School",
                                  value: _selectedSchool,
                                  items: _schools,
                                  onChanged: _onSchoolChanged,
                                  icon: Icons.business,
                                ),

                                // DEPARTMENT (Dependent on School)
                                _buildDropdown(
                                  label: "Department",
                                  value: _selectedDept,
                                  items: _depts,
                                  onChanged: _onDeptChanged,
                                  icon: Icons.category,
                                ),

                                // COURSE (Dependent on Dept)
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

                                const SizedBox(height: 16),

                                // Preview Message
                                if (_selectedCourse != null && _selectedYear != null && _selectedSem != null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.primary.withOpacity(0.3))
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: AppColors.primary),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            "Saving will register you for ${CampusData.getUnits(_selectedCourse!, _selectedYear!, _selectedSem!).length} units.",
                                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 32),

                                // Save Button
                                SizedBox(
                                  width: double.infinity,
                                  child: _isLoading
                                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                                      : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 4,
                                    ),
                                    onPressed: _saveProfile,
                                    child: const Text(
                                      'FINISH & VIEW UNITS',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
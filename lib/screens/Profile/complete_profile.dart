// lib/screens/Profile/complete_profile.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/colors.dart';
import '../home/home_screen.dart';

/// Embedded campus JSON (use the JSON you pasted)
// const String _campusJson = r'''
// {
//   "campuses": {
//     "Main": {
//       "colleges": {
//         "COPAS": {
//           "full_name": "College of Pure and Applied Sciences",
//           "schools": {
//             "SCIT": {
//               "full_name": "School of Computing and Information Technology",
//               "departments": {
//                 "IT": {
//                   "full_name": "Department of Information Technology",
//                   "courses": {
//                     "BIT": {
//                       "full_name": "Bachelor of Science in Information Technology",
//                       "years": {
//                         "year1": {
//                           "semester1": [
//                             { "code": "SZL 2111", "title": "HIV/AIDS", "type": "CORE" },
//                             { "code": "CILS 2101", "title": "Communication and Information Literacy Skills", "type": "CORE" },
//                             { "code": "SMA 2104", "title": "Mathematics for Sciences", "type": "CORE" },
//                             { "code": "ICS 2109", "title": "Computer Operating Systems", "type": "CORE" },
//                             { "code": "BIT 2103", "title": "Introduction to Computer Applications", "type": "CORE" },
//                             { "code": "BBC 2104", "title": "Hardware Systems Support and Maintenance", "type": "CORE" },
//                             { "code": "BBC 2105", "title": "Essentials of Economics", "type": "CORE" },
//                             { "code": "BIT 2104", "title": "Introduction to Programming", "type": "CORE" },
//                             { "code": "HBC 2128", "title": "Introduction to Accounting 1", "type": "CORE" }
//                           ],
//                           "semester2": [
//                             { "code": "BIT 2123", "title": "Computer Network, Design and Management", "type": "CORE" },
//                             { "code": "SDS 2107", "title": "Algebra for Data Science", "type": "CORE" },
//                             { "code": "BIT 2112", "title": "Systems Analysis and Design", "type": "CORE" },
//                             { "code": "ICS 2200", "title": "Analogue Electronics", "type": "CORE" },
//                             { "code": "BIT 2225", "title": "Cloud Computing", "type": "CORE" },
//                             { "code": "HRD 2102", "title": "Development Studies and Social Ethics", "type": "CORE" },
//                             { "code": "BIT 2212", "title": "Business Systems Modelling", "type": "CORE" },
//                             { "code": "SMA 2100", "title": "Discrete Mathematics", "type": "CORE" }
//                           ]
//                         },
//                         "year2": {
//                           "semester1": [
//                             { "code": "BIT 2324", "title": "Geographical Information Systems", "type": "CORE" },
//                             { "code": "ICS 2206", "title": "Introduction to Database Management Systems", "type": "CORE" },
//                             { "code": "BIT 2223", "title": "Mobile and Wireless Computing", "type": "CORE" },
//                             { "code": "BIT 2214", "title": "Object-Oriented Analysis and Design", "type": "CORE" },
//                             { "code": "ICS 2104", "title": "Object Oriented Programming I", "type": "CORE" },
//                             { "code": "SMA 2101", "title": "Calculus I", "type": "CORE" },
//                             { "code": "ICS 2203", "title": "Web Application Development I", "type": "CORE" },
//                             { "code": "ICS 2302", "title": "Software Engineering I", "type": "CORE" }
//                           ],
//                           "semester2": [
//                             { "code": "SMA 2102", "title": "Calculus II", "type": "CORE" },
//                             { "code": "BIT 2207", "title": "Web Design and Development II", "type": "CORE" },
//                             { "code": "BIT 2204", "title": "Network Systems Administration", "type": "CORE" },
//                             { "code": "BIT 2118", "title": "Application Programming I", "type": "CORE" },
//                             { "code": "ICS 2105", "title": "Data Structures and Algorithms", "type": "CORE" },
//                             { "code": "ICS 2201", "title": "Object Oriented Programming II", "type": "CORE" },
//                             { "code": "ICS 2205", "title": "Digital Logic", "type": "CORE" },
//                             { "code": "STA 2100", "title": "Probability and Statistics I", "type": "CORE" },
//                             { "code": "BIT 2122", "title": "Industrial Attachment", "type": "CORE" }
//                           ]
//                         },
//                         "year3": {
//                           "semester1": [
//                             { "code": "BIT 2111", "title": "Computer Aided Design", "type": "CORE" },
//                             { "code": "BIT 2203", "title": "Advanced Programming", "type": "CORE" },
//                             { "code": "BIT 2320", "title": "Mobile Application Development", "type": "CORE" },
//                             { "code": "BIT 2321", "title": "Software Engineering II", "type": "CORE" },
//                             { "code": "BIT 2323", "title": "Application Programming II", "type": "CORE" },
//                             { "code": "ICS 2301", "title": "Design and Analysis of Algorithms", "type": "CORE" },
//                             { "code": "ICS 2404", "title": "Advanced Database Management Systems", "type": "CORE" }
//                           ],
//                           "semester2": [
//                             { "code": "BIT 2215", "title": "Software Project Management", "type": "CORE" },
//                             { "code": "BIT 2301", "title": "Research Methodology", "type": "CORE" },
//                             { "code": "BIT 2319", "title": "Artificial Intelligence", "type": "CORE" },
//                             { "code": "STA 2200", "title": "Probability and Statistics II", "type": "CORE" },
//                             { "code": "ICS 2305", "title": "Systems Programming", "type": "CORE" },
//                             { "code": "BIT 2326", "title": "Internet of Things (IoT) and Embedded Systems", "type": "CORE" },
//                             { "code": "BIT 2327", "title": "Introduction to Cyber Security", "type": "CORE" },
//                             { "code": "BIT 2328", "title": "Cryptography and Blockchain Applications", "type": "CORE" }
//                           ]
//                         },
//                         "year4": {
//                           "semester1": [
//                             { "code": "BIT 2303", "title": "Research Project", "type": "CORE" },
//                             { "code": "BIT 2305", "title": "Human Computer Interactions", "type": "CORE" },
//                             { "code": "BIT 2400", "title": "Introduction to Functional Programming", "type": "CORE" },
//                             { "code": "ICS 2405", "title": "Knowledge Based Systems", "type": "CORE" },
//                             { "code": "ICS 2403", "title": "Distributed Systems", "type": "CORE" },
//                             { "code": "HSC 2408", "title": "Innovation and Technology Transfer", "type": "CORE" },
//                             { "code": "BIT 2210", "title": "Fundamentals of Business Intelligence", "type": "CORE" },
//                             { "code": "BIT 2317", "title": "Computer Systems Security", "type": "CORE" }
//                           ],
//                           "semester2": [
//                             { "code": "BIT 2313", "title": "Professional Issues in ICT", "type": "CORE" },
//                             { "code": "BIT 2318", "title": "Information System Audit", "type": "CORE" },
//                             { "code": "BIT 2401", "title": "Advanced Business Intelligence", "type": "CORE" },
//                             { "code": "BIT 2402", "title": "Enterprise Systems Applications and Architecture", "type": "CORE" },
//                             { "code": "ICS 2303", "title": "Multimedia Systems and Applications", "type": "CORE" },
//                             { "code": "HRD 2401", "title": "Entrepreneurship Skills", "type": "CORE" },
//                             { "code": "HBC 2112", "title": "Principles of Marketing", "type": "CORE" }
//                           ]
//                         }
//                       }
//                     }
//                   }
//                 }
//               }
//             }
//           }
//         },
//         "COETEC": {
//           "full_name": "College of Engineering and Technology",
//           "schools": {
//             "SOE": {
//               "full_name": "School of Engineering",
//               "departments": {
//                 "EEE": {
//                   "full_name": "Department of Electrical & Electronic Engineering",
//                   "courses": {
//                     "BENG_EEE": {
//                       "full_name": "Bachelor of Science in Electrical & Electronic Engineering",
//                       "years": {
//                         "year1": {
//                           "semester1": [
//                             { "code": "ENG 1101", "title": "Engineering Mathematics I", "type": "CORE" },
//                             { "code": "ENG 1102", "title": "Engineering Physics I", "type": "CORE" }
//                           ],
//                           "semester2": [
//                             { "code": "ENG 1201", "title": "Engineering Drawing", "type": "CORE" },
//                             { "code": "ENG 1202", "title": "Applied Electricity", "type": "CORE" }
//                           ]
//                         }
//                       }
//                     }
//                   }
//                 }
//               }
//             }
//           }
//         }
//       }
//     },
//     "Karen": {
//       "colleges": {
//         "LAW": {
//           "full_name": "School of Law",
//           "schools": {},
//           "departments": {},
//           "courses": {}
//         }
//       }
//     },
//     "Mombasa": {
//       "colleges": {
//         "CES": {
//           "full_name": "Commerce and Economic Studies Department",
//           "schools": {},
//           "departments": {},
//           "courses": {}
//         }
//       }
//     },
//     "CBD": {
//       "colleges": {
//         "EPD": {
//           "full_name": "Entrepreneurship Procurement Department",
//           "schools": {},
//           "departments": {},
//           "courses": {}
//         }
//       }
//     }
//   }
// }
// ''';

/// --- CampusData helper that reads the JSON and exposes safe getters ---
class CampusData {
  final Map<String, dynamic> campuses;

  CampusData({required this.campuses});

  factory CampusData.fromJsonString(String jsonString) {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      print('Decoded JSON top-level keys: ${map.keys}');
      return CampusData(
        campuses: map['campuses'] as Map<String, dynamic>,
      );
    } catch (e) {
      print('Error parsing campus JSON: $e');
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

  late Future<CampusData> _campusDataFuture;

  @override
  void initState() {
    super.initState();
    _campusDataFuture = _loadCampusData();
    _campusData = widget.campusData;
  }

  Future<CampusData> _loadCampusData() async {
    final jsonString = await rootBundle.loadString('assets/data/campus_data.json');
    return CampusData.fromJsonString(jsonString);
  }

  // --- Dropdown callbacks ---
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

    if (_selectedCampus == null ||
        _selectedCollege == null ||
        _selectedSchool == null ||
        _selectedDept == null ||
        _selectedCourse == null ||
        _selectedYearKey == null ||
        _selectedSemesterKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all fields'), backgroundColor: Colors.red));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated'), backgroundColor: AppColors.primary));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkGrey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(itemLabel?.call(e) ?? e, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: items.isEmpty ? null : onChanged,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.lightGrey,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          ),
          validator: (v) => v == null ? 'Required' : null,
          dropdownColor: Colors.white,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final selectedUnits = (_selectedCampus != null && _selectedCollege != null && _selectedSchool != null && _selectedDept != null && _selectedCourse != null && _selectedYearKey != null && _selectedSemesterKey != null)
        ? _campusData.getUnits(_selectedCampus!, _selectedCollege!, _selectedSchool!, _selectedDept!, _selectedCourse!, _selectedYearKey!, _selectedSemesterKey!)
        : [];

    final campuses = _campusData.getCampuses();

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Stack(
            children: [
              Container(
                height: size.height * 0.4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      const Text('Complete Profile', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Text('We need a few details to set up your portal', style: TextStyle(fontSize: 14, color: Colors.white70)),
                      const SizedBox(height: 30),
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDropdown(
                                  label: 'Campus',
                                  value: _selectedCampus ?? (campuses.isNotEmpty ? campuses.first : null),
                                  items: campuses,
                                  onChanged: (v) { _onCampusChanged(v); },
                                  icon: Icons.location_city,
                                ),
                                _buildDropdown(
                                  label: 'College',
                                  value: _selectedCollege,
                                  items: _colleges,
                                  onChanged: _onCollegeChanged,
                                  icon: Icons.account_balance,
                                ),
                                _buildDropdown(
                                  label: 'School',
                                  value: _selectedSchool,
                                  items: _schools,
                                  onChanged: _onSchoolChanged,
                                  icon: Icons.business,
                                ),
                                _buildDropdown(
                                  label: 'Department',
                                  value: _selectedDept,
                                  items: _departments,
                                  onChanged: _onDeptChanged,
                                  icon: Icons.category,
                                ),
                                _buildDropdown(
                                  label: 'Course',
                                  value: _selectedCourse,
                                  items: _courses,
                                  onChanged: _onCourseChanged,
                                  icon: Icons.book,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdown(
                                        label: 'Year',
                                        value: _selectedYearKey,
                                        items: _years,
                                        onChanged: (v) => _onYearChanged(v),
                                        icon: Icons.calendar_today,
                                        itemLabel: _displayYear,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildDropdown(
                                        label: 'Semester',
                                        value: _selectedSemesterKey,
                                        items: _semesters,
                                        onChanged: (v) => setState(() => _selectedSemesterKey = v),
                                        icon: Icons.timeline,
                                        itemLabel: _displaySemester,
                                      ),
                                    ),
                                  ],
                                ),
                                if (selectedUnits.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: AppColors.primary),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text('Saving will register you for ${selectedUnits.length} units.', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  child: _isLoading
                                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                                      : ElevatedButton(
                                    onPressed: _saveProfile,
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                    child: const Text('FINISH & VIEW UNITS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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

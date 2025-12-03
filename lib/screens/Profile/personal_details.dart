import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'profile_photo.dart';

class AcademicProfileData {
  final String campus;
  final String college;
  final String school;
  final String department;
  final String course;
  final String yearKey;
  final String semesterKey;
  final List<Map<String, dynamic>> registeredUnits;

  AcademicProfileData({
    required this.campus,
    required this.college,
    required this.school,
    required this.department,
    required this.course,
    required this.yearKey,
    required this.semesterKey,
    required this.registeredUnits,
  });
}

class PersonalDetailsPage extends StatefulWidget {
  final AcademicProfileData academicData;
  const PersonalDetailsPage({super.key, required this.academicData});

  @override
  State<PersonalDetailsPage> createState() => _PersonalDetailsPageState();
}

class _PersonalDetailsPageState extends State<PersonalDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  String? _fullName;
  String? _nickname;
  String? _regNumber;
  DateTime? _birthDate;

  final TextEditingController _birthDateController = TextEditingController();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // Default to 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
        _birthDateController.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  void _navigateToNext() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Navigate to the Profile Photo Page, passing both sets of data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfilePhotoPage(
            academicData: widget.academicData,
            personalData: PersonalDetailsData(
              fullName: _fullName!,
              regNumber: _regNumber!,
              birthDate: _birthDate!,
              nickname: _nickname,
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _birthDateController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    required void Function(String?) onSaved,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    TextEditingController? controller,
    bool readOnly = false,
    void Function()? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface.withOpacity(0.8))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onSaved: onSaved,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: colorScheme.primary),
          ),
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

    return Scaffold(
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
                    end: Alignment.bottomRight),
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
                    Text('Personal Details', style: theme.textTheme.headlineSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Tell us a bit about yourself', style: theme.textTheme.bodyMedium!.copyWith(color: Colors.white70)),
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
                              // Full Name
                              _buildTextField(
                                label: 'Full Name',
                                icon: Icons.person,
                                keyboardType: TextInputType.name,
                                validator: (v) => (v == null || v.isEmpty) ? 'Full Name is required' : null,
                                onSaved: (v) => _fullName = v!.trim(),
                              ),
                              // Registration Number
                              _buildTextField(
                                label: 'Registration Number',
                                icon: Icons.badge,
                                keyboardType: TextInputType.text,
                                validator: (v) => (v == null || v.isEmpty) ? 'Registration Number is required' : null,
                                onSaved: (v) => _regNumber = v!.toUpperCase().trim(),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-/]')), // Allow letters, numbers, hyphen, slash
                                ],
                              ),
                              // Nickname (Optional)
                              _buildTextField(
                                label: 'Nickname (Optional)',
                                icon: Icons.tag_faces,
                                keyboardType: TextInputType.text,
                                validator: (_) => null,
                                onSaved: (v) => _nickname = v?.trim(),
                              ),
                              // Birthdate
                              _buildTextField(
                                label: 'Birthdate',
                                icon: Icons.calendar_today,
                                controller: _birthDateController,
                                readOnly: true,
                                onTap: () => _selectDate(context),
                                validator: (v) => (_birthDate == null) ? 'Birthdate is required' : null,
                                onSaved: (_) {}, // Birthdate saved via _selectDate
                              ),

                              const SizedBox(height: 32),

                              // Next Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _navigateToNext,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                  child: Text('NEXT: PROFILE PHOTO', style: theme.textTheme.labelLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onPrimary)),
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
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../auth/profile_photo.dart';

class AcademicProfileData {
  final String university;
  final String campus;
  final String college;
  final String school;
  final String department;
  final String course;
  final String year;
  final String semester;
  final List<Map<String, dynamic>> registeredUnits;

  AcademicProfileData({
    required this.university,
    required this.campus,
    required this.college,
    required this.school,
    required this.department,
    required this.course,
    required this.year,
    required this.semester,
    required this.registeredUnits,
  });
}

class PersonalDetailsData {
  final String fullName;
  final String regNumber;
  final String phoneNumber;
  final DateTime birthDate;
  final String? nickname;

  PersonalDetailsData({
    required this.fullName,
    required this.regNumber,
    required this.phoneNumber,
    required this.birthDate,
    this.nickname,
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
  String? _phoneNumber;
  String? _regNumber;
  DateTime? _birthDate;

  final TextEditingController _birthDateController = TextEditingController();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
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

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfilePhotoPage(
            academicData: widget.academicData,
            personalData: PersonalDetailsData(
              fullName: _fullName!,
              regNumber: _regNumber!,
              phoneNumber: _phoneNumber!,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
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
            prefixIcon: Icon(icon, color: theme.colorScheme.primary),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Container(
              height: size.height * 0.35,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Text('Personal Details', style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Tell us a bit about yourself', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 4,
                      color: theme.cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildTextField(
                                label: 'Full Name',
                                icon: Icons.person_outline_rounded,
                                keyboardType: TextInputType.name,
                                validator: (v) => (v == null || v.isEmpty) ? 'Full Name is required' : null,
                                onSaved: (v) => _fullName = v!.trim(),
                              ),
                              _buildTextField(
                                label: 'Registration Number',
                                icon: Icons.badge_outlined,
                                validator: (v) => (v == null || v.isEmpty) ? 'Registration Number is required' : null,
                                onSaved: (v) => _regNumber = v!.toUpperCase().trim(),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-/]'))],
                              ),
                              _buildTextField(
                                label: 'Phone Number',
                                icon: Icons.phone_android_rounded,
                                keyboardType: TextInputType.phone,
                                validator: (v) => (v == null || v.isEmpty) ? 'Phone Number is required' : null,
                                onSaved: (v) => _phoneNumber = v!.trim(),
                              ),
                              _buildTextField(
                                label: 'Nickname (Optional)',
                                icon: Icons.face_unlock_rounded,
                                onSaved: (v) => _nickname = v?.trim(),
                                validator: (value) => null,
                              ),
                              _buildTextField(
                                label: 'Birthdate',
                                icon: Icons.calendar_today_rounded,
                                controller: _birthDateController,
                                readOnly: true,
                                onTap: () => _selectDate(context),
                                validator: (v) => (_birthDate == null) ? 'Birthdate is required' : null,
                                onSaved: (_) {},
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _navigateToNext,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: const Text('NEXT: PROFILE PHOTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
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
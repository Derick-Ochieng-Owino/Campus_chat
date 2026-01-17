// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _descController = TextEditingController();

  String _selectedType = 'Class Confirmation';
  String? _selectedUnit;
  DateTime? _selectedDate;

  // File Upload State
  PlatformFile? _pickedFile;
  bool _isLoading = false;
  bool _isFetchingUnits = false;

  // Units data
  List<Map<String, dynamic>> _units = [];
  List<String> _unitDisplayNames = [];

  final List<String> _types = [
    'General',
    'Class Confirmation',
    'Notes',
    'Assignment',
    'CAT',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserUnits();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  // --- FETCH USER UNITS ---
  Future<void> _fetchUserUnits() async {
    setState(() => _isFetchingUnits = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        if (userData.containsKey('registered_units')) {
          final List<dynamic> unitsList = userData['registered_units'];

          setState(() {
            _units = unitsList.map((unit) {
              return {
                'code': unit['code'] ?? '',
                'title': unit['title'] ?? '',
                'type': unit['type'] ?? 'CORE',
              };
            }).toList();

            // Create display names: "BIT 2.1 BIT 2324 Geographical Information Systems"
            _unitDisplayNames = _units.map((unit) {
              final code = unit['code'];
              final title = unit['title'];

              // Extract year and semester from code (e.g., "BIT 2324")
              String yearSemester = '';
              if (code.contains(' ')) {
                final parts = code.split(' ');
                if (parts.length > 1) {
                  final codeNumber = parts[1];
                  if (codeNumber.length >= 4) {
                    final year = codeNumber.substring(0, 2); // "23"
                    final semester = codeNumber.substring(2, 3); // "2"
                    yearSemester = '${parts[0]} $year.$semester';
                  }
                }
              }

              return '$yearSemester $code $title';
            }).toList();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error fetching units: $e"),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingUnits = false);
      }
    }
  }

  // --- 1. FILE PICKER LOGIC ---
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'png'],
    );

    if (result != null) {
      final file = result.files.first;

      if (file.size > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File size exceeds 5MB")),
        );
        return;
      }

      setState(() => _pickedFile = file);
    }
  }

  void _clearFile() {
    setState(() {
      _pickedFile = null;
    });
  }

  // --- 2. DATE PICKER LOGIC ---
  Future<void> _pickDate() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: colorScheme.copyWith(
              primary: colorScheme.primary,
              onPrimary: colorScheme.onPrimary,
              surface: colorScheme.surface,
              onSurface: colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: theme.copyWith(
              colorScheme: colorScheme.copyWith(
                primary: colorScheme.primary,
                onPrimary: colorScheme.onPrimary,
                surface: colorScheme.surface,
                onSurface: colorScheme.onSurface,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  // --- 3. UPLOAD & POST LOGIC ---
  Future<void> _postAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate based on type
    if (_selectedType != 'General' && _selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please select a unit for this announcement"),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please select a relevant date/time"),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not logged in");

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final semester = userData?['semester'] ?? 1;
      final year = userData?['year'] ?? 1;

      String? fileUrl;
      String? fileName;

      // A. Upload File to Firebase Storage (if selected)
      if (_pickedFile != null && _pickedFile!.path != null) {
        final file = File(_pickedFile!.path!);
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('announcements/${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}');

        final uploadTask = await storageRef.putFile(file);

        fileUrl = await uploadTask.ref.getDownloadURL();
        fileName = _pickedFile!.name;
      }

      // B. Prepare announcement data
      final Map<String, dynamic> announcementData = {
        'type': _selectedType,
        'description': _descController.text.trim(),
        'target_date': Timestamp.fromDate(_selectedDate!),
        'created_at': FieldValue.serverTimestamp(),
        'author_id': user.uid,
        'attachment_url': fileUrl,
        'attachment_name': fileName,
        'semester': semester,
        'year': year,
      };

      // C. Add unit-specific or general data
      if (_selectedType == 'General') {
        announcementData['title'] = 'General Announcement';
      } else {
        final selectedIndex = _unitDisplayNames.indexOf(_selectedUnit!);
        final unit = _units[selectedIndex];

        // Format: "Class Confirmation\nBIT 2.1 BIT 2324 Geographical Information Systems"
        announcementData['title'] = '$_selectedType\n${_unitDisplayNames[selectedIndex]}';
        announcementData['unit_code'] = unit['code'];
        announcementData['unit_title'] = unit['title'];

        // Save unit code in uppercase format for past papers/notes
        if (_selectedType == 'Notes' || _selectedType == 'CAT') {
          announcementData['unit_slug'] = unit['code'].replaceAll(' ', '_').toUpperCase();
          // e.g., "BIT_2324_GEO_INFO_SYST"
        }
      }

      // D. Save to Firestore
      await FirebaseFirestore.instance.collection('announcements').add(announcementData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Announcement posted successfully"),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error posting: $e"),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color labelColor = colorScheme.onSurface.withOpacity(0.8);
    final Color subtleTextColor = colorScheme.onSurface.withOpacity(0.6);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("New Announcement", style: theme.textTheme.titleLarge),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- TYPE DROPDOWN ---
              Text("Category", style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold, color: labelColor)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.onSurface.withOpacity(0.2)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    style: theme.textTheme.bodyMedium,
                    dropdownColor: theme.cardColor,
                    items: _types.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedType = newValue!;
                        if (_selectedType == 'General') {
                          _selectedUnit = null;
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- UNIT SELECTION (Only for non-General types) ---
              if (_selectedType != 'General') ...[
                Text("Select Unit", style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold, color: labelColor)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.onSurface.withOpacity(0.2)),
                  ),
                  child: _isFetchingUnits
                      ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: colorScheme.primary,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Loading units...",
                          style: theme.textTheme.bodyMedium!.copyWith(color: subtleTextColor),
                        ),
                      ],
                    ),
                  )
                      : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedUnit,
                      isExpanded: true,
                      hint: Text(
                        "Select a unit",
                        style: theme.textTheme.bodyMedium!.copyWith(color: subtleTextColor),
                      ),
                      style: theme.textTheme.bodyMedium,
                      dropdownColor: theme.cardColor,
                      items: _unitDisplayNames.map((String displayName) {
                        return DropdownMenuItem<String>(
                          value: displayName,
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedUnit = newValue;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // --- TITLE DISPLAY (For General type) ---
              if (_selectedType == 'General') ...[
                Text("Title", style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold, color: labelColor)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.announcement, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "General Announcement",
                          style: theme.textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // --- DESCRIPTION ---
              Text("Description", style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold, color: labelColor)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Enter announcement details...",
                  hintText: "Provide detailed information...",
                ),
                validator: (v) => v!.isEmpty ? "Description is required" : null,
              ),

              const SizedBox(height: 24),

              // --- ATTACHMENT SECTION ---
              Text("Attachments (Optional)", style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold, color: labelColor)),
              const SizedBox(height: 8),

              if (_pickedFile == null)
                InkWell(
                  onTap: _pickFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: subtleTextColor.withOpacity(0.5), style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(12),
                      color: theme.cardColor,
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: colorScheme.primary, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          "Tap to upload file",
                          style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "PDF, DOC, PPT, JPG (Max 5MB)",
                          style: theme.textTheme.bodySmall!.copyWith(color: subtleTextColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.primary),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pickedFile!.name,
                              style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "${(_pickedFile!.size / 1024).toStringAsFixed(2)} KB",
                              style: theme.textTheme.bodySmall!.copyWith(fontSize: 12, color: subtleTextColor),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: colorScheme.error),
                        onPressed: _clearFile,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // --- TIMELINE ---
              Text("Timeline", style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold, color: labelColor)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary),
                    borderRadius: BorderRadius.circular(12),
                    color: theme.cardColor,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDate == null
                            ? "Select Due Date / Sitting Date"
                            : DateFormat('EEE, MMM d, yyyy @ h:mm a').format(_selectedDate!),
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: _selectedDate == null ? subtleTextColor : colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // --- POST BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _postAnnouncement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text("UPLOADING...", style: theme.textTheme.labelLarge!.copyWith(color: colorScheme.onPrimary)),
                    ],
                  )
                      : Text(
                    "POST ANNOUNCEMENT",
                    style: theme.textTheme.labelLarge!.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
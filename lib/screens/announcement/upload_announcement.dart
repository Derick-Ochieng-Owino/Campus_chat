import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Import AppColors is no longer strictly necessary, but we'll use theme
// import '../../core/constants/colors.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _selectedType = 'Class Confirmation';
  DateTime? _selectedDate;

  // File Upload State
  PlatformFile? _pickedFile;
  bool _isLoading = false;

  final List<String> _types = [
    'Class Confirmation',
    'Notes',
    'Assignment',
    'CAT',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // --- 1. FILE PICKER LOGIC (Unchanged) ---
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  void _clearFile() {
    setState(() {
      _pickedFile = null;
    });
  }

  // --- 2. DATE PICKER LOGIC (Themed) ---
  Future<void> _pickDate() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        // Theme the DatePicker using the current theme's primary color
        return Theme(
          data: theme.copyWith(
            colorScheme: colorScheme.copyWith(
              primary: colorScheme.primary, // Use dynamic primary accent
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
          // Theme the TimePicker using the current theme's primary color
          return Theme(
            data: theme.copyWith(
              colorScheme: colorScheme.copyWith(
                primary: colorScheme.primary, // Use dynamic primary accent
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

  // --- 3. UPLOAD & POST LOGIC (Themed Snackbars) ---
  Future<void> _postAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;
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

      String? fileUrl;
      String? fileName;

      // A. Upload File to Firebase Storage (if selected) - Logic Unchanged
      if (_pickedFile != null && _pickedFile!.path != null) {
        final file = File(_pickedFile!.path!);
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('announcements/${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}');

        final uploadTask = await storageRef.putFile(file);

        fileUrl = await uploadTask.ref.getDownloadURL();
        fileName = _pickedFile!.name;
      }

      // B. Save to Firestore - Logic Unchanged
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'type': _selectedType,
        'target_date': Timestamp.fromDate(_selectedDate!),
        'created_at': FieldValue.serverTimestamp(),
        'author_id': user.uid,
        'attachment_url': fileUrl,
        'attachment_name': fileName,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Announcement posted successfully"),
            backgroundColor: Theme.of(context).colorScheme.secondary, // Dynamic Secondary Accent
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error posting: $e"),
            backgroundColor: Theme.of(context).colorScheme.error, // Dynamic Error Color
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

    // Helper to get consistent text color for labels
    final Color labelColor = colorScheme.onSurface.withOpacity(0.8);
    final Color subtleTextColor = colorScheme.onSurface.withOpacity(0.6);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Dynamic Background
      appBar: AppBar(
        title: Text("New Announcement", style: theme.textTheme.titleLarge), // Themed Text Style
        backgroundColor: colorScheme.surface, // Dynamic Surface/AppBar Color
        foregroundColor: colorScheme.onSurface, // Dynamic Icon/Text Color
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
                  // Rely on InputDecorationTheme or define colors explicitly for non-FormField dropdowns
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
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- DETAILS ---
              Text("Details", style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold, color: labelColor)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                  hintText: "e.g., CAT 1 Dates",
                  // Fill color and border handled by InputDecorationTheme
                ),
                validator: (v) => v!.isEmpty ? "Title is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "Enter details...",
                  // Fill color and border handled by InputDecorationTheme
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
                      color: theme.cardColor, // Dynamic Card Color
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: colorScheme.primary, size: 32), // Dynamic Primary
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
                    color: colorScheme.primaryContainer, // Dynamic Primary Container BG
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.primary), // Dynamic Primary Border
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file, color: colorScheme.primary), // Dynamic Primary
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
                        icon: Icon(Icons.close, color: colorScheme.error), // Dynamic Error
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
                    border: Border.all(color: colorScheme.primary), // Dynamic Primary
                    borderRadius: BorderRadius.circular(12),
                    color: theme.cardColor, // Dynamic Card Color
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, color: colorScheme.primary), // Dynamic Primary
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
                    backgroundColor: colorScheme.primary, // Dynamic Primary
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
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 2), // Dynamic OnPrimary
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
                      color: colorScheme.onPrimary, // Dynamic OnPrimary
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
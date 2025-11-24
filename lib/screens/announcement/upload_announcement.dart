import 'dart:io'; // Needed for File
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart'; // Import File Picker
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';

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

  // --- 1. FILE PICKER LOGIC ---
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

  // --- 2. DATE PICKER LOGIC ---
  Future<void> _pickDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
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
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: AppColors.primary),
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
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a relevant date/time")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not logged in");

      String? fileUrl;
      String? fileName;

      // A. Upload File to Firebase Storage (if selected)
      if (_pickedFile != null && _pickedFile!.path != null) {
        final file = File(_pickedFile!.path!);
        // Create a unique path: announcements/timestamp_filename
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('announcements/${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}');

        // Upload
        final uploadTask = await storageRef.putFile(file);

        // Get URL
        fileUrl = await uploadTask.ref.getDownloadURL();
        fileName = _pickedFile!.name;
      }

      // B. Save to Firestore
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'type': _selectedType,
        'target_date': Timestamp.fromDate(_selectedDate!),
        'created_at': FieldValue.serverTimestamp(),
        'author_id': user.uid,
        // Add file fields (nullable)
        'attachment_url': fileUrl,
        'attachment_name': fileName,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Announcement posted successfully"),
            backgroundColor: AppColors.secondary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error posting: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("New Announcement", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Category", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkGrey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
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

              const Text("Details", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkGrey)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: "Title",
                  hintText: "e.g., CAT 1 Dates",
                  filled: true,
                  fillColor: AppColors.lightGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) => v!.isEmpty ? "Title is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: "Description",
                  hintText: "Enter details...",
                  filled: true,
                  fillColor: AppColors.lightGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) => v!.isEmpty ? "Description is required" : null,
              ),

              const SizedBox(height: 24),

              // --- ATTACHMENT SECTION ---
              const Text("Attachments (Optional)", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkGrey)),
              const SizedBox(height: 8),

              if (_pickedFile == null)
                InkWell(
                  onTap: _pickFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.darkGrey.withOpacity(0.3), style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          "Tap to upload file",
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "PDF, DOC, PPT, JPG (Max 5MB)",
                          style: TextStyle(color: AppColors.darkGrey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pickedFile!.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "${(_pickedFile!.size / 1024).toStringAsFixed(2)} KB",
                              style: const TextStyle(fontSize: 12, color: AppColors.darkGrey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.error),
                        onPressed: _clearFile,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              const Text("Timeline", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkGrey)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDate == null
                            ? "Select Due Date / Sitting Date"
                            : DateFormat('EEE, MMM d, yyyy @ h:mm a').format(_selectedDate!),
                        style: TextStyle(
                          color: _selectedDate == null ? AppColors.darkGrey : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _postAnnouncement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text("UPLOADING...", style: TextStyle(color: Colors.white)),
                    ],
                  )
                      : const Text(
                    "POST ANNOUNCEMENT",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
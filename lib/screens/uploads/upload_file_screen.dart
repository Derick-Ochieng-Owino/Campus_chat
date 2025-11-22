import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/services/firestore_service.dart';
import '../../core/services/file_service.dart';
import '../../providers/user_provider.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/loading_widget.dart';

class FileUploadScreen extends StatefulWidget {
  const FileUploadScreen({super.key});

  @override
  State<FileUploadScreen> createState() => _FileUploadScreenState();
}

class _FileUploadScreenState extends State<FileUploadScreen> {
  final _firestore = FirestoreService();
  final _fileService = FileService();

  String? _selectedUnitId;
  String? _selectedUnitName;
  File? _pickedFile;
  bool _uploading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
    );
    if (result == null) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() {
      _pickedFile = File(path);
    });
  }

  Future<void> _upload() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final uid = userProvider.uid ?? "unknown";

    if (_pickedFile == null || _selectedUnitId == null || _selectedUnitName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select a unit and a file first.")),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      await _fileService.uploadUnitFile(
        file: _pickedFile!,
        unitId: _selectedUnitId!,
        unitName: _selectedUnitName!,
        uploadedBy: uid,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upload successful.")),
      );

      setState(() {
        _pickedFile = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // role check: only class_rep & assistant_rep should upload
    final userProvider = Provider.of<UserProvider>(context);
    final role = userProvider.role ?? "student";
    final canUpload = role == "class_rep" || role == "assistant_rep";

    return Scaffold(
      appBar: AppBar(title: const Text("Upload Files (Class Rep)")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Units dropdown loaded from Firestore
            StreamBuilder(
              stream: _firestore.getSemesterUnits(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Text("No units found for the semester.");
                }

                final docs = snap.data!.docs;
                return DropdownButtonFormField<String>(
                  value: _selectedUnitId,
                  items: docs.map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final id = d.id;
                    final name = data['name'] ?? data['code'] ?? 'Unit';
                    return DropdownMenuItem(
                      value: id,
                      child: Text(name),
                      onTap: () {
                        // capture name on selection
                        _selectedUnitName = name;
                      },
                    );
                  }).toList(),
                  hint: const Text("Select unit"),
                  onChanged: (val) {
                    setState(() {
                      _selectedUnitId = val;
                      // _selectedUnitName is set via onTap above for convenience
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            // File picker
            Row(
              children: [
                Expanded(
                  child: Text(
                    _pickedFile?.path.split('/').last ?? "No file selected",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: canUpload ? _pickFile : null,
                  icon: const Icon(Icons.attach_file),
                  label: const Text("Pick file"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _uploading ? const LoadingWidget() : AppButton(
              text: canUpload ? "Upload" : "You cannot upload (not a class rep)",
              onPressed: canUpload ? _upload : () {},
              loading: _uploading,
            ),
            const SizedBox(height: 12),
            if (!canUpload)
              const Text(
                "Uploads are restricted to class reps and assistant reps.",
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}

// import 'dart:io';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
//
// class CreateAnnouncementScreen extends StatefulWidget {
//   final String? existingDocId;
//   final Map<String, dynamic>? existingData;
//
//   const CreateAnnouncementScreen({
//     super.key,
//     this.existingDocId,
//     this.existingData,
//   });
//
//   @override
//   State<CreateAnnouncementScreen> createState() =>
//       _CreateAnnouncementScreenState();
// }
//
// class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _descController = TextEditingController();
//   final TextEditingController _generalNotesController = TextEditingController();
//
//   String _selectedType = 'Class Confirmation';
//   String _generalMediaType = 'None';
//   String? _selectedUnit;
//   DateTime? _selectedDate;
//
//   PlatformFile? _pickedFile;
//   PlatformFile? _pickedImage;
//   bool _isLoading = false;
//   bool _isFetchingUnits = false;
//   String? _existingAttachmentUrl;
//
//   List<Map<String, dynamic>> _units = [];
//   List<String> _unitDisplayNames = [];
//   Map<String, dynamic>? _userAcademicProfile;
//
//   final List<String> _types = [
//     'General',
//     'Class Confirmation',
//     'Notes',
//     'Assignment',
//     'CAT',
//     'Past Paper',
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchUserUnitsAndProfile().then((_) {
//       if (widget.existingData != null) {
//         _prepopulateFormFields();
//       }
//     });
//   }
//
//   void _prepopulateFormFields() {
//     final data = widget.existingData!;
//     _descController.text = data['description'] ?? '';
//     _selectedType = data['type'] ?? 'General';
//
//     if (data['general_notes'] != null) {
//       _generalMediaType = 'Notes';
//       _generalNotesController.text = data['general_notes'];
//     } else if (data['has_picture'] == true) {
//       _generalMediaType = 'Picture';
//     }
//
//     _existingAttachmentUrl = data['attachment_url'];
//     if (data['target_date'] != null) {
//       _selectedDate = (data['target_date'] as Timestamp).toDate();
//     }
//
//     if (_selectedType != 'General' && _unitDisplayNames.isNotEmpty) {
//       final String? matchingCode = data['unit_id'];
//       final matchIdx = _units.indexWhere(
//         (element) => element['code'] == matchingCode,
//       );
//       if (matchIdx != -1) {
//         _selectedUnit = _unitDisplayNames[matchIdx];
//       }
//     }
//     setState(() {});
//   }
//
//   @override
//   void dispose() {
//     _descController.dispose();
//     _generalNotesController.dispose();
//     super.dispose();
//   }
//
//   String _sanitizePathSegment(String input) {
//     if (input.trim().isEmpty) return 'UNKNOWN';
//     return input
//         .replaceAll(RegExp(r'[^\w\s\-]'), '')
//         .trim()
//         .replaceAll(RegExp(r'[\s\-]+'), '_')
//         .toUpperCase();
//   }
//
//   Future<void> _fetchUserUnitsAndProfile() async {
//     setState(() => _isFetchingUnits = true);
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) return;
//
//       final userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(user.uid)
//           .get();
//       if (userDoc.exists && userDoc.data() != null) {
//         final data = userDoc.data()!;
//         _userAcademicProfile = data;
//         final List<dynamic> unitsList = data['registered_units'] ?? [];
//
//         setState(() {
//           _units = unitsList
//               .map(
//                 (unit) => {
//                   'code': unit['code'] ?? '',
//                   'title': unit['title'] ?? '',
//                 },
//               )
//               .toList();
//
//           _unitDisplayNames = _units
//               .map((unit) => '${unit['code']} - ${unit['title']}')
//               .toList();
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text("Error fetching units: $e"),
//             backgroundColor: Theme.of(context).colorScheme.error,
//           ),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _isFetchingUnits = false);
//     }
//   }
//
//   Future<void> _pickAttachmentFile() async {
//     final result = await FilePicker.platform.pickFiles(
//       type: FileType.custom,
//       allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'png'],
//     );
//     if (result != null) {
//       final file = result.files.first;
//       if (file.size > 5 * 1024 * 1024) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(const SnackBar(content: Text("File size exceeds 5MB")));
//         return;
//       }
//       setState(() {
//         _pickedFile = file;
//         _existingAttachmentUrl = null;
//       });
//     }
//   }
//
//   Future<void> _pickGeneralImage() async {
//     final result = await FilePicker.platform.pickFiles(type: FileType.image);
//     if (result != null) {
//       setState(() {
//         _pickedImage = result.files.first;
//         _existingAttachmentUrl = null;
//       });
//     }
//   }
//
//   Future<void> _pickDate() async {
//     final DateTime? pickedDate = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate ?? DateTime.now(),
//       firstDate: DateTime.now().subtract(const Duration(days: 30)),
//       lastDate: DateTime.now().add(const Duration(days: 365)),
//     );
//
//     if (pickedDate != null && mounted) {
//       final TimeOfDay? pickedTime = await showTimePicker(
//         context: context,
//         initialTime: _selectedDate != null
//             ? TimeOfDay.fromDateTime(_selectedDate!)
//             : TimeOfDay.now(),
//       );
//
//       if (pickedTime != null) {
//         setState(() {
//           _selectedDate = DateTime(
//             pickedDate.year,
//             pickedDate.month,
//             pickedDate.day,
//             pickedTime.hour,
//             pickedTime.minute,
//           );
//         });
//       }
//     }
//   }
//
//   Future<void> _postAnnouncement() async {
//     if (!_formKey.currentState!.validate()) return;
//     if (_selectedType != 'General' && _selectedUnit == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Please select a valid unit.")),
//       );
//       return;
//     }
//
//     final bool needsTimeline =
//         _selectedType == 'Class Confirmation' ||
//         _selectedType == 'Assignment' ||
//         _selectedType == 'CAT';
//     if (needsTimeline && _selectedDate == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("Please choose a required timeline for $_selectedType"),
//         ),
//       );
//       return;
//     }
//     if (_userAcademicProfile == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Profile context routing error.")),
//       );
//       return;
//     }
//
//     setState(() => _isLoading = true);
//
//     try {
//       String? fileUrl = _existingAttachmentUrl;
//       String? fileName = widget.existingData?['attachment_name'];
//
//       if (_selectedType == 'General' &&
//           _generalMediaType == 'Picture' &&
//           _pickedImage != null &&
//           _pickedImage!.path != null) {
//         final storageRef = FirebaseStorage.instance.ref().child(
//           'general_images/${DateTime.now().millisecondsSinceEpoch}_${_pickedImage!.name}',
//         );
//         await storageRef.putFile(File(_pickedImage!.path!));
//         fileUrl = await storageRef.getDownloadURL();
//         fileName = _pickedImage!.name;
//       } else if (_selectedType != 'Class Confirmation' &&
//           _selectedType != 'General' &&
//           _pickedFile != null &&
//           _pickedFile!.path != null) {
//         final storageRef = FirebaseStorage.instance.ref().child(
//           'announcements/${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}',
//         );
//         await storageRef.putFile(File(_pickedFile!.path!));
//         fileUrl = await storageRef.getDownloadURL();
//         fileName = _pickedFile!.name;
//       }
//
//       final int selectedIndex = _selectedUnit != null
//           ? _unitDisplayNames.indexOf(_selectedUnit!)
//           : -1;
//       final String unitCode = selectedIndex != -1
//           ? _units[selectedIndex]['code']
//           : 'GENERAL';
//
//       final String campus = _sanitizePathSegment(
//         _userAcademicProfile?['campus'] ?? 'MAIN_CAMPUS',
//       );
//       final String college = _sanitizePathSegment(
//         _userAcademicProfile?['college'] ?? 'COPAS',
//       );
//       final String school = _sanitizePathSegment(
//         _userAcademicProfile?['school'] ?? 'SCIT',
//       );
//       final String dept = _sanitizePathSegment(
//         _userAcademicProfile?['department'] ?? 'COMPUTING',
//       );
//       final String course = _sanitizePathSegment(
//         _userAcademicProfile?['course'] ?? 'BSc_IT',
//       );
//       final String rawYear =
//           _userAcademicProfile?['year']?.toString().replaceAll(
//             RegExp(r'[^0-9]'),
//             '',
//           ) ??
//           '1';
//       final String rawSem =
//           _userAcademicProfile?['semester']?.toString().replaceAll(
//             RegExp(r'[^0-9]'),
//             '',
//           ) ??
//           '1';
//       final String year = 'YEAR_$rawYear';
//       final String sem = 'SEM_$rawSem';
//
//       final Map<String, dynamic> announcementMap = {
//         'type': _selectedType,
//         'description': _descController.text.trim(),
//         'target_date': _selectedDate != null
//             ? Timestamp.fromDate(_selectedDate!)
//             : null,
//         'updated_at': FieldValue.serverTimestamp(),
//         'attachment_url': fileUrl,
//         'attachment_name': fileName,
//         'title': _selectedType == 'General'
//             ? 'General Announcement'
//             : '$_selectedType: $unitCode',
//         'unit_id': selectedIndex != -1 ? _units[selectedIndex]['code'] : null,
//         'unit_name': selectedIndex != -1
//             ? _units[selectedIndex]['title']
//             : null,
//         'general_notes':
//             (_selectedType == 'General' && _generalMediaType == 'Notes')
//             ? _generalNotesController.text.trim()
//             : null,
//         'has_picture':
//             _selectedType == 'General' && _generalMediaType == 'Picture',
//       };
//
//       final collectionRef = FirebaseFirestore.instance
//           .collection('announcements')
//           .doc(campus)
//           .collection(college)
//           .doc(school)
//           .collection(dept)
//           .doc(course)
//           .collection(year)
//           .doc(sem)
//           .collection('notices');
//
//       if (widget.existingDocId != null) {
//         // Safe modification update patch execution logic path
//         await collectionRef.doc(widget.existingDocId).update(announcementMap);
//       } else {
//         announcementMap['created_at'] = FieldValue.serverTimestamp();
//         announcementMap['author_id'] = FirebaseAuth.instance.currentUser!.uid;
//         announcementMap['campus_routing_id'] = campus;
//         announcementMap['course_routing_id'] = course;
//         await collectionRef.add(announcementMap);
//       }
//
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               widget.existingDocId != null
//                   ? "Announcement updated successfully."
//                   : "Announcement posted successfully.",
//             ),
//           ),
//         );
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text("Operation failed: $e"),
//             backgroundColor: Theme.of(context).colorScheme.error,
//           ),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//     final bool isEditing = widget.existingDocId != null;
//
//     final bool showTimelinePicker =
//         _selectedType == 'General' ||
//         _selectedType == 'Class Confirmation' ||
//         _selectedType == 'Assignment' ||
//         _selectedType == 'CAT';
//
//     return Scaffold(
//       backgroundColor: theme.scaffoldBackgroundColor,
//       appBar: AppBar(
//         title: Text(isEditing ? "Edit Announcement" : "New Announcement"),
//         centerTitle: true,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 "Category",
//                 style: theme.textTheme.bodyMedium?.copyWith(
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               DropdownButtonFormField<String>(
//                 value: _selectedType,
//                 dropdownColor: theme.cardColor,
//                 decoration: InputDecoration(
//                   fillColor: theme.cardColor,
//                   filled: true,
//                 ),
//                 items: _types
//                     .map((t) => DropdownMenuItem(value: t, child: Text(t)))
//                     .toList(),
//                 onChanged: (v) => setState(() {
//                   _selectedType = v!;
//                   if (_selectedType == 'General') _selectedUnit = null;
//                 }),
//               ),
//               const SizedBox(height: 24),
//
//               if (_selectedType != 'General') ...[
//                 Text(
//                   "Select Unit",
//                   style: theme.textTheme.bodyMedium?.copyWith(
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 _isFetchingUnits
//                     ? const Center(child: LinearProgressIndicator())
//                     : DropdownButtonFormField<String>(
//                         value: _selectedUnit,
//                         dropdownColor: theme.cardColor,
//                         hint: const Text("Choose unit"),
//                         decoration: InputDecoration(
//                           fillColor: theme.cardColor,
//                           filled: true,
//                         ),
//                         items: _unitDisplayNames
//                             .map(
//                               (n) => DropdownMenuItem(
//                                 value: n,
//                                 child: Text(
//                                   n,
//                                   maxLines: 1,
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                               ),
//                             )
//                             .toList(),
//                         onChanged: (v) => setState(() => _selectedUnit = v),
//                       ),
//                 const SizedBox(height: 24),
//               ],
//
//               if (_selectedType == 'General') ...[
//                 Text(
//                   "Optional Attachments Filter",
//                   style: theme.textTheme.bodyMedium?.copyWith(
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 SegmentedButton<String>(
//                   segments: const [
//                     ButtonSegment(
//                       value: 'None',
//                       label: Text('None'),
//                       icon: Icon(Icons.block),
//                     ),
//                     ButtonSegment(
//                       value: 'Picture',
//                       label: Text('Add Picture'),
//                       icon: Icon(Icons.image),
//                     ),
//                     ButtonSegment(
//                       value: 'Notes',
//                       label: Text('Add Notes'),
//                       icon: Icon(Icons.sticky_note_2),
//                     ),
//                   ],
//                   selected: {_generalMediaType},
//                   onSelectionChanged: (set) =>
//                       setState(() => _generalMediaType = set.first),
//                 ),
//                 const SizedBox(height: 24),
//
//                 if (_generalMediaType == 'Picture') ...[
//                   Text(
//                     "Upload Image Document",
//                     style: theme.textTheme.bodyMedium?.copyWith(
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   GestureDetector(
//                     onTap: _pickGeneralImage,
//                     child: Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.symmetric(vertical: 20),
//                       decoration: BoxDecoration(
//                         color: theme.cardColor,
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: colorScheme.outlineVariant),
//                       ),
//                       child: Column(
//                         children: [
//                           Icon(
//                             Icons.camera_alt_outlined,
//                             color: colorScheme.primary,
//                             size: 28,
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             _pickedImage == null &&
//                                     _existingAttachmentUrl == null
//                                 ? "Select optional announcement image"
//                                 : (_pickedImage?.name ??
//                                       "Existing Image File Attached"),
//                             style: TextStyle(
//                               color: colorScheme.primary,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 24),
//                 ],
//
//                 if (_generalMediaType == 'Notes') ...[
//                   Text(
//                     "Extra Context Notes",
//                     style: theme.textTheme.bodyMedium?.copyWith(
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   TextFormField(
//                     controller: _generalNotesController,
//                     maxLines: 3,
//                     decoration: const InputDecoration(
//                       hintText: "Type out supplementary text notes...",
//                     ),
//                   ),
//                   const SizedBox(height: 24),
//                 ],
//               ],
//
//               Text(
//                 "Details Description",
//                 style: theme.textTheme.bodyMedium?.copyWith(
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               TextFormField(
//                 controller: _descController,
//                 maxLines: 4,
//                 decoration: const InputDecoration(
//                   hintText:
//                       "Provide description... Links (http://...) match automatically.",
//                 ),
//                 validator: (v) => (v == null || v.isEmpty)
//                     ? "Description cannot be empty"
//                     : null,
//               ),
//               const SizedBox(height: 24),
//
//               if (_selectedType != 'Class Confirmation' &&
//                   _selectedType != 'General') ...[
//                 Text(
//                   "Attachment File (Optional)",
//                   style: theme.textTheme.bodyMedium?.copyWith(
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 GestureDetector(
//                   onTap: _pickAttachmentFile,
//                   child: Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.symmetric(vertical: 20),
//                     decoration: BoxDecoration(
//                       color: theme.cardColor,
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: colorScheme.outlineVariant),
//                     ),
//                     child: Column(
//                       children: [
//                         Icon(
//                           Icons.cloud_upload_outlined,
//                           color: colorScheme.primary,
//                           size: 28,
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           _pickedFile == null && _existingAttachmentUrl == null
//                               ? "Tap to browse local device file storage"
//                               : (_pickedFile?.name ??
//                                     "Existing Document File Attached"),
//                           style: TextStyle(
//                             color: colorScheme.primary,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//               ],
//
//               if (showTimelinePicker) ...[
//                 Text(
//                   _selectedType == 'General'
//                       ? "Timeline (Optional)"
//                       : "Timeline Milestone Schedule",
//                   style: theme.textTheme.bodyMedium?.copyWith(
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 InkWell(
//                   onTap: _pickDate,
//                   child: Container(
//                     padding: const EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       color: theme.cardColor,
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: colorScheme.primary),
//                     ),
//                     child: Row(
//                       children: [
//                         Icon(Icons.calendar_month, color: colorScheme.primary),
//                         const SizedBox(width: 12),
//                         Text(
//                           _selectedDate == null
//                               ? "Select Scheduled Milestone Date"
//                               : DateFormat(
//                                   'EEE, MMM d, yyyy @ h:mm a',
//                                 ).format(_selectedDate!),
//                           style: const TextStyle(fontWeight: FontWeight.w500),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//               const SizedBox(height: 40),
//               SizedBox(
//                 width: double.infinity,
//                 height: 52,
//                 child: _isLoading
//                     ? const Center(child: CircularProgressIndicator())
//                     : FilledButton(
//                         onPressed: _postAnnouncement,
//                         child: Text(
//                           isEditing
//                               ? "SAVE UPDATED MODIFICATIONS"
//                               : "POST ANNOUNCEMENT",
//                           style: const TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 14,
//                           ),
//                         ),
//                       ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  final String? existingDocId;
  final Map<String, dynamic>? existingData;

  const CreateAnnouncementScreen({super.key, this.existingDocId, this.existingData});

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _generalNotesController = TextEditingController();

  String _selectedType = 'Class Confirmation';
  String _generalMediaType = 'None';
  String? _selectedUnit;
  DateTime? _selectedDate;

  PlatformFile? _pickedFile;
  PlatformFile? _pickedImage;
  bool _isLoading = false;
  bool _isFetchingUnits = false;
  String? _existingAttachmentUrl;

  List<Map<String, dynamic>> _units = [];
  List<String> _unitDisplayNames = [];
  Map<String, dynamic>? _userAcademicProfile;

  final List<String> _types = ['General', 'Class Confirmation', 'Notes', 'Assignment', 'CAT', 'Past Paper'];

  @override
  void initState() {
    super.initState();
    _fetchUserUnitsAndProfile().then((_) {
      if (widget.existingData != null) _prepopulateFormFields();
    });
  }

  void _prepopulateFormFields() {
    final data = widget.existingData!;
    _descController.text = data['description'] ?? '';
    _selectedType = data['type'] ?? 'General';

    if (data['general_notes'] != null) {
      _generalMediaType = 'Notes';
      _generalNotesController.text = data['general_notes'];
    } else if (data['has_picture'] == true) {
      _generalMediaType = 'Picture';
    }

    _existingAttachmentUrl = data['attachment_url'];
    if (data['target_date'] != null) _selectedDate = (data['target_date'] as Timestamp).toDate();

    if (_selectedType != 'General' && _unitDisplayNames.isNotEmpty) {
      final String? matchingCode = data['unit_id'];
      final matchIdx = _units.indexWhere((e) => e['code'] == matchingCode);
      if (matchIdx != -1) _selectedUnit = _unitDisplayNames[matchIdx];
    }
    setState(() {});
  }

  @override
  void dispose() {
    _descController.dispose();
    _generalNotesController.dispose();
    super.dispose();
  }

  String _sanitizePathSegment(String input) {
    if (input.trim().isEmpty) return 'UNKNOWN';
    return input.replaceAll(RegExp(r'[^\w\s\-]'), '').trim().replaceAll(RegExp(r'[\s\-]+'), '_').toUpperCase();
  }

  Future<void> _fetchUserUnitsAndProfile() async {
    setState(() => _isFetchingUnits = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        _userAcademicProfile = data;
        final List<dynamic> unitsList = data['registered_units'] ?? [];

        setState(() {
          _units = unitsList.map((u) => {'code': u['code'] ?? '', 'title': u['title'] ?? ''}).toList();
          _unitDisplayNames = _units.map((u) => '${u['code']} - ${u['title']}').toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching units: $e"), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) setState(() => _isFetchingUnits = false);
    }
  }

  Future<void> _pickAttachmentFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'png']);
    if (result != null) {
      final file = result.files.first;
      if (file.size > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File size exceeds 5MB")));
        return;
      }
      setState(() { _pickedFile = file; _existingAttachmentUrl = null; });
    }
  }

  Future<void> _pickGeneralImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() { _pickedImage = result.files.first; _existingAttachmentUrl = null; });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDate != null ? TimeOfDay.fromDateTime(_selectedDate!) : TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() { _selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute); });
      }
    }
  }

  Future<void> _postAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType != 'General' && _selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a valid unit.")));
      return;
    }

    if ((_selectedType == 'Class Confirmation' || _selectedType == 'Assignment' || _selectedType == 'CAT') && _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please choose a required timeline for $_selectedType")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? fileUrl = _existingAttachmentUrl;
      String? fileName = widget.existingData?['attachment_name'];

      if (_selectedType == 'General' && _generalMediaType == 'Picture' && _pickedImage != null && _pickedImage!.path != null) {
        final storageRef = FirebaseStorage.instance.ref().child('general_images/${DateTime.now().millisecondsSinceEpoch}_${_pickedImage!.name}');
        await storageRef.putFile(File(_pickedImage!.path!));
        fileUrl = await storageRef.getDownloadURL();
        fileName = _pickedImage!.name;
      } else if (_selectedType != 'Class Confirmation' && _selectedType != 'General' && _pickedFile != null && _pickedFile!.path != null) {
        final storageRef = FirebaseStorage.instance.ref().child('announcements/${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}');
        await storageRef.putFile(File(_pickedFile!.path!));
        fileUrl = await storageRef.getDownloadURL();
        fileName = _pickedFile!.name;
      }

      final int selectedIndex = _selectedUnit != null ? _unitDisplayNames.indexOf(_selectedUnit!) : -1;
      final String unitCode = selectedIndex != -1 ? _units[selectedIndex]['code'] : 'GENERAL';

      final String campus = _sanitizePathSegment(_userAcademicProfile?['campus'] ?? 'MAIN_CAMPUS');
      final String college = _sanitizePathSegment(_userAcademicProfile?['college'] ?? 'COPAS');
      final String school = _sanitizePathSegment(_userAcademicProfile?['school'] ?? 'SCIT');
      final String dept = _sanitizePathSegment(_userAcademicProfile?['department'] ?? 'COMPUTING');
      final String course = _sanitizePathSegment(_userAcademicProfile?['course'] ?? 'BSc_IT');
      final String rawYear = _userAcademicProfile?['year']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '1';
      final String rawSem = _userAcademicProfile?['semester']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '1';
      final String year = 'YEAR_$rawYear';
      final String sem = 'SEM_$rawSem';

      final Map<String, dynamic> announcementMap = {
        'type': _selectedType,
        'description': _descController.text.trim(),
        'target_date': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
        'updated_at': FieldValue.serverTimestamp(),
        'attachment_url': fileUrl,
        'attachment_name': fileName,
        'title': _selectedType == 'General' ? 'General Announcement' : '$_selectedType: $unitCode',
        'unit_id': selectedIndex != -1 ? _units[selectedIndex]['code'] : null,
        'unit_name': selectedIndex != -1 ? _units[selectedIndex]['title'] : null,
        'general_notes': (_selectedType == 'General' && _generalMediaType == 'Notes') ? _generalNotesController.text.trim() : null,
        'has_picture': _selectedType == 'General' && _generalMediaType == 'Picture',
      };

      final collectionRef = FirebaseFirestore.instance
          .collection('announcements')
          .doc(campus)
          .collection(college)
          .doc(school)
          .collection(dept)
          .doc(course)
          .collection(year)
          .doc(sem)
          .collection('notices');

      if (widget.existingDocId != null) {
        await collectionRef.doc(widget.existingDocId).update(announcementMap);
      } else {
        announcementMap['created_at'] = FieldValue.serverTimestamp();
        announcementMap['author_id'] = FirebaseAuth.instance.currentUser!.uid;
        announcementMap['campus_routing_id'] = campus;
        announcementMap['course_routing_id'] = course;
        await collectionRef.add(announcementMap);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.existingDocId != null ? "Announcement updated successfully." : "Announcement posted successfully.")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Operation failed: $e"), backgroundColor: Theme.of(context).colorScheme.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isEditing = widget.existingDocId != null;
    final bool showTimelinePicker = _selectedType == 'General' || _selectedType == 'Class Confirmation' || _selectedType == 'Assignment' || _selectedType == 'CAT';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(isEditing ? "Edit Announcement" : "New Announcement"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Category", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                dropdownColor: theme.cardColor,
                decoration: InputDecoration(fillColor: theme.cardColor, filled: true),
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() { _selectedType = v!; if (_selectedType == 'General') _selectedUnit = null; }),
              ),
              const SizedBox(height: 24),
              if (_selectedType != 'General') ...[
                Text("Select Unit", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _isFetchingUnits
                    ? const Center(child: LinearProgressIndicator())
                    : DropdownButtonFormField<String>(
                  initialValue: _selectedUnit,
                  dropdownColor: theme.cardColor,
                  hint: const Text("Choose unit"),
                  decoration: InputDecoration(fillColor: theme.cardColor, filled: true),
                  items: _unitDisplayNames.map((n) => DropdownMenuItem(value: n, child: Text(n, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _selectedUnit = v),
                ),
                const SizedBox(height: 24),
              ],
              if (_selectedType == 'General') ...[
                Text("Optional Attachments Filter", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'None', label: Text('None'), icon: Icon(Icons.block)),
                    ButtonSegment(value: 'Picture', label: Text('Add Picture'), icon: Icon(Icons.image)),
                    ButtonSegment(value: 'Notes', label: Text('Add Notes'), icon: Icon(Icons.sticky_note_2)),
                  ],
                  selected: {_generalMediaType},
                  onSelectionChanged: (set) => setState(() => _generalMediaType = set.first),
                ),
                const SizedBox(height: 24),
                if (_generalMediaType == 'Picture') ...[
                  Text("Upload Image Document", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickGeneralImage,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: colorScheme.outlineVariant)),
                      child: Column(
                        children: [
                          Icon(Icons.camera_alt_outlined, color: colorScheme.primary, size: 28),
                          const SizedBox(height: 8),
                          Text(_pickedImage == null && _existingAttachmentUrl == null ? "Select optional announcement image" : (_pickedImage?.name ?? "Existing Image Attached"), style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (_generalMediaType == 'Notes') ...[
                  Text("Extra Context Notes", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(controller: _generalNotesController, maxLines: 3, decoration: const InputDecoration(hintText: "Type supplementary context notes...")),
                  const SizedBox(height: 24),
                ],
              ],
              Text("Details Description", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(hintText: "Provide description... Links (http://...) match automatically."),
                validator: (v) => (v == null || v.isEmpty) ? "Description cannot be empty" : null,
              ),
              const SizedBox(height: 24),
              if (_selectedType != 'Class Confirmation' && _selectedType != 'General') ...[
                Text("Attachment File (Optional)", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickAttachmentFile,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: colorScheme.outlineVariant)),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: colorScheme.primary, size: 28),
                        const SizedBox(height: 8),
                        Text(_pickedFile == null && _existingAttachmentUrl == null ? "Tap to browse local device file storage" : (_pickedFile?.name ?? "Existing Document Attached"), style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (showTimelinePicker) ...[
                Text(_selectedType == 'General' ? "Timeline (Optional)" : "Timeline Milestone Schedule", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: colorScheme.primary)),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(_selectedDate == null ? "Select Scheduled Milestone Date" : DateFormat('EEE, MMM d, yyyy @ h:mm a').format(_selectedDate!), style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton(
                  onPressed: _postAnnouncement,
                  child: Text(isEditing ? "SAVE UPDATED MODIFICATIONS" : "POST ANNOUNCEMENT", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
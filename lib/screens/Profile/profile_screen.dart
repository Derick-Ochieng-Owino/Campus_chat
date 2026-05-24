import 'package:flutter/material.dart';
import '../../models/student_id_model.dart';
import '../../services/student_id_service.dart';
import '../../widgets/student_id_flip_card.dart';

class StudentIdScreen extends StatefulWidget {
  const StudentIdScreen({super.key});

  @override
  State<StudentIdScreen> createState() => _StudentIdScreenState();
}

class _StudentIdScreenState extends State<StudentIdScreen> {
  final StudentIdService _service = StudentIdService();

  StudentIdModel? _studentId;
  bool _isLoading = true;
  String? _error;
  bool _isOfflineData = false;

  @override
  void initState() {
    super.initState();
    _loadId();
  }

  Future<void> _loadId() async {
    try {
      final online = await _service.getStudentId();
      if (!mounted) return;

      if (online != null) {
        setState(() {
          _studentId = online;
          _isLoading = false;
          _isOfflineData = false;
        });
        return;
      }

      final cached = await _service.getCachedStudentId();
      if (!mounted) return;

      setState(() {
        _studentId = cached;
        _isLoading = false;
        _isOfflineData = cached != null;
        _error = cached == null ? 'No student ID data found.' : null;
      });
    } catch (e) {
      final cached = await _service.getCachedStudentId();
      if (!mounted) return;

      setState(() {
        _studentId = cached;
        _isLoading = false;
        _isOfflineData = cached != null;
        _error = cached == null ? 'Failed to load student ID.' : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student ID'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : _error != null
              ? Text(_error!, style: theme.textTheme.bodyLarge)
              : Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isOfflineData)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Showing cached ID data',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: StudentIdFlipCard(data: _studentId!),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tap the card to flip',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
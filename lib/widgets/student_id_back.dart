import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/student_id_model.dart';

class StudentIdBack extends StatelessWidget {
  const StudentIdBack({
    super.key,
    required this.data,
  });

  final StudentIdModel data;

  @override
  Widget build(BuildContext context) {
    final qrPayload = '''
uid:${data.uid}
name:${data.fullName}
reg:${data.regNumber}
course:${data.course}
school:${data.school}
validity:${data.validity}
''';

    return AspectRatio(
      aspectRatio: 1.58,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFFF8F8F8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.06,
                  child: Image.asset(
                    'assets/images/jkuat_watermark.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VERIFICATION CARD BACK',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: QrImageView(
                                data: qrPayload,
                                version: QrVersions.auto,
                                size: 180,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DefaultTextStyle(
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('NAME: ${data.fullName.toUpperCase()}'),
                                  Text('REG NO: ${data.regNumber.toUpperCase()}'),
                                  Text('COURSE: ${data.course.toUpperCase()}'),
                                  Text('SCHOOL: ${data.school.toUpperCase()}'),
                                  Text('VALID: ${data.validity}'),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Scan QR to verify this student card in-app.',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Property of JKUAT. If found, return to the University administration.',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
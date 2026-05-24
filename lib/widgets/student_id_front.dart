import 'dart:io';
import 'package:flutter/material.dart';
import '../models/student_id_model.dart';

class StudentIdFront extends StatelessWidget {
  const StudentIdFront({
    super.key,
    required this.data,
  });

  final StudentIdModel data;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.58,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFFF5F7F2),
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
                  opacity: 1,
                  child: Image.asset(
                    'assets/images/jkuat_watermark.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 10,
                            child: _leftStrip(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 58,
                            child: _centerDetails(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 32,
                            child: _photoBox(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'VALID: ${data.validity}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.0,
                        ),
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

  Widget _leftStrip() {
    return RotatedBox(
      quarterTurns: 3,
      child: Align(
        alignment: Alignment.center,
        child: Text(
          'VALID: ${data.validity}',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _centerDetails() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/jkuat_logo.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.school, size: 32);
                  },
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'JOMO KENYATTA UNIVERSITY OF\nAGRICULTURE & TECHNOLOGY',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black38,
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
                          height: 1.05,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '"A University of global excellence in Training, Research,\nInnovation and Entrepreneurship for development."',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black38,
                          fontSize: 7.2,
                          fontStyle: FontStyle.italic,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: maxWidth,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              color: const Color(0xFFCC2D2D),
              child: const FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  'STUDENT IDENTIFICATION CARD',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _compactLine(data.fullName.toUpperCase()),
            _compactLine(data.course.toUpperCase()),
            _compactLine(data.regNumber.toUpperCase()),
            _compactLine(data.school.toUpperCase()),
          ],
        );
      },
    );
  }

  Widget _compactLine(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _line(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 15,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _photoBox() {
    final hasLocal = data.localPhotoPath != null && data.localPhotoPath!.isNotEmpty;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF1E4FB1), width: 3),
          color: Colors.white,
        ),
        child: hasLocal
            ? Image.file(
          File(data.localPhotoPath!),
          fit: BoxFit.cover,
          width: double.infinity,
        )
            : const Center(
          child: Icon(Icons.person, size: 60),
        ),
      ),
    );
  }
}
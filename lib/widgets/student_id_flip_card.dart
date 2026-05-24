import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/student_id_model.dart';
import 'student_id_back.dart';
import 'student_id_front.dart';

class StudentIdFlipCard extends StatefulWidget {
  const StudentIdFlipCard({
    super.key,
    required this.data,
  });

  final StudentIdModel data;

  @override
  State<StudentIdFlipCard> createState() => _StudentIdFlipCardState();
}

class _StudentIdFlipCardState extends State<StudentIdFlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_showFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _showFront = !_showFront;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * math.pi;
          final isFrontVisible = angle < math.pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: isFrontVisible
                ? widgetFront()
                : Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: widgetBack(),
            ),
          );
        },
      ),
    );
  }

  Widget widgetFront() => StudentIdFront(data: widget.data);

  Widget widgetBack() => StudentIdBack(data: widget.data);
}
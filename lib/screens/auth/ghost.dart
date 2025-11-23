import 'package:flutter/material.dart';

class InteractiveGhost extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isPasswordField;
  final bool isPasswordVisible; // <--- NEW PARAMETER
  final double size;

  const InteractiveGhost({
    Key? key,
    required this.controller,
    required this.focusNode,
    this.isPasswordField = false,
    this.isPasswordVisible = false, // <--- Default false
    this.size = 200,
  }) : super(key: key);

  @override
  State<InteractiveGhost> createState() => _InteractiveGhostState();
}

class _InteractiveGhostState extends State<InteractiveGhost>
    with TickerProviderStateMixin {

  late AnimationController _armController;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  double _pupilMovePos = 0.0;
  bool _hasAtSymbol = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();

    _armController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _floatAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _floatController.repeat(reverse: true);

    widget.controller.addListener(_updateGhostState);
    widget.focusNode.addListener(_onFocusChange);

    _updateGhostState();
    _onFocusChange();

    // Check initial arm state
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArmState());
  }

  @override
  void didUpdateWidget(InteractiveGhost oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_updateGhostState);
      widget.controller.addListener(_updateGhostState);
      _updateGhostState();
    }

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      _onFocusChange();
    }

    // NEW: If password visibility changes, or we switch fields, update arms
    if (widget.isPasswordField != oldWidget.isPasswordField ||
        widget.isPasswordVisible != oldWidget.isPasswordVisible) {
      _updateArmState();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateGhostState);
    widget.focusNode.removeListener(_onFocusChange);
    _armController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = widget.focusNode.hasFocus;
    });
    _updateArmState();
  }

  // CENTRALIZED ARM LOGIC
  void _updateArmState() {
    // We only cover eyes if:
    // 1. It IS a password field
    // 2. It HAS focus
    // 3. The password is NOT visible (Hidden)
    bool shouldCoverEyes = widget.isPasswordField &&
        widget.focusNode.hasFocus &&
        !widget.isPasswordVisible;

    if (shouldCoverEyes) {
      _armController.forward(); // Arms Up
    } else {
      _armController.reverse(); // Arms Down (Peek)
    }
  }

  void _updateGhostState() {
    final text = widget.controller.text;

    setState(() {
      if (text.isNotEmpty) {
        if (text.contains('@') && text.indexOf('@') < text.length - 1) {
          _hasAtSymbol = true;
        } else {
          _hasAtSymbol = false;
        }
      }
      _pupilMovePos = text.length > 30 ? 13.33 : text.length / 2.25;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_armController, _floatController]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: GhostPathPainter(
              pupilMovePos: _pupilMovePos,
              hasAtSymbol: _hasAtSymbol,
              isFocused: _isFocused,
              isPasswordField: widget.isPasswordField,
              textLength: widget.controller.text.length,
              armAnimValue: _armController.value,
            ),
          ),
        );
      },
    );
  }
}

class GhostPathPainter extends CustomPainter {
  final double pupilMovePos;
  final bool hasAtSymbol;
  final bool isFocused;
  final bool isPasswordField;
  final int textLength;
  final double armAnimValue;

  GhostPathPainter({
    required this.pupilMovePos,
    required this.hasAtSymbol,
    required this.isFocused,
    required this.isPasswordField,
    required this.textLength,
    required this.armAnimValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200;
    canvas.scale(scale);

    final bodyFillPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final eyeFillPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFF999999)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pupilPaint = Paint()..color = const Color(0xFF333333)..style = PaintingStyle.fill;

    // --- 1. BODY ---
    final bodyPath = Path()
      ..moveTo(54, 181)
      ..cubicTo(44, 131, 13, 11, 99, 11)
      ..cubicTo(185, 12, 164, 110, 150, 182)
      ..cubicTo(146, 195, 139, 185, 137, 177)
      ..cubicTo(134, 170, 126, 169, 124, 179)
      ..cubicTo(120, 192, 114, 190, 109, 179)
      ..cubicTo(105, 167, 98, 166, 94, 179)
      ..cubicTo(92, 185, 85, 193, 79, 179)
      ..cubicTo(74, 170, 68, 168, 66, 179)
      ..cubicTo(62, 193, 56, 191, 54, 181)
      ..close();

    canvas.drawPath(bodyPath, bodyFillPaint);
    canvas.drawPath(bodyPath, strokePaint);

    // --- 2. EYES ---
    final eyeRightPath = Path()
      ..moveTo(69, 71)
      ..cubicTo(69, 64, 73, 54, 84, 55)
      ..cubicTo(96, 56, 100, 62, 100, 70)
      ..cubicTo(100, 79, 89, 83, 84, 83)
      ..cubicTo(78, 83, 69, 80, 69, 71)..close();

    final eyeLeftPath = Path()
      ..moveTo(105, 73)
      ..cubicTo(104, 66, 108, 57, 120, 57)
      ..cubicTo(130, 57, 134, 65, 134, 71)
      ..cubicTo(134, 80, 125, 85, 119, 85)
      ..cubicTo(114, 85, 105, 82, 105, 73)..close();

    canvas.drawPath(eyeRightPath, eyeFillPaint);
    canvas.drawPath(eyeLeftPath, eyeFillPaint);
    canvas.drawPath(eyeRightPath, strokePaint);
    canvas.drawPath(eyeLeftPath, strokePaint);

    // --- 3. PUPILS ---
    double rPx, rPy, lPx, lPy;

    if (!isPasswordField && isFocused) {
      rPx = 78 + pupilMovePos;
      rPy = 75;
      lPx = 113 + pupilMovePos;
      lPy = 76;
    } else {
      rPx = 84; rPy = 69;
      lPx = 120; lPy = 71;
    }

    canvas.drawCircle(Offset(rPx, rPy), 4, pupilPaint);
    canvas.drawCircle(Offset(lPx, lPy), 4, pupilPaint);

    // --- 4. MOUTH ---
    final mouthPath = Path();

    if (!isPasswordField && textLength > 0) {
      if (hasAtSymbol) {
        mouthPath.moveTo(75, 115);
        mouthPath.cubicTo(79, 110, 92, 117, 102, 117);
        mouthPath.cubicTo(111, 117, 123, 111, 127, 114);
        mouthPath.cubicTo(131, 117, 123, 136, 102, 136);
        mouthPath.cubicTo(81, 137, 73, 121, 75, 115);
      } else {
        mouthPath.moveTo(75, 115);
        mouthPath.cubicTo(79, 110, 92, 119, 101, 119);
        mouthPath.cubicTo(110, 119, 123, 111, 127, 114);
        mouthPath.cubicTo(131, 117, 118, 131, 102, 132);
        mouthPath.cubicTo(87, 132, 73, 121, 75, 115);
      }
    } else {
      mouthPath.moveTo(75, 115);
      mouthPath.cubicTo(79, 120, 91, 126, 101, 125);
      mouthPath.cubicTo(110, 125, 126, 118, 127, 114);
      mouthPath.cubicTo(125, 117, 117, 125, 101, 125);
      mouthPath.cubicTo(85, 126, 79, 117, 75, 115);
    }
    mouthPath.close();

    Color mouthColor;
    if (isPasswordField && isFocused) {
      mouthColor = Colors.white;
    } else if (hasAtSymbol) {
      mouthColor = const Color(0xFF55AA55);
    } else if (textLength > 0) {
      mouthColor = const Color(0xFFAA4040);
    } else {
      mouthColor = const Color(0xFFAA4040);
    }

    canvas.drawPath(mouthPath, Paint()..color = mouthColor..style = PaintingStyle.fill);
    canvas.drawPath(mouthPath, Paint()..color = const Color(0xFF660000)..style = PaintingStyle.stroke..strokeWidth = 2);

    // --- 5. ARMS ---
    final rightArmPath = Path();
    rightArmPath.moveTo(45, 89);
    rightArmPath.cubicTo(
        _lerp(25, 54, armAnimValue), _lerp(92, 64, armAnimValue),
        _lerp(9, 103, armAnimValue), _lerp(108, 48, armAnimValue),
        _lerp(11, 106, armAnimValue), _lerp(124, 64, armAnimValue)
    );
    rightArmPath.cubicTo(
        _lerp(13, 108, armAnimValue), _lerp(141, 80, armAnimValue),
        _lerp(27, 65, armAnimValue), _lerp(115, 121, armAnimValue),
        48, 119
    );
    rightArmPath.close();

    canvas.drawPath(rightArmPath, bodyFillPaint);
    canvas.drawPath(rightArmPath, strokePaint);

    final leftArmPath = Path();
    leftArmPath.moveTo(155, 88);
    leftArmPath.cubicTo(
        _lerp(191, 145, armAnimValue), _lerp(90, 68, armAnimValue),
        _lerp(194, 105, armAnimValue), _lerp(114, 51, armAnimValue),
        _lerp(192, 103, armAnimValue), _lerp(125, 62, armAnimValue)
    );
    leftArmPath.cubicTo(
        _lerp(191, 102, armAnimValue), _lerp(137, 74, armAnimValue),
        _lerp(172, 123, armAnimValue), _lerp(109, 117, armAnimValue),
        155, 116
    );
    leftArmPath.close();

    canvas.drawPath(leftArmPath, bodyFillPaint);
    canvas.drawPath(leftArmPath, strokePaint);
  }

  double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  @override
  bool shouldRepaint(GhostPathPainter oldDelegate) {
    return oldDelegate.pupilMovePos != pupilMovePos ||
        oldDelegate.hasAtSymbol != hasAtSymbol ||
        oldDelegate.isFocused != isFocused ||
        oldDelegate.armAnimValue != armAnimValue ||
        oldDelegate.textLength != textLength;
  }
}
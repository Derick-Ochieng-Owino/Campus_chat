import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile_model.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showBackOfCard = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: Text(
            'No active authentication profile session.',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
        title: Text(
          'Student Hub Profile',
          style: theme.appBarTheme.titleTextStyle,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading profile stream context.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: theme.colorScheme.secondary),
            );
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final profile = UserProfile.fromMap(data, user.uid);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Flippable Digital Student Identity Badge Container ---
                GestureDetector(
                  onTap: () => setState(() => _showBackOfCard = !_showBackOfCard),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return rotationYTransform(animation, child);
                    },
                    child: _showBackOfCard ? _buildCardBack(profile) : _buildCardFront(profile, theme),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flip_camera_android_rounded, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Text(
                        'Tap card block to view structural verification flip-side',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // --- Live Registered Units Stack ---
                Text(
                  'Registered Academic Units',
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 12),
                if (profile.registeredUnits.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'No active semester structural course units registered.',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: profile.registeredUnits.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final unit = profile.registeredUnits[index];
                      final String unitCode = unit['code']?.toString() ?? 'UNIT';
                      final String unitTitle = unit['title']?.toString() ?? 'Course Module Unit Description';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                unitCode,
                                style: TextStyle(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                unitTitle,
                                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                            const Icon(Icons.verified_user_rounded, color: Colors.greenAccent, size: 18),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 28),

                // --- Auxiliary Parameters Overview Block ---
                Text(
                  'Ecosystem Auxiliary Details',
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildAuxRow(theme, 'Institutional Reference ID', profile.uid.substring(0, 8).toUpperCase()),
                      Divider(color: theme.dividerTheme.color, height: 24),
                      _buildAuxRow(theme, 'Current Account Standing', 'Year ${profile.year}, Semester ${profile.semester}'),
                      Divider(color: theme.dividerTheme.color, height: 24),
                      _buildAuxRow(theme, 'Assigned Campus Domain', profile.campus),
                      if (profile.nickname != null && profile.nickname!.isNotEmpty) ...[
                        Divider(color: theme.dividerTheme.color, height: 24),
                        _buildAuxRow(theme, 'Internal App Profile Tag', profile.nickname!),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAuxRow(ThemeData theme, String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
        Text(val, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // --- Front Profile Layout (Matches physical identity sheet styling parameters) ---
  Widget _buildCardFront(UserProfile profile, ThemeData theme) {
    const darkTextColor = Color(0xFF111111);

    return Container(
      key: const ValueKey(true),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFBEF7BC), // #bef7bc background base configuration
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9CCC65), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Watermark Layer (Locked strictly to 70x70 dimensions)
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: 110,
                height: 110,
                child: Image.asset(
                  'assets/images/jkuat_logo.png',
                  fit: BoxFit.contain,
                  opacity: const AlwaysStoppedAnimation(0.12),
                ),
              ),
            ),
          ),

          // 2. Uniform Triangle Mesh Layer with scaled-down mesh size
          Positioned.fill(
            child: CustomPaint(
              painter: JkuatCardPatternPainter(),
            ),
          ),

          // 3. Dynamic Profile Information UI Layer
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/jkuat_logo.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.university.split('&')[0].trim(),
                            style: const TextStyle(color: darkTextColor, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                          ),
                          if (profile.university.contains('&'))
                            Text(
                              '& ${profile.university.split('&')[1].trim()}',
                              style: const TextStyle(color: darkTextColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                            ),
                          const SizedBox(height: 2),
                          const Text(
                            '"A University of global excellence in Training, Research, Innovation and Entrepreneurship for development."',
                            style: TextStyle(color: Colors.black87, fontSize: 7, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            color: const Color(0xFFC62828),
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: const Text(
                              'STUDENT IDENTIFICATION CARD',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                            ),
                          ),
                          Text(
                            profile.fullName,
                            style: const TextStyle(color: darkTextColor, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                          ),
                          const SizedBox(height: 10),
                          const Text('COURSE', style: TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.bold)),
                          Text(
                            profile.course,
                            style: const TextStyle(color: darkTextColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          const Text('REG NO', style: TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.bold)),
                          Text(
                            profile.regNumber,
                            style: const TextStyle(color: darkTextColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 10),
                          const Text('COLLEGE', style: TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.bold)),
                          Text(
                            profile.college,
                            style: const TextStyle(color: darkTextColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        Container(
                          width: 85,
                          height: 105,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D1D6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black26, width: 1.5),
                            image: profile.profilePhotoUrl != null
                                ? DecorationImage(image: NetworkImage(profile.profilePhotoUrl!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: profile.profilePhotoUrl == null ? const Icon(Icons.person_rounded, size: 40, color: Colors.black38) : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'VALID: ${profile.validityPeriod}',
                          style: const TextStyle(color: darkTextColor, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Identity Sheet Back View ---
  Widget _buildCardBack(UserProfile profile) {
    return Container(
      key: const ValueKey(false),
      width: double.infinity,
      height: 226,
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'IF FOUND RETURN TO JKUAT MAIN CAMPUS,\nOR POST TO P.O. BOX 62000-00200, NRB. Kenya.\nTel: 254-67-52711/52181-4 Fax: 254-67-52164\nwww.jkuat.ac.ke',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.bold, height: 1.4),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              Container(
                width: 180,
                height: 38,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage('https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/Bar_code_128.svg/800px-Bar_code_128.svg.png'),
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.regNumber,
                style: const TextStyle(color: Colors.black, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('------------------', style: TextStyle(color: Colors.black38, fontSize: 10)),
                  SizedBox(height: 2),
                  Text('Student Signature', style: TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4), width: 1.5),
                ),
                child: const Icon(Icons.gavel_rounded, color: Colors.blueAccent, size: 20),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget rotationYTransform(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final angle = animation.value * 3.141592653589793;
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          alignment: Alignment.center,
          child: angle >= 1.5707963267948966
              ? Transform(
            transform: Matrix4.identity()..rotateY(3.141592653589793),
            alignment: Alignment.center,
            child: child,
          )
              : child,
        );
      },
    );
  }
}

class JkuatCardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset centerPoint = Offset(size.width / 2, size.height / 2);
    // Tight radius constraint to envelope the 70x70 canvas center gap clean space securely
    const double plainSpaceRadius = 48.0;

    final Path totalCanvasPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final Path clearCirclePath = Path()
      ..addOval(Rect.fromCircle(center: centerPoint, radius: plainSpaceRadius));

    final Path gridMaskPath = Path.combine(
      PathOperation.difference,
      totalCanvasPath,
      clearCirclePath,
    );

    canvas.save();
    canvas.clipPath(gridMaskPath);

    final Paint linePaint = Paint()
      ..color = const Color(0xFF1B5E20).withValues(alpha: 0.18) // Slightly lower alpha for dense line density readability
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6; // Thinner strokes to prevent the smaller pattern from looking crowded

    final Paint fillPaint = Paint()
      ..color = const Color(0xFF1B5E20).withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    // Shrunk down layout metrics for tight uniform density pattern
    const double triangleWidth = 24.0;
    const double triangleHeight = triangleWidth * 0.866025;

    final int colCount = (size.width / triangleWidth).ceil() + 1;
    final int rowCount = (size.height / triangleHeight).ceil() + 1;

    for (int row = -1; row <= rowCount; row++) {
      for (int col = -1; col <= colCount; col++) {
        final double xOffset = (row % 2 == 0) ? 0 : triangleWidth / 2;

        final double currentX = col * triangleWidth + xOffset;
        final double currentY = row * triangleHeight;

        final double nextX = currentX + triangleWidth;
        final double bottomX = currentX - (row % 2 == 0 ? -triangleWidth / 2 : triangleWidth / 2);
        final double bottomY = currentY + triangleHeight;
        final double nextBottomX = bottomX + triangleWidth;

        final Path pathA = Path()
          ..moveTo(currentX, currentY)
          ..lineTo(nextX, currentY)
          ..lineTo(nextBottomX, bottomY)
          ..close();

        final Path pathB = Path()
          ..moveTo(currentX, currentY)
          ..lineTo(bottomX, bottomY)
          ..lineTo(nextBottomX, bottomY)
          ..close();

        if ((col + row) % 2 == 0) {
          canvas.drawPath(pathA, fillPaint);
        } else {
          canvas.drawPath(pathB, fillPaint);
        }

        canvas.drawPath(pathA, linePaint);
        canvas.drawPath(pathB, linePaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
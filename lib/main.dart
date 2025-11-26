
import 'dart:convert';

import 'package:campus_app/providers/theme_provider.dart';
import 'package:campus_app/screens/Profile/complete_profile.dart';
import 'package:campus_app/screens/groups/groups_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Import your screens
import 'screens/auth/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'providers/chat_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider())
      ],
      child: const MyApp(),
    ),
  );
}

// ======================================================
// ROUTES CONFIGURATION
// ======================================================
class AppRoutes {
  static const String home = "/home";
  static const String fileUpload = "/file-upload";
  static const String courseUnits = "/course-units";
  static const String groups = '/groups';
  static const String profile = '/profile';
  static const String login = '/login';
  static const String signup = '/signup';

  static Map<String, WidgetBuilder> get routes => {
    home: (context) => const HomePage(),
    groups: (context) => const GroupsTab(),
    login: (context) => const LoginPage(),
    signup: (context) => const SignUpPage(),
  };
}

// ======================================================
// MAIN APP WIDGET
// ======================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Campus Hub',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      // We do NOT set initialRoute here because we want 'home' to take precedence.
      // The SplashScreen acts as the gatekeeper to decide where to go next.
      home: const SplashScreen(),
      routes: AppRoutes.routes,
    );
  }
}


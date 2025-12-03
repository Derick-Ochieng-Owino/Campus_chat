import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';

import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/groups/groups_screen.dart';

import 'firebase_options.dart';

// Conditional import for Windows (only if you have a custom wrapper)
import 'firebase_stub.dart'
if (dart.library.io) 'firebase_windows.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for all platforms
  await FirebaseInitializer.initialize();

  // Check if user has completed onboarding
  final prefs = await SharedPreferences.getInstance();
  final hasCompleted = prefs.getBool('has_completed_onboarding') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationManager()),
      ],
      child: MyApp(hasCompletedOnboarding: hasCompleted),
    ),
  );
}

// ======================================================
// Firebase Initialization Helper
// ======================================================
class FirebaseInitializer {
  static Future<void> initialize() async {
    if (!kIsWeb && Platform.isWindows) {
      // Windows-specific Firebase initialization if needed
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      // Normal Firebase initialization for web/mobile
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }
}

// ======================================================
// ROUTES CONFIGURATION
// ======================================================
class AppRoutes {
  static const String initial = "/";
  static const String home = "/home";
  static const String groups = '/groups';
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
  final bool hasCompletedOnboarding;

  const MyApp({super.key, required this.hasCompletedOnboarding});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Campus Hub',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      initialRoute: AppRoutes.initial,
      routes: {
        AppRoutes.initial: (context) =>
            SplashScreen(hasCompletedOnboarding: hasCompletedOnboarding),
        ...AppRoutes.routes,
      },
    );
  }
}

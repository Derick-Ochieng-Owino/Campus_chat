import 'package:campus_app/providers/notification_provider.dart';
import 'package:campus_app/providers/theme_provider.dart';
import 'package:campus_app/screens/groups/groups_screen.dart';
import 'package:campus_app/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'providers/chat_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (Necessary for FCM and Firestore)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();

  final hasCompleted = prefs.getBool('has_completed_onboarding') ?? false;

  runApp(
    MultiProvider(
      providers: [
        // Core Providers: All top-level services accessible throughout the app
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationManager()) // Correct instantiation
      ],
      child: MyApp(hasCompletedOnboarding: hasCompleted),
    ),
  );
}

// ======================================================
// ROUTES CONFIGURATION (Centralizing navigation paths)
// ======================================================
class AppRoutes {
  static const String initial = "/";
  static const String home = "/home";
  static const String groups = '/groups';
  static const String login = '/login';
  static const String signup = '/signup';

  static Map<String, WidgetBuilder> get routes => {
    // The main entry point after authentication/splash checks
    home: (context) => const HomePage(),
    groups: (context) => const GroupsTab(),
    login: (context) => const LoginPage(),
    signup: (context) => const SignUpPage(),
    // Note: SplashScreen handles the very first routing decision,
    // so it uses Navigator.pushReplacementNamed inside its logic.
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
    // Read the ThemeProvider for dynamic theming
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Campus Hub',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,

      // Set the SplashScreen as the initial screen
      // It will then redirect using the named routes defined above.
      initialRoute: AppRoutes.initial,

      // Merge routes with the initial route redirecting to SplashScreen
      routes: {
        AppRoutes.initial: (context) =>
            SplashScreen(hasCompletedOnboarding: hasCompletedOnboarding),
        ...AppRoutes.routes,
      },
    );
  }
}
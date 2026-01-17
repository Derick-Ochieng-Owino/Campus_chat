import 'package:alma_mata/screens/announcement/fcm_initializer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

// -------------------- BACKGROUND HANDLER --------------------
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('BG message received: ${message.messageId}');
}

// -------------------- MAIN --------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Check onboarding status
  final prefs = await SharedPreferences.getInstance();
  final hasCompleted = prefs.getBool('has_completed_onboarding') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationManager()),
      ],
      child: FCMInitializer(
        child: MyApp(hasCompletedOnboarding: hasCompleted),
      ),
    ),
  );
}

// -------------------- APP ROUTES --------------------
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

// -------------------- MAIN APP WIDGET --------------------
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

import 'package:alma_mata/screens/announcement/fcm_initializer.dart';
import 'package:alma_mata/screens/announcement/fcm_background.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';

import 'screens/auth/splash_screen.dart';
import 'screens/auth/signin_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/groups/groups_screen.dart';

import 'firebase_options.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  try {
    final dynamic nativeZoneValue = await FlutterTimezone.getLocalTimezone();
    String timeZoneName;
    if (nativeZoneValue is Map) {
      timeZoneName = nativeZoneValue['name'] ?? 'Africa/Nairobi';
    } else if (nativeZoneValue != null && nativeZoneValue.toString().contains('TimezoneInfo')) {
      timeZoneName = 'Africa/Nairobi';
    } else {
      timeZoneName = nativeZoneValue?.toString() ?? 'Africa/Nairobi';
    }
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    debugPrint('[Timezone Setup] Bound native zone location: $timeZoneName');
  } catch (e) {
    debugPrint('[Timezone Setup] Fallback triggered: $e');
    tz.setLocalLocation(tz.getLocation('Africa/Nairobi'));
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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

class MyApp extends StatelessWidget {
  final bool hasCompletedOnboarding;
  const MyApp({super.key, required this.hasCompletedOnboarding});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'NetWorth',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      initialRoute: AppRoutes.initial,
      routes: {
        AppRoutes.initial: (context) => SplashScreen(hasCompletedOnboarding: hasCompletedOnboarding),
        ...AppRoutes.routes,
      },
    );
  }
}
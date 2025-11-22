import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Import your screens
import 'screens/splash/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/uploads/upload_file_screen.dart';
import 'screens/home/groups_tab.dart';
import 'screens/home/units_tab.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';

// Import your providers
import 'providers/user_provider.dart';
import 'providers/group_provider.dart';
import 'providers/chat_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => GroupsProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// ======================================================
// ROUTES
// ======================================================
class AppRoutes {
  static const home = "/home";
  static const fileUpload = "/file-upload";
  static const courseUnits = "/course-units";
  static const groups = "/groups";
  static const profile = "/profile";
  static const login = "/login";
  static const signup = "/signup";

  static Map<String, WidgetBuilder> routes = {
    home: (context) => const HomePage(),
    fileUpload: (context) => const FileUploadScreen(),
    groups: (context) => const GroupsScreen(),
    courseUnits: (context) => CourseUnitsScreen(),
    login: (context) => const LoginPage(),
    signup: (context) => const SignUpPage(),
  };
}

// ======================================================
// MAIN APP
// ======================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.home,
      routes: AppRoutes.routes,
      home: const SplashScreen(),
    );
  }
}

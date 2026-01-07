import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';

// Initialize local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Define the custom notification sound channel (MUST match Android/iOS setup)
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // title
  description: 'This channel is used for important notifications.', // description
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('notification_sound'), // 'notification_sound' is the file name in res/raw (without extension)
);

// Top-level function to handle background messages
// (Must be defined outside any class)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you perform heavy operations here, ensure Firebase is initialized first
  debugPrint('Handling a background message: ${message.messageId}');
  // Background messages typically handle navigation or data persistence,
  // and the OS handles the display/sound based on the payload.
}

class FCMInitializer extends StatefulWidget {
  final Widget child;
  const FCMInitializer({super.key, required this.child});

  @override
  State<FCMInitializer> createState() => _FCMInitializerState();
}

class _FCMInitializerState extends State<FCMInitializer> {
  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  // --- 1. Setup and Token Storage ---
  Future<void> _initializeFCM() async {
    // 1. Setup Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Local Notifications Setup
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // 3. Request Permissions
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
    );

    // 4. Handle Token and Store in Firestore
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && FirebaseAuth.instance.currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
      debugPrint("FCM Token stored: $token");
    }

    // 5. Setup Foreground Listener
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  // --- 2. Foreground Message Handler (CRITICAL for Modal) ---
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground Message received: ${message.data}');

    final manager = Provider.of<NotificationManager>(context, listen: false);

    // Convert FCM data to our model
    final notification = NotificationData.fromFCM(message.data);

    if (notification.type == NotificationType.classConfirmation ||
        notification.type == NotificationType.cat) {

      // A. Show Custom Modal
      manager.showNotification(notification);

      // B. Manually Play Sound (Since the system won't play it in the foreground)
      flutterLocalNotificationsPlugin.show(
        0,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id, channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
            playSound: true,
            // Use the same sound name defined in the channel
            sound: const RawResourceAndroidNotificationSound('notification_sound'),
          ),
          iOS: const DarwinNotificationDetails(
            sound: 'notification_sound.wav', // Match iOS bundled sound file name
          ),
        ),
      );

    } else {
      // C. Standard Banner Notification (DMs, Notes Update)
      flutterLocalNotificationsPlugin.show(
        notification.id.hashCode, // Use hash code for unique ID
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel',
            'Default Notifications',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // This widget sits above the app and handles the FCM setup
    return widget.child;
  }
}
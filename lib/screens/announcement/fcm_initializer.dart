import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel highChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Used for important alerts',
  importance: Importance.max,
  playSound: true,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('BG message: ${message.messageId}');
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
    _initialize();
  }

  Future<void> _initialize() async {
    // ❌ Firebase Messaging NOT supported on Windows
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('FCM skipped: unsupported platform');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );

    await _setupLocalNotifications();
    await _requestPermission();
    await _handleToken();
    _setupForegroundListeners();
  }

  Future<void> _setupLocalNotifications() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(highChannel);

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  Future<void> _requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _handleToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  void _setupForegroundListeners() {
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);
  }

  // ---------------- FOREGROUND ----------------

  void _onForegroundMessage(RemoteMessage message) {
    final manager = context.read<NotificationManager>();

    // Extract title & body correctly
    String title = message.notification?.title ?? '📢 Announcement';
    String body = message.notification?.body ?? '';

    final notification = NotificationData.fromFCM(message.data);

    // Pass extracted title/body to local notification
    // notification.title = title;
    // notification.body = body;

    // Handle in app (custom logic)
    manager.handle(notification);

    // Show system notification
    _showSystemNotification(notification);
  }


  void _showSystemNotification(NotificationData n) {
    flutterLocalNotificationsPlugin.show(
      n.id.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          highChannel.id,
          highChannel.name,
          channelDescription: highChannel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ---------------- TAP ----------------

  void _onNotificationTap(RemoteMessage message) {
    final notification = NotificationData.fromFCM(message.data);
    context.read<NotificationManager>().handle(notification);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

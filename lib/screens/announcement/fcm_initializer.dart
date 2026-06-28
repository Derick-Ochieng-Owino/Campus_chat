import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import 'fcm_background.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel highChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Used for important academic notifications.',
  importance: Importance.max,
  playSound: true,
);

class FCMInitializer extends StatefulWidget {
  final Widget child;
  const FCMInitializer({super.key, required this.child});

  static Future<void> scheduleAcademicReminders(List<QueryDocumentSnapshot> notices) async {
    await flutterLocalNotificationsPlugin.cancelAll();
    final now = DateTime.now();
    int notificationId = 1000;

    for (var doc in notices) {
      final data = doc.data() as Map<String, dynamic>;
      final String type = data['type'] ?? 'General';

      if (type != 'Assignment' && type != 'CAT') continue;

      final Timestamp? targetTimestamp = data['target_date'] as Timestamp?;
      if (targetTimestamp == null) continue;
      final DateTime targetDate = targetTimestamp.toDate();

      if (now.isAfter(targetDate)) continue;

      final String title = "$type Reminder: ${data['title'] ?? 'Academic Task'}";
      final String body = "Due on ${DateFormat('EEE, MMM d @ h:mm a').format(targetDate)}.";

      DateTime currentDayCheck = DateTime(now.year, now.month, now.day);
      while (currentDayCheck.isBefore(targetDate)) {
        final targetHours = [6, 18, 23];

        for (int hour in targetHours) {
          final DateTime scheduledAlarmTime = DateTime(
            currentDayCheck.year,
            currentDayCheck.month,
            currentDayCheck.day,
            hour,
            0,
          );

          if (scheduledAlarmTime.isAfter(now) && scheduledAlarmTime.isBefore(targetDate)) {
            notificationId++;
            await flutterLocalNotificationsPlugin.zonedSchedule(
              notificationId,
              title,
              body,
              tz.TZDateTime.from(scheduledAlarmTime, tz.local),
              NotificationDetails(
                android: AndroidNotificationDetails(
                  highChannel.id,
                  highChannel.name,
                  channelDescription: highChannel.description,
                  importance: Importance.max,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
                  playSound: true,
                ),
                iOS: const DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            );
          }
        }
        currentDayCheck = currentDayCheck.add(const Duration(days: 1));
      }
    }
    debugPrint("Academic local reminders refreshed successfully.");
  }

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
    if (!Platform.isAndroid && !Platform.isIOS) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _setupLocalNotifications();
    await _requestPermission();
    await _handleToken();
    _setupForegroundListeners();
  }

  Future<void> _setupLocalNotifications() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(highChannel);

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  Future<void> _requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
  }

  Future<void> _handleToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'fcmToken': token}, SetOptions(merge: true));
  }

  void _setupForegroundListeners() {
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);
  }

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('📢 Foreground Push Received: ${message.notification?.title}');
    final manager = context.read<NotificationManager>();
    final notification = NotificationData.fromFCM(message);
    manager.handle(notification);
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
          icon: '@mipmap/ic_launcher',
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  void _onNotificationTap(RemoteMessage message) {
    final notification = NotificationData.fromFCM(message);
    context.read<NotificationManager>().handle(notification);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
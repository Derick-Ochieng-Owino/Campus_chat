// import 'dart:io';
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter_timezone/flutter_timezone.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:timezone/data/latest.dart' as tz;
// import 'package:intl/intl.dart';
//
// // ==========================================
// // 1. DATA MODEL & ENUMS
// // ==========================================
// enum NotificationType { assignment, cat, classConfirmation, notes, pastPaper, general }
//
// class NotificationData {
//   final String id, title, body, unitCode;
//   final NotificationType type;
//
//   NotificationData({required this.id, required this.title, required this.body, required this.type, this.unitCode = ''});
//
//   factory NotificationData.fromFCM(RemoteMessage message) {
//     final data = message.data;
//     final fallback = message.notification;
//
//     final rawType = (data['type'] ?? 'general').toString().toLowerCase();
//     NotificationType mappedType = NotificationType.general;
//     if (rawType == 'assignment') mappedType = NotificationType.assignment;
//     if (rawType == 'cat') mappedType = NotificationType.cat;
//     if (rawType.contains('confirmation')) mappedType = NotificationType.classConfirmation;
//     if (rawType == 'notes') mappedType = NotificationType.notes;
//     if (rawType.contains('paper')) mappedType = NotificationType.pastPaper;
//
//     return NotificationData(
//       id: data['id'] ?? message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
//       title: fallback?.title ?? data['title'] ?? 'Academic Alert',
//       body: fallback?.body ?? data['body'] ?? '',
//       type: mappedType,
//       unitCode: data['unitCode'] ?? '',
//     );
//   }
//
//   Color get color {
//     if (type == NotificationType.cat) return Colors.red;
//     if (type == NotificationType.assignment) return Colors.orange;
//     if (type == NotificationType.classConfirmation) return Colors.indigo;
//     return Colors.blue;
//   }
// }
//
// // ==========================================
// // 2. GLOBAL BACKGROUND HANDLING ISOLATE
// // ==========================================
// final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
//
// const AndroidNotificationChannel highChannel = AndroidNotificationChannel(
//   'high_importance_channel', 'High Importance Alerts',
//   importance: Importance.max, playSound: true,
// );
//
// @pragma('vm:entry-point')
// Future<void> fcmBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   tz.initializeTimeZones();
//   try {
//     final String location = await FlutterTimezone.getLocalTimezone();
//     tz.setLocalLocation(tz.getLocation(location));
//   } catch (_) {
//     tz.setLocalLocation(tz.getLocation('Africa/Nairobi'));
//   }
//
//   final notification = NotificationData.fromFCM(message);
//   if (notification.type == NotificationType.assignment || notification.type == NotificationType.cat) {
//     final snap = await FirebaseFirestore.instance.collection('announcements').get();
//     await NotificationManager.refreshLocalAlarms(snap.docs);
//   }
// }
//
// // ==========================================
// // 3. CENTRAL MANAGEMENT PROVIDER
// // ==========================================
// class NotificationManager extends ChangeNotifier {
//   NotificationData? _activeModal;
//   Timer? _dismissTimer;
//
//   NotificationData? get activeModal => _activeModal;
//
//   Future<void> initializeSystem() async {
//     if (Platform.isWindows || Platform.isMacOS) return;
//
//     FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
//
//     // Bind local channel pipes
//     await localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(highChannel);
//
//     await localNotifications.initialize(
//       const InitializationSettings(
//         android: AndroidNotificationSettings('@mipmap/ic_launcher'),
//         iOS: DarwinInitializationSettings(),
//       ),
//     );
//
//     // Request permissions and register token signatures
//     await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
//
//     final user = FirebaseAuth.instance.currentUser;
//     final token = await FirebaseMessaging.instance.getToken();
//     if (user != null && token != null) {
//       await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'fcmToken': token}, SetOptions(merge: true));
//     }
//
//     // Connect real-time foreground stream ports
//     FirebaseMessaging.onMessage.listen((msg) {
//       final notification = NotificationData.fromFCM(msg);
//
//       // In-App Overlay Trigger Mapping Block
//       if (notification.type != NotificationType.general) {
//         _dismissTimer?.cancel();
//         _activeModal = notification;
//         notifyListeners();
//         _dismissTimer = Timer(const Duration(seconds: 15), () => dismissModal());
//       }
//
//       // Draw System Tray Banner
//       localNotifications.show(
//         notification.id.hashCode, notification.title, notification.body,
//         NotificationDetails(
//           android: AndroidNotificationDetails(
//               highChannel.id, highChannel.name, importance: Importance.max, priority: Priority.high, icon: '@mipmap/ic_launcher'
//           ),
//           iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
//         ),
//       );
//     });
//   }
//
//   void dismissModal() {
//     if (_activeModal != null) {
//       _dismissTimer?.cancel();
//       _activeModal = null;
//       notifyListeners();
//     }
//   }
//
//   static Future<void> refreshLocalAlarms(List<QueryDocumentSnapshot> docs) async {
//     await localNotifications.cancelAll();
//     final now = DateTime.now();
//     int idCount = 2000;
//
//     for (var doc in docs) {
//       final data = doc.data() as Map<String, dynamic>;
//       final String type = data['type'] ?? 'General';
//       if (type != 'Assignment' && type != 'CAT') continue;
//
//       final Timestamp? ts = data['target_date'] as Timestamp?;
//       if (ts == null) continue;
//       final DateTime deadline = ts.toDate();
//       if (now.isAfter(deadline)) continue;
//
//       DateTime currentDay = DateTime(now.year, now.month, now.day);
//       while (currentDay.isBefore(deadline)) {
//         for (int hour in [6, 18, 23]) { // Morning (6 AM), Evening (6 PM), Night Review (11 PM)
//           final scheduled = DateTime(currentDay.year, currentDay.month, currentDay.day, hour, 0);
//
//           if (scheduled.isAfter(now) && scheduled.isBefore(deadline)) {
//             idCount++;
//             await localNotifications.zonedSchedule(
//               idCount,
//               "$type Reminder: ${data['title'] ?? 'Task'}",
//               "Due on ${DateFormat('EEE, MMM d @ h:mm a').format(deadline)}.",
//               tz.TZDateTime.from(scheduled, tz.local),
//               NotificationDetails(
//                 android: AndroidNotificationDetails(highChannel.id, highChannel.name, importance: Importance.max, priority: Priority.high, icon: '@mipmap/ic_launcher'),
//                 iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
//               ),
//               androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
//             );
//           }
//         }
//         currentDay = currentDay.add(const Duration(days: 1));
//       }
//     }
//   }
// }
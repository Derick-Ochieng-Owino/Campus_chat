// lib/models/notification_data.dart
import 'package:flutter/material.dart';

enum NotificationType {
  assignment,
  cat,
  classConfirmation,
  notesUpdate,
  dm,
  groupChat,
  general
}

class NotificationData {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String targetId; // e.g., chatId, unitId, announcementId
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  NotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.targetId,
    required this.timestamp,
    required this.icon,
    required this.color,
  });

  // Factory to parse data from a standard FCM map
  factory NotificationData.fromFCM(Map<String, dynamic> data) {
    // Determine the type safely
    final typeString = data['type'] ?? 'general';
    final type = NotificationType.values.firstWhere(
          (e) => e.toString().split('.').last == typeString.toLowerCase(),
      orElse: () => NotificationType.general,
    );

    // Get theme-independent colors/icons for foreground notifications
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.classConfirmation:
        icon = Icons.class_rounded;
        color = Colors.indigo;
        break;
      case NotificationType.cat:
        icon = Icons.warning_rounded;
        color = Colors.red;
        break;
      case NotificationType.assignment:
        icon = Icons.assignment_rounded;
        color = Colors.orange;
        break;
      default:
        icon = Icons.message_rounded;
        color = Colors.green;
    }

    return NotificationData(
      id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: data['title'] ?? 'New Notification',
      body: data['body'] ?? '',
      type: type,
      targetId: data['targetId'] ?? '',
      timestamp: DateTime.now(),
      icon: icon,
      color: color,
    );
  }
}
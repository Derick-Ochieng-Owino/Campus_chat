import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

enum NotificationType {
  assignment,
  cat,
  classConfirmation,
  notes,
  pastPaper,
  ads,
  dm,
  groupChat,
  general,
}

class NotificationData {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String targetId;
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

  factory NotificationData.fromFCM(RemoteMessage message) {
    final Map<String, dynamic> data = message.data;
    final RemoteNotification? notification = message.notification;

    final rawType = (data['type'] ?? 'general').toString().toLowerCase();
    final NotificationType type = _mapType(rawType);
    final visual = _visualForType(type);

    return NotificationData(
      id: data['id'] ?? message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: notification?.title ?? data['title'] ?? 'New Notification',
      body: notification?.body ?? data['body'] ?? '',
      type: type,
      targetId: data['targetId'] ?? data['id'] ?? '',
      timestamp: DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
      icon: visual.icon,
      color: visual.color,
    );
  }

  static NotificationType _mapType(String type) {
    switch (type) {
      case 'assignment':
        return NotificationType.assignment;
      case 'cat':
        return NotificationType.cat;
      case 'classconfirmation':
      case 'class_confirmation':
        return NotificationType.classConfirmation;
      case 'notes':
      case 'notesupdate':
        return NotificationType.notes;
      case 'pastpaper':
      case 'past_paper':
        return NotificationType.pastPaper;
      case 'ads':
        return NotificationType.ads;
      case 'dm':
        return NotificationType.dm;
      case 'groupchat':
      case 'group_chat':
        return NotificationType.groupChat;
      default:
        return NotificationType.general;
    }
  }

  static _NotificationVisual _visualForType(NotificationType type) {
    switch (type) {
      case NotificationType.classConfirmation:
        return const _NotificationVisual(icon: Icons.class_rounded, color: Colors.indigo);
      case NotificationType.cat:
        return const _NotificationVisual(icon: Icons.warning_amber_rounded, color: Colors.red);
      case NotificationType.assignment:
        return const _NotificationVisual(icon: Icons.assignment_rounded, color: Colors.orange);
      case NotificationType.notes:
        return const _NotificationVisual(icon: Icons.book_rounded, color: Colors.blue);
      case NotificationType.pastPaper:
        return const _NotificationVisual(icon: Icons.history_edu_rounded, color: Colors.teal);
      case NotificationType.ads:
        return const _NotificationVisual(icon: Icons.campaign_rounded, color: Colors.purple);
      case NotificationType.dm:
        return const _NotificationVisual(icon: Icons.chat_bubble_rounded, color: Colors.green);
      case NotificationType.groupChat:
        return _NotificationVisual(icon: Icons.groups_rounded, color: Colors.green);
      default:
        return const _NotificationVisual(icon: Icons.notifications_rounded, color: Colors.grey);
    }
  }
}

class _NotificationVisual {
  final IconData icon;
  final Color color;
  const _NotificationVisual({required this.icon, required this.color});
}
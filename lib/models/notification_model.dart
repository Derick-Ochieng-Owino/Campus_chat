import 'package:flutter/material.dart';

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
  final String targetId; // chatId, announcementId, fileId, etc
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

  /// 🔥 Robust FCM → App mapping
  factory NotificationData.fromFCM(Map<String, dynamic> data) {
    final rawType = (data['type'] ?? 'general').toString().toLowerCase();

    final NotificationType type = _mapType(rawType);

    final visual = _visualForType(type);

    return NotificationData(
      id: data['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: data['title'] ?? 'New Notification',
      body: data['body'] ?? '',
      type: type,
      targetId: data['targetId'] ?? '',
      timestamp: DateTime.tryParse(data['timestamp'] ?? '') ??
          DateTime.now(),
      icon: visual.icon,
      color: visual.color,
    );
  }

  // -------------------- TYPE MAPPING --------------------
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

  // -------------------- UI VISUALS --------------------
  static _NotificationVisual _visualForType(NotificationType type) {
    switch (type) {
      case NotificationType.classConfirmation:
        return _NotificationVisual(
          icon: Icons.class_rounded,
          color: Colors.indigo,
        );
      case NotificationType.cat:
        return _NotificationVisual(
          icon: Icons.warning_amber_rounded,
          color: Colors.red,
        );
      case NotificationType.assignment:
        return _NotificationVisual(
          icon: Icons.assignment_rounded,
          color: Colors.orange,
        );
      case NotificationType.notes:
        return _NotificationVisual(
          icon: Icons.book_rounded,
          color: Colors.blue,
        );
      case NotificationType.pastPaper:
        return _NotificationVisual(
          icon: Icons.history_edu_rounded,
          color: Colors.teal,
        );
      case NotificationType.ads:
        return _NotificationVisual(
          icon: Icons.campaign_rounded,
          color: Colors.purple,
        );
      case NotificationType.dm:
        return _NotificationVisual(
          icon: Icons.chat_bubble_rounded,
          color: Colors.green,
        );
      case NotificationType.groupChat:
        return _NotificationVisual(
          icon: Icons.groups_rounded,
          color: Colors.green.shade700,
        );
      default:
        return _NotificationVisual(
          icon: Icons.notifications_rounded,
          color: Colors.grey,
        );
    }
  }
}

// -------------------- Helper --------------------
class _NotificationVisual {
  final IconData icon;
  final Color color;

  const _NotificationVisual({
    required this.icon,
    required this.color,
  });
}

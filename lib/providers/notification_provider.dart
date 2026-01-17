import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/notification_model.dart';

class NotificationManager extends ChangeNotifier {
  NotificationData? _activeModal;

  NotificationData? get activeModal => _activeModal;

  /// Entry point for ALL notifications (FCM, Firestore, local)
  void handle(NotificationData notification) {
    if (_isHighPriority(notification)) {
      _showModal(notification);
    } else {
      debugPrint("Standard notification received: ${notification.title}");
      // handled by system notification tray (FCM)
    }
  }

  // ---------- MODAL CONTROL ----------

  void _showModal(NotificationData notification) {
    _activeModal = notification;
    notifyListeners();

    // Auto-dismiss after 15 seconds
    Future.delayed(const Duration(seconds: 15), () {
      if (_activeModal?.id == notification.id) {
        dismissModal();
      }
    });
  }

  void dismissModal() {
    if (_activeModal != null) {
      _activeModal = null;
      notifyListeners();
    }
  }

  // ---------- PRIORITY LOGIC ----------

  bool _isHighPriority(NotificationData n) {
    return n.type == NotificationType.classConfirmation ||
        n.type == NotificationType.cat;
  }

  // ---------- PERMISSIONS ----------

  Future<void> requestNotificationPermission() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');
  }
}

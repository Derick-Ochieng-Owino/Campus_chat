import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/notification_model.dart';

class NotificationManager extends ChangeNotifier {
  NotificationData? _activeModal;
  Timer? _dismissTimer;

  NotificationData? get activeModal => _activeModal;

  void handle(NotificationData notification) {
    if (_isHighPriority(notification)) {
      _showModal(notification);
    } else {
      debugPrint("Standard background notification logged: ${notification.title}");
    }
  }

  void _showModal(NotificationData notification) {
    _dismissTimer?.cancel();
    _activeModal = notification;
    notifyListeners();

    _dismissTimer = Timer(const Duration(seconds: 15), () {
      if (_activeModal?.id == notification.id) {
        dismissModal();
      }
    });
  }

  void dismissModal() {
    if (_activeModal != null) {
      _dismissTimer?.cancel();
      _activeModal = null;
      notifyListeners();
    }
  }

  bool _isHighPriority(NotificationData n) {
    return n.type == NotificationType.classConfirmation ||
        n.type == NotificationType.cat ||
        n.type == NotificationType.assignment ||
        n.type == NotificationType.notes ||
        n.type == NotificationType.pastPaper;
  }

  Future<void> requestNotificationPermission() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('Notification permission status: ${settings.authorizationStatus}');
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}
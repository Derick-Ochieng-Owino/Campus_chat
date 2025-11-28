import 'dart:async';
import 'package:flutter/material.dart';

import '../models/notification_model.dart';

class NotificationManager with ChangeNotifier {
  // Stream to push high-priority modal data (Class Confirmation, CAT Reminder)
  final _modalNotificationStream = StreamController<NotificationData?>.broadcast();
  Stream<NotificationData?> get modalNotificationStream => _modalNotificationStream.stream;

  // The currently displayed high-priority notification data
  NotificationData? _currentModalNotification;
  NotificationData? get currentModalNotification => _currentModalNotification;

  // --- 1. Push a new notification into the manager ---
  void showNotification(NotificationData notification) {
    // Only high-priority types get the custom modal overlay
    if (notification.type == NotificationType.classConfirmation ||
        notification.type == NotificationType.cat) {

      // Set the internal state and push to the stream
      _currentModalNotification = notification;
      _modalNotificationStream.add(notification);
      notifyListeners();

      // Optional: Auto-dismiss modal after 15 seconds
      Future.delayed(const Duration(seconds: 15), () {
        if (_currentModalNotification?.id == notification.id) {
          dismissModal();
        }
      });

    } else {
      // For standard notifications (DMs, Notes Update), the local notification service
      // handled by FCMInitializer will show the banner/banner notification.
      debugPrint("Standard notification received: ${notification.title}");
    }
  }

  // --- 2. Dismiss the modal ---
  void dismissModal() {
    if (_currentModalNotification != null) {
      _currentModalNotification = null;
      _modalNotificationStream.add(null);
      notifyListeners();
      debugPrint("Modal dismissed.");
    }
  }

  @override
  void dispose() {
    _modalNotificationStream.close();
    super.dispose();
  }
}
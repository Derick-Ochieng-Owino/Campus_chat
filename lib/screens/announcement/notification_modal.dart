// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';

class ConfirmationModal extends StatelessWidget {
  final NotificationData notification;

  const ConfirmationModal({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = notification.color;
    final typeName = notification.type.toString().split('.').last.toUpperCase();

    // The modal is built using a custom layout that sits in the Stack of the main app wrapper.
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      right: 10,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        elevation: 8,
        color: theme.cardColor,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            color: theme.cardColor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Type, Title, and Close Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(notification.icon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeName,
                          style: theme.textTheme.bodySmall!.copyWith(color: color, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          notification.title,
                          style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Close Button
                  InkWell(
                    onTap: () {
                      Provider.of<NotificationManager>(context, listen: false).dismissModal();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Icon(Icons.close_rounded, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, thickness: 1),

              TextButton(
                onPressed: () {
                  Provider.of<NotificationManager>(context, listen: false).dismissModal();

                  // Navigate based on the notification's targetId / type
                  if (notification.type == NotificationType.classConfirmation) {
                    Navigator.pushNamed(context, '/classConfirmation', arguments: notification.targetId);
                  } else if (notification.type == NotificationType.cat) {
                    Navigator.pushNamed(context, '/examSchedule', arguments: notification.targetId);
                  } else {
                    Navigator.pushNamed(context, '/inbox', arguments: notification.targetId);
                  }
                },
                child: Text('VIEW DETAILS', style: TextStyle(color: notification.color)),
              ),

              // Body
              Text(
                notification.body,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Action Button (Example)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // Implement deep link navigation here based on notification.targetId
                    Provider.of<NotificationManager>(context, listen: false).dismissModal();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Navigating to relevant page for ${notification.targetId}')),
                    );
                  },
                  child: Text('VIEW DETAILS', style: TextStyle(color: color)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
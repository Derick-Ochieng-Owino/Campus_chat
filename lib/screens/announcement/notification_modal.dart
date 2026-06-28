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
    final colorScheme = theme.colorScheme;
    final color = notification.color;
    final typeName = notification.type.toString().split('.').last.toUpperCase();

    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double computedTopPadding = statusBarHeight > 0 ? statusBarHeight + 12 : 24.0;

    return Positioned(
      top: computedTopPadding,
      left: 12,
      right: 12,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          borderRadius: BorderRadius.circular(16),
          elevation: 10,
          shadowColor: Colors.black.withOpacity(0.25),
          // ✅ THEME AUTOMATION: Automatically swaps based on user's active theme colors
          color: colorScheme.surface,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              // ✅ THEME AUTOMATION: Uses the theme's default border outline rules
              border: Border.all(color: color.withOpacity(0.35), width: 1.5),
              color: colorScheme.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notification.title,
                            style: theme.textTheme.titleMedium!.copyWith(
                              fontWeight: FontWeight.bold,
                              // ✅ THEME AUTOMATION: Changes text ink cleanly from light to dark modes
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Provider.of<NotificationManager>(context, listen: false).dismissModal(),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          // ✅ THEME AUTOMATION: Matches the dynamic close icon contrast matrix
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, thickness: 0.5),
                Text(
                  notification.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    // ✅ THEME AUTOMATION: Gives description text clean, automated readability parameters
                    color: colorScheme.onSurface.withOpacity(0.85),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Provider.of<NotificationManager>(context, listen: false).dismissModal();
                      if (notification.type == NotificationType.groupChat || notification.type == NotificationType.dm) {
                        Navigator.pushNamed(context, '/groups', arguments: notification.targetId);
                      } else {
                        Navigator.pushNamed(context, '/home', arguments: notification.targetId);
                      }
                    },
                    child: Text(
                      'VIEW DETAILED INFO',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
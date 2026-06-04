import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../notifications/notification_badge_service.dart';
import '../theme/app_colors.dart';

/// Reusable notification bell icon with a red dot badge when there are unread notifications.
class NotificationBellIcon extends StatelessWidget {
  const NotificationBellIcon({
    super.key,
    this.onPressed,
    this.size = 24,
  });

  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconWithBadge = ValueListenableBuilder<int>(
      valueListenable: NotificationBadgeService.unreadCount,
      builder: (context, count, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ?child,
            if (count > 0)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: size * 0.45,
                  height: size * 0.45,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.surface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: PhosphorIcon(
        PhosphorIconsRegular.bell,
        size: size,
        color: AppColors.textPrimary,
      ),
    );

    if (onPressed == null) {
      return iconWithBadge;
    }

    return IconButton(
      icon: iconWithBadge,
      onPressed: onPressed,
      tooltip: 'Notifications',
    );
  }
}


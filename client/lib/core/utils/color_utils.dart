import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

final List<Color> _avatarColors = [
  AppColors.primary,
  AppColors.primaryAccent,
  AppColors.success,
  AppColors.warning,
  AppColors.cookingChipText,
  AppColors.outForDeliveryChipText,
  AppColors.primaryAccent,
  AppColors.pendingChipText,
];

Color colorFromName(String name) {
  if (name.isEmpty) return _avatarColors[0];
  int hash = 0;
  for (int i = 0; i < name.length; i++) {
    hash = name.codeUnitAt(i) + ((hash << 5) - hash);
  }
  return _avatarColors[hash.abs() % _avatarColors.length];
}

Color statusBorderColor(String status) {
  final s = status.toLowerCase();
  if (s == 'active' || s == 'delivered' || s == 'completed') return AppColors.success;
  if (s == 'processing' || s == 'cooking' || s == 'in_transit' || s == 'to_process') return AppColors.cookingChipText;
  if (s == 'out_for_delivery') return AppColors.outForDeliveryChipText;
  if (s == 'expired' || s == 'cancelled' || s == 'overdue' || s == 'failed') return AppColors.error;
  if (s == 'pending' || s == 'assigned') return AppColors.textHint;
  return AppColors.textHint;
}

/// Background and text color for status chip
(Color, Color) statusChipColors(String status) {
  final s = status.toLowerCase();
  if (s == 'active' || s == 'delivered' || s == 'completed') return (AppColors.successChipBg, AppColors.successChipText);
  if (s == 'processing' || s == 'cooking' || s == 'to_process') return (AppColors.cookingChipBg, AppColors.cookingChipText);
  if (s == 'out_for_delivery' || s == 'in_transit') return (AppColors.outForDeliveryChipBg, AppColors.outForDeliveryChipText);
  if (s == 'expired' || s == 'cancelled' || s == 'overdue' || s == 'failed') return (AppColors.errorContainer, AppColors.error);
  if (s == 'pending' || s == 'assigned') return (AppColors.pendingChipBg, AppColors.pendingChipText);
  return (AppColors.surfaceContainerHighest, AppColors.textSecondary);
}

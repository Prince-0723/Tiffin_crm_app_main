// import '../../../core/network/api_endpoints.dart';
// import '../../../core/network/dio_client.dart';
// import '../../../models/notification_model.dart';

// /// Notifications API for vendor / delivery_staff / admin (GET /notifications).
// abstract final class NotificationApi {
//   /// Returns { notifications, total, page, totalPages }.
//   static Future<Map<String, dynamic>> getMyNotifications({
//     int page = 1,
//     int limit = 20,
//     bool? isRead,
//   }) async {
//     final query = <String, dynamic>{'page': page, 'limit': limit};
//     if (isRead != null) query['isRead'] = isRead;
//     final response = await DioClient.instance.get(
//       ApiEndpoints.notifications,
//       queryParameters: query,
//     );
//     final payload = parseData(response);
//     if (payload is! Map<String, dynamic>) {
//       return {
//         'notifications': <NotificationModel>[],
//         'total': 0,
//         'page': page,
//         'totalPages': 0,
//       };
//     }
//     final list = payload['data'] is List ? payload['data'] as List : [];
//     final notifications = list
//         .whereType<Map<String, dynamic>>()
//         .map((e) => NotificationModel.fromJson(e))
//         .toList();
//     final total = (payload['total'] is num) ? (payload['total'] as num).toInt() : 0;
//     final currentPage = (payload['page'] is num) ? (payload['page'] as num).toInt() : page;
//     final totalPages = (payload['totalPages'] is num) ? (payload['totalPages'] as num).toInt() : 1;
//     return {
//       'notifications': notifications,
//       'total': total,
//       'page': currentPage,
//       'totalPages': totalPages,
//     };
//   }

//   static Future<void> markNotificationRead(String notificationId) async {
//     await DioClient.instance.patch(
//       ApiEndpoints.notificationMarkRead(notificationId),
//     );
//   }

//   /// Delete a single notification.
//   static Future<void> deleteNotification(String notificationId) async {
//     await DioClient.instance.delete(
//       ApiEndpoints.notificationById(notificationId),
//     );
//   }

//   /// Delete all read notifications for the current user.
//   static Future<void> clearReadNotifications() async {
//     await DioClient.instance.delete(
//       ApiEndpoints.notificationsClearRead,
//     );
//   }

//   /// Mark all notifications as read for the current user.
//   static Future<void> markAllRead() async {
//     await DioClient.instance.patch(
//       '${ApiEndpoints.notifications}/read-all',
//     );
//   }
// }
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/notification_model.dart';

/// Notifications API for vendor / delivery_staff / admin (GET /notifications).
abstract final class NotificationApi {
  /// Returns { notifications, total, page, totalPages }.
  static Future<Map<String, dynamic>> getMyNotifications({
    int page = 1,
    int limit = 20,
    bool? isRead,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (isRead != null) query['isRead'] = isRead;
    final response = await DioClient.instance.get(
      ApiEndpoints.notifications,
      queryParameters: query,
    );
    final payload = parseData(response);
    if (payload is! Map<String, dynamic>) {
      return {
        'notifications': <NotificationModel>[],
        'total': 0,
        'page': page,
        'totalPages': 0,
      };
    }
    final list = payload['data'] is List ? payload['data'] as List : [];
    final notifications = list
        .whereType<Map<String, dynamic>>()
        .map((e) => NotificationModel.fromJson(e))
        .toList();
    final total = (payload['total'] is num)
        ? (payload['total'] as num).toInt()
        : 0;
    final currentPage = (payload['page'] is num)
        ? (payload['page'] as num).toInt()
        : page;
    final totalPages = (payload['totalPages'] is num)
        ? (payload['totalPages'] as num).toInt()
        : 1;
    return {
      'notifications': notifications,
      'total': total,
      'page': currentPage,
      'totalPages': totalPages,
    };
  }

  static Future<void> markNotificationRead(String notificationId) async {
    try {
      await DioClient.instance.patch(
        ApiEndpoints.notificationMarkRead(notificationId),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        if (kDebugMode) {
          debugPrint(
            '[Notification] Already deleted or not found: $notificationId',
          );
        }
        return;
      }
      rethrow;
    }
  }

  /// Delete a single notification.
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await DioClient.instance.delete(
        ApiEndpoints.notificationById(notificationId),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        if (kDebugMode) {
          debugPrint(
            '[Notification] Already deleted or not found: $notificationId',
          );
        }
        return;
      }
      rethrow;
    }
  }

  /// Delete all read notifications for the current user.
  static Future<void> clearReadNotifications() async {
    await DioClient.instance.delete(ApiEndpoints.notificationsClearRead);
  }

  /// Mark all notifications as read for the current user.
  static Future<void> markAllRead() async {
    await DioClient.instance.patch('${ApiEndpoints.notifications}/read-all');
  }
}

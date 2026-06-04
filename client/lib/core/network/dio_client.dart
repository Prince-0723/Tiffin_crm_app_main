import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_session.dart';
import '../config/app_config.dart';
import '../router/app_routes.dart';
import '../socket/delivery_tracking_socket.dart';
import '../storage/secure_storage.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';

final class DioClient {
  DioClient._();

  static Dio? _dio;
  static bool _isRefreshing = false;

  static Dio get instance {
    _dio ??= _createDio();
    return _dio!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: <String, dynamic>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 && !_isRefreshing) {
            _isRefreshing = true;
            try {
              final refreshToken = await SecureStorage.getRefreshToken();
              if (refreshToken == null || refreshToken.isEmpty) {
                throw Exception('No refresh token');
              }
              final refreshed = await _refreshToken(refreshToken);
              if (refreshed) {
                final token = await SecureStorage.getAccessToken();
                if (token != null && token.isNotEmpty) {
                  error.requestOptions.headers['Authorization'] = 'Bearer $token';
                  final response = await dio.fetch(error.requestOptions);
                  return handler.resolve(response);
                }
              }
              throw Exception('Refresh failed');
            } catch (_) {
              await AuthSession.clearLocalSession();
              _goToRoleSelection();
            } finally {
              _isRefreshing = false;
            }
            return handler.next(error);
          }
          return handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
        ),
      );
    }

    return dio;
  }

  static Future<bool> _refreshToken(String refreshToken) async {
    try {
      final refreshDio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
      final response = await refreshDio.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
        options: Options(
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        ),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) return false;
      final success = data['success'] as bool? ?? false;
      final payload = data['data'];
      if (!success || payload is! Map<String, dynamic>) {
        if (data['accessToken'] != null) {
          final access = data['accessToken'] as String?;
          final refresh = data['refreshToken'] as String?;
          if (access != null) await SecureStorage.saveAccessToken(access);
          if (refresh != null) await SecureStorage.saveRefreshToken(refresh);
          unawaited(DeliveryTrackingSocket.instance.reconnectWithFreshToken());
          return true;
        }
        return false;
      }

      final access = payload['accessToken'] as String?;
      final refresh = payload['refreshToken'] as String?;
      if (access != null) await SecureStorage.saveAccessToken(access);
      if (refresh != null) await SecureStorage.saveRefreshToken(refresh);
      unawaited(DeliveryTrackingSocket.instance.reconnectWithFreshToken());
      return true;
    } catch (_) {
      return false;
    }
  }

  static void _goToRoleSelection() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        GoRouter.of(context).go(AppRoutes.roleSelection);
      } catch (_) {}
    }
  }

  static GlobalKey<NavigatorState> get navigatorKey {
    try {
      // Avoid direct dependency on AppRouter from dio_client to prevent
      // pulling in all routes. Caller must set this.
      return _navigatorKey;
    } catch (_) {
      return GlobalKey<NavigatorState>();
    }
  }

  static GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }
}

class LogInterceptor extends Interceptor {
  LogInterceptor({
    this.requestBody = false,
    this.responseBody = false,
    this.error = true,
  });

  final bool requestBody;
  final bool responseBody;
  final bool error;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode && requestBody && options.data != null) {
      try {
        debugPrint('[Dio] ${options.method} ${options.uri}');
        debugPrint('[Dio] body: ${options.data}');
      } catch (_) {}
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode && responseBody) {
      try {
        debugPrint('[Dio] ${response.statusCode} ${response.requestOptions.uri}');
      } catch (_) {}
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode && error) {
      debugPrint('[Dio] error: ${err.message} ${err.response?.statusCode}');
    }
    handler.next(err);
  }
}

/// Throws [ApiException] on non-2xx responses.
void throwIfNotSuccess(Response response) {
  if (response.statusCode != null &&
      response.statusCode! >= 200 &&
      response.statusCode! < 300) {
    return;
  }
  final data = response.data;
  String? message;
  if (data is Map<String, dynamic>) {
    message = data['message'] as String? ?? data['error'] as String?;
  }
  throw ApiException(message ?? 'Request failed', response.statusCode);
}

/// Parses API response: { success: true, data: ... } -> returns data.
dynamic parseData(Response response) {
  final data = response.data;
  if (data is Map<String, dynamic>) {
    final success = data['success'] as bool? ?? false;
    if (!success) {
      final msg = data['message'] as String? ?? data['error'] as String? ?? 'Request failed';
      throw ApiException(msg, response.statusCode);
    }
    return data['data'];
  }
  return data;
}

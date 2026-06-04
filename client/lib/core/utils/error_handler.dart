import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import 'app_snackbar.dart';

abstract final class ErrorHandler {
  static void show(BuildContext context, dynamic error) {
    String message = 'Something went wrong';
    if (error is ApiException) {
      message = error.message ?? message;
    } else if (error.toString().contains('timeout')) {
      message = 'Connection timeout. Try again.';
    } else if (error.toString().contains('connection') ||
        error.toString().contains('SocketException')) {
      message = 'No internet connection.';
    }
    AppSnackbar.error(context, message);
  }
}

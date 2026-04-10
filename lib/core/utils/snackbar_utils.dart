import 'package:flutter/material.dart';

/// App-wide SnackBar helpers — consistent colours and duration everywhere.
class AppSnackBar {
  AppSnackBar._();

  static void error(BuildContext context, String message) => _show(
        context,
        message,
        backgroundColor: Colors.redAccent,
      );

  static void success(BuildContext context, String message) => _show(
        context,
        message,
        backgroundColor: const Color(0xFF2E7D32),
      );

  static void info(BuildContext context, String message) => _show(
        context,
        message,
        backgroundColor: Colors.blueGrey,
      );

  static void _show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ));
  }
}

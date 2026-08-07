import 'package:flutter/material.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Runs [action] if the user is authenticated, otherwise shows the login
/// bottom sheet. After a successful login the [action] is called automatically.
Future<void> requireAuth(
  BuildContext context, {
  required VoidCallback action,
}) async {
  final token = await sl<AuthService>().getToken();
  if (!context.mounted) return;

  if (token.isNotEmpty) {
    action();
    return;
  }

  await showLoginSheet(context, onLoginSuccess: action);
}

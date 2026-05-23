import 'package:flutter/material.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// Thin wrapper kept for backwards compatibility.
/// Prefer [AppEmptyState] directly in new code.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.ext,
    required this.icon,
    required this.message,
    this.action,
  });

  final AppThemeExtension ext;
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) =>
      AppEmptyState(icon: icon, message: message, action: action);
}

import 'package:flutter/material.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// Centred themed loading spinner.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.strokeWidth = 2});
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Center(
      child: CircularProgressIndicator(
        color: ext.accentGold,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

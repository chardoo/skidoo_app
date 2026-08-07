import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Stub notifications tab — no backend endpoint exists for a real
/// notifications feed yet, so this shows an empty state matching the app's
/// existing page chrome rather than faking a feed.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            floating: true,
            snap: true,
            elevation: 0,
            titleSpacing: 16.w,
            title: Text(
              'Notifications',
              style: TextStyle(
                color: ext.greetingColor,
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
              ),
            ),
          ),
        ],
        body: const AppEmptyState(
          icon: Icons.notifications_none_rounded,
          message: 'No notifications yet.',
        ),
      ),
    );
  }
}

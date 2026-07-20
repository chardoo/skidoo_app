import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/features/home/presentation/widgets/search_item_widget.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

// ── Search events list ────────────────────────────────────────────────────────

class SearchEventsList extends StatelessWidget {
  const SearchEventsList({
    super.key,
    required this.homeState,
    required this.ext,
    required this.onEventTap,
  });

  final HomeState homeState;
  final AppThemeExtension ext;
  final ValueChanged<dynamic> onEventTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: AppSpacing.sm.h),
      itemCount: homeState.events.length,
      itemBuilder: (context, index) {
        final event = homeState.events[index];
        return SearchItemWidget(
          event: event,
          onTap: () => onEventTap(event),
        );
      },
    );
  }
}

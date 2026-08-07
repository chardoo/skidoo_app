import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/models/event/Event.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

class SearchItemWidget extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const SearchItemWidget({
    super.key,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String formattedDate = '';
    try {
      formattedDate =
          DateFormat.yMMMd().format(DateTime.parse(event.eventDate)).toString();
    } catch (_) {
      formattedDate = event.eventDate;
    }

    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    // Material, not a decorated Container: ListTile paints its background and
    // ink splashes onto the nearest Material ancestor, so a coloured box in
    // between hides them — and asserts in debug. Carrying the colour on the
    // Material itself means the tap ripple lands on it, clipped to the same
    // rounded rect.
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
      child: Material(
        color: ext.searchItemBackground,
        borderRadius: BorderRadius.circular(14.r),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w, vertical: AppSpacing.xs.h),
          leading: CircleAvatar(
            radius: 18.r,
            backgroundColor: ext.accentGold,
            child: Text(
              event.photographer.isNotEmpty
                  ? event.photographer[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
              ),
            ),
          ),
          title: Text(
            event.eventName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ext.searchItemTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 14.sp,
            ),
          ),
          subtitle: Text(
            '${event.photographer}  ·  $formattedDate',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ext.searchHintColor,
              fontSize: 12.sp,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

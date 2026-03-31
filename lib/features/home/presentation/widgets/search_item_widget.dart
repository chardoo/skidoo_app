import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/event/Event.dart';

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
      formattedDate = DateFormat.yMMMd()
          .format(DateTime.parse(event.eventDate))
          .toString();
    } catch (_) {
      formattedDate = event.eventDate;
    }

    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: ext.searchItemBackground,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
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
    );
  }
}

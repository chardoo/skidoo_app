import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Centred date marker between days in a conversation.
class DaySeparator extends StatelessWidget {
  const DaySeparator({super.key, required this.date, this.emphasised = false});

  final DateTime date;

  /// Bolder styling, used for days that carry a heading of their own in the
  /// designs ("Yesterday" above a group's creation notices).
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Padding(
      padding:
          EdgeInsets.symmetric(vertical: AppSpacing.md.h, horizontal: 16.w),
      child: Center(
        child: Text(
          label(date),
          style: TextStyle(
            color: emphasised ? ext.greetingColor : ext.searchHintColor,
            fontSize: 12.sp,
            fontWeight: emphasised ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// "Today" / "Yesterday" / a weekday within the last week / a date beyond it.
  static String label(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const days = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday',
      ];
      return days[date.weekday - 1];
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    // The year is only worth the space once it stops being the current one.
    final year = date.year == now.year ? '' : ' ${date.year}';
    return '${date.day} ${months[date.month - 1]}$year';
  }

  /// Whether a separator belongs between two adjacent messages.
  static bool needsSeparator(DateTime older, DateTime newer) =>
      older.year != newer.year ||
      older.month != newer.month ||
      older.day != newer.day;
}

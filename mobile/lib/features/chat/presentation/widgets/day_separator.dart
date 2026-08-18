import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/presentation/chat_time.dart';

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
  ///
  /// The day is the phone's day. Reading the calendar fields off the raw
  /// (UTC) timestamp put the boundary at UTC midnight, so for anyone west of
  /// it a message sent late last night was filed under "Today", and east of it
  /// this evening's messages started a new day early.
  static String label(DateTime date) {
    final diff = ChatTime.daysAgo(date);
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return ChatTime.weekday(date);
    return ChatTime.longDate(date);
  }

  /// Whether a separator belongs between two adjacent messages.
  static bool needsSeparator(DateTime older, DateTime newer) =>
      !ChatTime.sameDay(older, newer);
}

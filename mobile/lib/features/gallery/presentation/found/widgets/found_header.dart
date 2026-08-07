import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// "Found photos" title with the running match count on the right.
///
/// [count] is `totals.photos` for the *current filter set*, not the user's
/// lifetime match count: the server counts it over the same predicate it
/// selects rows with, so it narrows as chips are applied. That's deliberate —
/// it keeps one number meaning one thing across the screen, agreeing both with
/// the grid below and with the "Show N photos" the filter sheet promised.
///
/// Null suppresses the count entirely, for when the server sent no usable
/// `totals`. Showing nothing is better than showing a number derived from the
/// pages loaded so far, which would be wrong and would move as the user
/// scrolls.
class FoundHeader extends StatelessWidget {
  const FoundHeader({super.key, required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            'Found photos',
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (count != null)
          Text(
            '$count found',
            style: TextStyle(
              color: ext.accentGold,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

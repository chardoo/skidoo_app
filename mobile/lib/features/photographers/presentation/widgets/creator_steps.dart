import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// How far through becoming a creator you are: ① — ②, captioned.
///
/// Both steps ask for real work — a portfolio with four photos, then an ID and
/// three agreements — and someone part-way through a form deserves to know
/// whether they are nearly done. A step they have finished shows a tick rather
/// than its number, so the row reads as progress rather than as a pair of
/// buttons.
///
/// The same widget on both pages, which is what keeps them one flow rather
/// than two screens that happen to follow each other.
class CreatorSteps extends StatelessWidget {
  const CreatorSteps({super.key, required this.current});

  /// 0-based: 0 while on Profile Info, 1 on Verification.
  final int current;

  static const _labels = ['Profile Info', 'Verification'];

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(
      label: 'Step ${current + 1} of ${_labels.length}: ${_labels[current]}',
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _labels.length; i++) ...[
                if (i > 0)
                  Padding(
                    // Nudged up so the rule sits against the circles rather
                    // than the captions hanging below them.
                    padding: EdgeInsets.only(top: 13.h),
                    child: Container(
                      width: 28.w,
                      height: 1,
                      color: ext.searchHintColor.withValues(alpha: 0.4),
                    ),
                  ),
                _Step(
                  index: i,
                  label: _labels[i],
                  done: i < current,
                  active: i == current,
                  ext: ext,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
    required this.ext,
  });

  final int index;
  final String label;
  final bool done;
  final bool active;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    // Done and current are both "reached"; only the one still ahead is muted.
    final reached = done || active;
    final colour = reached ? ext.accentGold : ext.searchHintColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26.r,
          height: 26.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: reached ? ext.accentGold : Colors.transparent,
            border: Border.all(
              color: reached
                  ? ext.accentGold
                  : ext.searchHintColor.withValues(alpha: 0.5),
            ),
          ),
          alignment: Alignment.center,
          child: done
              ? Icon(Icons.check_rounded, size: 15.sp, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: reached ? Colors.white : ext.searchHintColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        SizedBox(height: AppSpacing.xs.h),
        Text(
          label,
          style: TextStyle(
            color: colour,
            fontSize: 11.sp,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

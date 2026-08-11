import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// "Is this your photo?" — the question asked over one photo at a time.
///
/// Face recognition proposes; this is where the person disposes. It sits
/// above the image rather than over it because the answer depends on looking
/// at the whole frame, and a card floating on the face would cover the thing
/// being judged.
///
/// Two plain buttons and no default. The batch grid this replaces started
/// everything at "yes" and asked for exceptions, which is right when someone
/// is skimming twenty photos; asked one at a time the question deserves a
/// real answer rather than a pre-filled one.
class FoundReviewPrompt extends StatelessWidget {
  const FoundReviewPrompt({
    super.key,
    required this.onYes,
    required this.onNo,
    this.busy = false,
  });

  final VoidCallback onYes;
  final VoidCallback onNo;

  /// An answer is in flight. Both buttons go inert — double-answering would
  /// send a second verdict for a photo that has already left the queue.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg.w,
        AppSpacing.md.h,
        AppSpacing.md.w,
        AppSpacing.md.h,
      ),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Is this your photo?',
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _AnswerButton(
            label: 'Yes',
            filled: true,
            onPressed: busy ? null : onYes,
            ext: ext,
          ),
          SizedBox(width: AppSpacing.sm.w),
          _AnswerButton(
            label: 'No',
            filled: false,
            onPressed: busy ? null : onNo,
            ext: ext,
          ),
        ],
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.filled,
    required this.onPressed,
    required this.ext,
  });

  final String label;

  /// Yes is solid, No is outlined. Confirming is the common answer and the one
  /// that moves the queue along, so it carries the weight — but "No" stays a
  /// full-sized button rather than a text link, because rejecting a wrong
  /// match is the whole reason this screen exists.
  final bool filled;
  final VoidCallback? onPressed;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return Semantics(
      button: true,
      enabled: !disabled,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: disabled ? 0.5 : 1,
          child: Container(
            constraints: BoxConstraints(minWidth: 52.w),
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w,
              vertical: AppSpacing.sm.h,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? ext.accentGold : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm.r),
              border: filled
                  ? null
                  : Border.all(
                      color: ext.greetingColor.withValues(alpha: 0.4),
                    ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : ext.greetingColor,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

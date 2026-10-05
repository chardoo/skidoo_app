import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/features/settings/presentation/personalisation_prompt.dart';

/// "Personalise my feed?" — asked once, in the feed, after enough of it has
/// been watched for the question to mean something.
///
/// The switch behind it (`share_usage_data`) has existed all along, off by
/// default, reachable only through Settings › Privacy where it was called
/// "Share Usage Data" under "Diagnostic analytics". One account in 228 had it
/// on. This asks in the place the benefit lands, in the words the benefit is
/// actually in.
///
/// Both answers are final — see [PersonalisationPrompt.markAnswered]. "Not now"
/// is a decision, not a deferral, and the setting stays in Privacy for anyone
/// who changes their mind either way.
class PersonalisationSheet extends StatelessWidget {
  const PersonalisationSheet({super.key, required this.onAccept});

  /// Turns the setting on. Returns false if the server refused, so the sheet
  /// can say so rather than closing on a promise it did not keep.
  final Future<bool> Function() onAccept;

  /// Opens the sheet. Resolves to true if they turned personalisation on.
  ///
  /// Dismissible, deliberately: a prompt somebody cannot close is a prompt they
  /// answer dishonestly to get rid of. A swipe-away counts as "not now" —
  /// having been asked and walked away from is an answer.
  static Future<bool> show(
    BuildContext context, {
    required Future<bool> Function() onAccept,
  }) async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => PersonalisationSheet(onAccept: onAccept),
    );
    await PersonalisationPrompt.markAnswered();
    return accepted ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, AppSpacing.md.h, AppSpacing.lg.w, AppSpacing.xl.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: AppSpacing.lg.h),
              decoration: BoxDecoration(
                color: ext.searchHintColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          Container(
            width: 56.w,
            height: 56.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ext.accentGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg.r),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                color: ext.accentGold, size: 28.sp),
          ),
          SizedBox(height: AppSpacing.lg.h),

          Text(
            'Personalise my feed',
            textAlign: TextAlign.center,
            style: AppTypography.headline.copyWith(color: ext.greetingColor),
          ),
          SizedBox(height: AppSpacing.sm.h),

          // Says what it does and what it does not do. The old copy — "help us
          // improve by sharing anonymized analytics" — described a benefit to
          // us and never mentioned the feed at all.
          Text(
            'We can use which events you watch, and which you skip, to choose '
            'what to show you next. It stays on your account: never shared '
            'with other users or advertisers, and never used to identify you.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: ext.searchHintColor,
              height: 1.5,
            ),
          ),
          SizedBox(height: AppSpacing.xl.h),

          _AcceptButton(onAccept: onAccept),
          SizedBox(height: AppSpacing.sm.h),

          // Plain, and as easy to hit as the other one. A "no" dressed as a
          // link is a dark pattern, and the honest version is what makes the
          // "yes" worth having.
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Not now',
              style: AppTypography.bodyBold.copyWith(color: ext.searchHintColor),
            ),
          ),

          Text(
            'You can change this any time in Settings › Privacy.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: ext.searchHintColor),
          ),
        ],
      ),
    );
  }
}

class _AcceptButton extends StatefulWidget {
  const _AcceptButton({required this.onAccept});

  final Future<bool> Function() onAccept;

  @override
  State<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends State<_AcceptButton> {
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.onAccept();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    // Stays open on a failure. Closing would leave somebody believing they had
    // turned something on that is still off.
    setState(() {
      _busy = false;
      _error = 'We could not save that. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          fullWidth: true,
          isLoading: _busy,
          onPressed: _busy ? null : _accept,
          label: 'Personalise my feed',
        ),
        if (_error != null) ...[
          SizedBox(height: AppSpacing.sm.h),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: ext.likeRed),
          ),
        ],
      ],
    );
  }
}

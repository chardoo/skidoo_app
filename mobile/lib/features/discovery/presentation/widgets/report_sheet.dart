import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';

const reportReasons = <String, String>{
  'inappropriate_content': 'Inappropriate content',
  'spam': 'Spam',
  'harassment': 'Harassment',
  // Its own reason rather than a kind of "inappropriate content", because the
  // published child safety standards commit to triaging these ahead of all
  // other moderation — and a reason shared with blurry photos cannot be
  // triaged differently. The admin queue sorts on this exact value.
  'child_safety': 'Child safety or exploitation',
  'copyright': 'Copyright violation',
  'other': 'Other',
};

/// The `onReport` a comment options sheet wants, or null when there is nobody
/// to report to.
///
/// Four surfaces draw comments — an event's thread, a photo's, an ad's and a
/// request's — and all four reach the same reason picker with the same asset
/// type, so the wiring is here rather than copied into each of them. Null for
/// your own comment: reporting your own words is not an act anyone wants, and
/// the one thing worse than not offering an option is offering one the server
/// refuses.
VoidCallback? reportCommentAction(
  BuildContext context, {
  required AppThemeExtension ext,
  required String commentId,
  required bool isMine,
}) {
  if (isMine) return null;
  return () => ReportSheet.show(
        context,
        ext: ext,
        assetType: 'comment',
        assetId: commentId,
      );
}

/// Shared report-reason bottom sheet.
///
/// [assetType] must be one of: "event", "picture", "comment", "user",
/// "request", "campaign" — the six the server accepts. "user" is the account
/// itself rather than anything it posted, and [assetId] is then a user id.
/// [assetId] is otherwise the backend ID of the thing being reported.
class ReportSheet extends StatefulWidget {
  const ReportSheet({
    super.key,
    required this.ext,
    required this.assetType,
    required this.assetId,
  });

  final AppThemeExtension ext;
  final String assetType;
  final String assetId;

  static void show(
    BuildContext context, {
    required AppThemeExtension ext,
    required String assetType,
    required String assetId,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          ReportSheet(ext: ext, assetType: assetType, assetId: assetId),
    );
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  String? _selected;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_selected == null || _submitting) return;
    setState(() => _submitting = true);
    String? failure;
    try {
      final userId = await sl<AuthService>().getUserId();
      await sl<Api>().dio.post(
        '/client/$userId/report',
        data: {
          'assetType': widget.assetType,
          'assetId': widget.assetId,
          'reason': _selected,
        },
      );
    } on dio.DioException catch (e) {
      // Said plainly rather than swallowed.
      //
      // This used to pop and thank the reader whatever happened, so a refused
      // report — the commonest refusal being "you have already reported this"
      // — looked exactly like an accepted one. Nothing reaches moderation, and
      // the person who went looking for the control is told it worked. For the
      // one kind of report that has to be trusted, a false receipt is worse
      // than an error.
      final data = e.response?.data;
      failure = data is Map
          ? (data['error'] is Map ? data['error']['message'] as String? : null)
          : null;
      failure ??= 'Could not submit the report. Try again.';
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (failure != null) {
      AppSnackBar.error(context, failure);
      return;
    }
    AppSnackBar.success(
        context, 'Report submitted. Thank you for your feedback.');
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      // ListTile ink paints on the nearest Material ancestor; this decorated
      // Container sits between the sheet's Material and the tiles and would
      // swallow it (and assert in debug). A transparency Material paints
      // nothing and just gives the ink somewhere to land.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: ext.searchHintColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 12.h),
                child: Row(
                  children: [
                    Semantics(
                        button: true,
                        label: 'Close',
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(AppBackButton.icon,
                              color: ext.greetingColor, size: 18.sp),
                        )),
                    SizedBox(width: AppSpacing.md.w),
                    // Expanded, because the heading is a whole sentence next
                    // to an icon in a fixed-width row: at a large system text
                    // scale it ran off the right edge of the sheet (and does
                    // so in widget tests, where the test font is wider than
                    // any real one). Taking the remaining width and
                    // ellipsising is the readable failure.
                    Expanded(
                      child: Text(
                        'Why are you reporting this?',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppTypography.displayFontFamily,
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                  height: 1, color: ext.searchHintColor.withValues(alpha: 0.1)),
              ...reportReasons.entries.map((entry) {
                final selected = _selected == entry.key;
                return ListTile(
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      color: selected ? Colors.redAccent : ext.greetingColor,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14.sp,
                    ),
                  ),
                  trailing: selected
                      ? Icon(Icons.check_circle_rounded,
                          color: Colors.redAccent, size: 20.sp)
                      : Icon(Icons.radio_button_unchecked_rounded,
                          color: ext.searchHintColor, size: 20.sp),
                  onTap: () => setState(() => _selected = entry.key),
                );
              }),
              SizedBox(height: AppSpacing.md.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
                child: AppButton(
                  fullWidth: true,
                  variant: AppButtonVariant.destructive,
                  isLoading: _submitting,
                  onPressed: _selected == null || _submitting ? null : _submit,
                  label: 'Submit Report',
                ),
              ),
              SizedBox(height: AppSpacing.lg.h),
            ],
          ),
        ),
      ),
    );
  }
}

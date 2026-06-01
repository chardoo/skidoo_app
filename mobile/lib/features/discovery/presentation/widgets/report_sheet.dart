import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/services/auth_service.dart';

const reportReasons = <String, String>{
  'inappropriate_content': 'Inappropriate content',
  'spam': 'Spam',
  'harassment': 'Harassment',
  'copyright': 'Copyright violation',
  'other': 'Other',
};

/// Shared report-reason bottom sheet.
///
/// [assetType] must be one of: "event", "picture", "request", "campaign".
/// [assetId] is the backend ID of the thing being reported.
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
      builder: (_) => ReportSheet(ext: ext, assetType: assetType, assetId: assetId),
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
    } on dio.DioException catch (_) {
      // Best-effort — don't block on network error.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnackBar.success(context, 'Report submitted. Thank you for your feedback.');
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 12.h),
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
                  if (!kIsWeb)
                    Semantics(button: true, label: 'Close', child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: ext.greetingColor, size: 18.sp),
                    )),
                  SizedBox(width: 12.w),
                  Text(
                    'Why are you reporting this?',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: ext.searchHintColor.withValues(alpha: 0.1)),

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

            SizedBox(height: 12.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected == null || _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    disabledBackgroundColor:
                        Colors.redAccent.withValues(alpha: 0.3),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Submit Report',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.sp,
                          ),
                        ),
                ),
              ),
            ),

            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }
}

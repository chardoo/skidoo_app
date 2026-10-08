import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';

/// Found's empty state for somebody signed in who has never added a face.
///
/// Split from [FoundScanningState], which this state used to share. That
/// screen says "Scanning for your face — we haven't matched you to any photo
/// yet. We'll notify you once we do", and for somebody with no face on file
/// every clause of it is false: nothing is scanning, nothing can be matched,
/// and the notification it promises can never arrive. It described work that
/// was not happening and gave them nothing to do about it.
///
/// What [onTakeSelfie] actually opens is the code sheet, not the camera —
/// deliberately, and the reason is worth keeping. A selfie only means
/// something once the album is known: a face with no event to search is
/// enrolment, and enrolment is not what somebody standing at an event with a
/// printed code in their hand is trying to do. So the order is code, then
/// camera, then the offer to keep the face. The button names the errand and
/// the sheet asks for the one thing that has to come first.
///
/// This is the panel that was deleted on 2026-10-05, returning under a
/// narrower rule. It was removed for showing *guests* a selfie prompt before
/// asking them for an account, and for putting the camera ahead of the code.
/// Neither applies here: a guest still gets [FoundJoinPrompt], and the code
/// still comes first.
/// The design's button width, on its 390pt frame: the pill spans roughly half
/// the screen. Named so the widget test can assert it rather than restate it.
const double kTakeSelfieButtonWidth = 190;

class FoundAddFaceState extends StatelessWidget {
  const FoundAddFaceState({super.key, required this.onTakeSelfie});

  final VoidCallback onTakeSelfie;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl.w,
          vertical: AppSpacing.xxl.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96.w,
              height: 96.w,
              decoration: BoxDecoration(
                color: ext.cardSurface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.add_a_photo_outlined,
                size: 40.sp,
                color: ext.searchHintColor,
              ),
            ),
            SizedBox(height: AppSpacing.xxl.h),
            Text(
              'Add your face to get found',
              textAlign: TextAlign.center,
              style: AppTypography.headline.copyWith(color: ext.greetingColor),
            ),
            SizedBox(height: AppSpacing.sm.h),
            Text(
              'Upload a selfie so we can match you in photos from events you '
              'attend.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: ext.searchHintColor),
            ),
            SizedBox(height: AppSpacing.xxxl.h),
            // About half the width, as the design draws it — not the
            // wall-to-wall pill this shipped as. It is one small errand, and a
            // button stretched across the screen reads as the only thing left
            // to do on a tab somebody may just be passing through.
            //
            // A minimum rather than a fixed width: it holds this shape for
            // this label, and a longer translation pushes it wider instead of
            // being clipped. Padding alone could not do it — the width would
            // then follow the font, and the test font is square-glyphed, so
            // nothing here could be measured honestly.
            ElevatedButton(
              onPressed: onTakeSelfie,
              style: ElevatedButton.styleFrom(
                backgroundColor: ext.accentGold,
                foregroundColor: Colors.white,
                minimumSize: Size(kTakeSelfieButtonWidth.w, 48.h),
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl.w,
                  vertical: AppSpacing.md.h,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill.r),
                ),
              ),
              child: Text(
                'Take a selfie',
                style: AppTypography.bodyBold.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

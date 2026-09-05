import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:jperg_app/core/common/widgets/app_section_label.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/photographers/presentation/pages/creator_profile_page.dart';

/// One photographer who answered a request: who they are, what they have shot,
/// and what people say about them.
///
/// The profile itself is [CreatorProfilePage] — the same screen a tap on this
/// person anywhere else opens. It used to be a second, better-looking copy of
/// that page that only this flow could reach, which is how the app came to
/// have two profiles for one person.
///
/// What belongs to *this* flow is the button. Choosing here closes the request
/// to everyone else, so the confirmation says so in as many words before it
/// happens.
class RequestPhotographerPage extends StatelessWidget {
  const RequestPhotographerPage({
    super.key,
    required this.photographer,
    required this.requestTitle,
    required this.onSelect,
    this.alreadySelected = false,
  });

  final RequestInterest photographer;
  final String requestTitle;

  /// Runs after the confirmation, and pops with true when it succeeds.
  final Future<bool> Function() onSelect;
  final bool alreadySelected;

  String get _displayName => (photographer.name?.trim().isNotEmpty ?? false)
      ? photographer.name!.trim()
      : 'Photographer';

  Future<void> _confirm(BuildContext context, AppThemeExtension ext) async {
    final agreed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        name: _displayName,
        requestTitle: requestTitle,
        ext: ext,
      ),
    );
    if (agreed != true) return;
    final ok = await onSelect();
    if (ok && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return CreatorProfilePage(
      // The interest row already carries the whole header — it was fetched
      // with the rest of the page — so this opens on the person rather than
      // on a spinner, and asks the server for nothing.
      profile: CreatorProfile(
        id: photographer.id,
        name: _displayName,
        photoUrl: photographer.profileUrl,
        bannerUrl: photographer.studioImageUrl,
        bio: photographer.bio,
        location: photographer.location,
        specialties: photographer.specialties,
        rating: photographer.rating,
        ratingCount: photographer.ratingCount,
        followerCount: photographer.followerCount,
        verified: photographer.verified,
      ),
      fetchProfile: false,
      note: (photographer.message?.isNotEmpty ?? false)
          ? _Note(message: photographer.message!, ext: ext)
          : null,
      footer: Column(
        children: [
          // Centred and only as wide as it needs to be, the way the design
          // draws it — a full-bleed bar would read as the end of the page
          // rather than one choice on it.
          Center(
            child: SizedBox(
              height: 46.h,
              child: ElevatedButton(
                onPressed:
                    alreadySelected ? null : () => _confirm(context, ext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ext.accentGold,
                  disabledBackgroundColor:
                      ext.accentGold.withValues(alpha: 0.5),
                  padding: EdgeInsets.symmetric(horizontal: 30.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                child: Text(
                  alreadySelected ? 'Selected' : 'Select photographer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'View more profiles',
                style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The note they sent with their answer.
class _Note extends StatelessWidget {
  const _Note({required this.message, required this.ext});

  final String message;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionLabel('Additional message'),
        SizedBox(height: AppSpacing.sm.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSpacing.md.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(
              color: ext.searchHintColor.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Text(
            message,
            style: TextStyle(
              color: ext.searchHintColor,
              fontSize: 13.sp,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.name,
    required this.requestTitle,
    required this.ext,
  });

  final String name;
  final String requestTitle;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: AppSpacing.lg.h),
                decoration: BoxDecoration(
                  color: ext.searchHintColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Text(
                'Confirm photographer?',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),
              Text(
                // Said plainly, because it is the consequence people would
                // otherwise discover afterwards.
                'Confirm $name for $requestTitle? '
                "Others won't be able to apply after this.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 13.sp,
                  height: 1.4,
                ),
              ),
              SizedBox(height: AppSpacing.xl.h),
              SizedBox(
                width: double.infinity,
                height: 46.h,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ext.accentGold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                  child: Text(
                    'Confirm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
